---
phase: 06-polish-testflight
plan: 03
subsystem: trip-reminders-integration
tags: [trips, reminders, notifications, deep-link, swift-testing]
requires: [phase-05, 06-02]
provides:
  - "D79: NotificationScheduler unions Trip+Activity over private ScheduledReminder with single prefix(64)"
  - "D80: Trip notification content (title 'Trip starting soon', body '<name> · <bodyPhrase>', userInfo['tripID']=bare uuid)"
  - "D81: PendingDeepLink.trip(UUID) routed through AppDelegate + ContentView to AppDestination.tripDetail"
  - "D82: TripEditSheet Reminder Section mirroring ActivityEditSheet (Toggle + Picker + auth flow + dirty-tracking triplet + reconcile-on-save)"
  - "D83: Trip reschedule-on-date-edit + cancel-on-delete via existing Rule 1 drift detection + cascade fetch"
affects:
  - "Travellify/Shared/NotificationScheduler.swift (reconcile signature-compatible but now iterates ScheduledReminder instead of (Activity, Date))"
  - "Wave 4 (06-04) TestFlight prep (no runtime effects)"
tech_stack:
  added: []
  patterns:
    - "Private Sendable ScheduledReminder struct collapsing two @Model fetches into one sort+prefix(64) pipeline"
    - "Trip/Activity identifier namespacing via prefix string ('trip-' vs bare uuid)"
    - "Dirty-tracking triplet pattern (isEnabled/leadMinutes/anchorDate) reused across Activity+Trip edit sheets"
key_files:
  created: []
  modified:
    - Travellify/Shared/NotificationScheduler.swift
    - Travellify/App/AppState.swift
    - Travellify/App/AppDelegate.swift
    - Travellify/ContentView.swift
    - Travellify/Features/Trips/TripEditSheet.swift
    - TravellifyTests/NotificationSchedulerTests.swift
    - TravellifyTests/ReminderLifecycleTests.swift
decisions:
  - "[06-03] Zero new source files → zero pbxproj edits this wave"
  - "[06-03] ScheduledReminder is file-private — callers still see reconcile(modelContext:) as the only public mutation entry"
  - "[06-03] Deep-link switch over PendingDeepLink handles .none explicitly (Phase 5 consume-after-push semantics preserved)"
metrics:
  duration: ~12min
  completed: 2026-04-24
  tasks: 3
  files_created: 0
  files_modified: 7
---

# Phase 6 Plan 3: Trip Reminders Integration Summary

Scheduler, deep-link, and edit-sheet integration that closes out TRIP-07, TRIP-08, TRIP-09. Wave 2's foundation (Trip schema + TripReminderLeadTime + ReminderFireDate.fireDate(for: Trip)) is now end-to-end wired: toggle a Trip reminder in TripEditSheet → scheduler reconciles the Trip+Activity union under a single prefix(64) cap → tap the delivered notification → app deep-links to the trip detail.

## What Shipped

- **D79 (Scheduler union)** — `Travellify/Shared/NotificationScheduler.swift`:
  - New `private struct ScheduledReminder { kind, identifier, fireDate, title, body, userInfoKey, userInfoValue }`.
  - `reconcile(modelContext:)` now runs `FetchDescriptor<Activity>` + `FetchDescriptor<Trip>`, compact-maps both into `[ScheduledReminder]`, concatenates, `.sorted { $0.fireDate < $1.fireDate }.prefix(64)` — **exactly one** `.prefix(64)` call.
  - Rule 1 drift detection preserved (existing identifier with changed fireDate → cancel+readd); `components.timeZone = .current` preserved verbatim.
  - `schedule(reminder:)` replaces `schedule(activity:fireDate:)`; reads title/body/userInfoKey+Value/identifier/fireDate from the struct.
  - Activity body still produced via existing `activityBody(activity:trip:)` helper.

- **D80 (Trip content)** — Trip reminders carry `title = "Trip starting soon"`, `body = "<trip.name> · <bodyPhrase>"`, `userInfo["tripID"] = trip.id.uuidString` (bare — **not** prefixed). Identifier is `"trip-<uuid>"`.

- **D81 (Deep-link)** — 3 files:
  - `AppState.swift`: `enum PendingDeepLink { case activity(UUID); case trip(UUID) }`.
  - `AppDelegate.swift`: `didReceive` now branches on `info["activityID"]` first, then `info["tripID"]`; `@preconcurrency UNUserNotificationCenterDelegate` + async signature preserved.
  - `ContentView.swift`: `.onChange(of: appState.pendingDeepLink)` replaced with `switch` over `.activity / .trip / .none`; trip branch does `FetchDescriptor<Trip>` by UUID then `path.append(AppDestination.tripDetail(trip.persistentModelID))`. No new AppDestination case added — landmine #4 held.

- **D82 (TripEditSheet Reminder Section)** — `Travellify/Features/Trips/TripEditSheet.swift`:
  - `reminderSection()` @ViewBuilder inserted at **line 90** in the Form body; `@ViewBuilder` helper defined at **line 124**.
  - `UserNotifications` imported; `@Environment(\.scenePhase)` added.
  - State additions: `isReminderEnabled`, `leadMinutes` (defaulting to `TripReminderLeadTime.default.rawValue`), `authStatus`, `showDeniedAlert`, plus dirty-tracking triplet `initialIsReminderEnabled` / `initialLeadMinutes` / `initialStartDate`.
  - Lifecycle modifiers (task, onChange(scenePhase), alert "Notifications are off" with Open Settings / Cancel) attached at NavigationStack scope.
  - `handleToggleChange`, `requestAuthAndEnable`, `refreshAuthStatus` copied from ActivityEditSheet verbatim.
  - `loadInitialValuesIfNeeded()` hydrates `isReminderEnabled` + `leadMinutes` from Trip on `.edit`, then snapshots the dirty-tracking triplet for both modes.
  - `save()` writes `trip.isReminderEnabled` + `trip.reminderLeadMinutes` on both create + edit; after `modelContext.save()` it reconciles via `Task { await NotificationScheduler.shared.reconcile(modelContext: context) }` when `reminderChanged || isCreate` (closed-over `let context = modelContext` per Phase 5 pattern).

- **D83 (Lifecycle)** — No new code needed; existing Rule 1 drift detection handles date edits (same `trip-<uuid>` identifier, new fireDate → cancel+readd) and union fetch handles delete (Trip row disappears from fetch set → identifier falls into `toCancelMissing`).

## Landmine Verification

- **Landmine #1 (single prefix(64))** — `grep -c "\.prefix(64)" Travellify/Shared/NotificationScheduler.swift` → **1**. Confirmed exactly one cap across the union.
- **Landmine #4 (no new AppDestination case)** — `AppDestination.swift` was **not modified** this plan. `.tripDetail(PersistentIdentifier)` was already present from Phase 2.

## Tests

All 8 NotificationSchedulerTests + all 7 ReminderLifecycleTests pass. Full `xcodebuild test` succeeds on iPhone 16e.

**New NotificationSchedulerTests:**
- `unionSoonest64` — seeds 40 activities + 40 trips (80 total, interleaved fire dates), asserts `pending.count == 64` AND both prefix families appear (proves single-cap not bucket-cap).
- `tripIdentifierPrefix` — asserts `"trip-<uuid>"` identifier shape, `UUID(uuidString: dropFirst(5))` round-trips, `userInfo["tripID"]` is the **bare** uuid (not prefixed).

**New ReminderLifecycleTests:**
- `tripToggleOffCancels`
- `tripDateEditReschedules` — identifier stable across date edit.
- `tripDeleteCancels`

Existing tests still green (scheduleOnEnable, rescheduleOnDateChange, cancelOnDelete, cancelOnTripCascade, soonestSixtyFour, diffIdempotent, pastDatesIgnored, identifierMatchesUUID, contentBodyFormat, rescheduleDiff).

## Swift 6 Strict Concurrency

No new warnings observed on TripEditSheet Reminder Section, handlers, or ScheduledReminder value struct. Patterns mirror ActivityEditSheet verbatim (already Swift 6 clean since Phase 5).

## iOS Permission Alert Behavior (Manual Smoke Reminder)

`UNUserNotificationCenter.current()` is app-global, so once a user grants notification auth for an Activity reminder, toggling on a Trip reminder does **not** re-prompt — the existing `.authorized` status short-circuits into the "enable" branch directly. Denied state likewise shows the `"Notifications are off"` alert without attempting a second request. This is the intended cross-surface behavior and matches the Phase 5 locked contract.

## Commits

| Task | Gate | Hash | Message |
|------|------|------|---------|
| 1 | RED | 9e5d398 | test(06-03): add failing tests for scheduler Trip+Activity union |
| 1 | GREEN | 525d296 | feat(06-03): NotificationScheduler unions Trip+Activity over ScheduledReminder |
| 2 | — | 61a2daf | feat(06-03): extend deep-link path with .trip(UUID) routing (D81) |
| 3 | RED | 2fe719c | test(06-03): add trip lifecycle tests (TRIP-08) |
| 3 | GREEN | 4916e67 | feat(06-03): TripEditSheet Reminder Section mirrors ActivityEditSheet (D82) |

Note — Task 3's new lifecycle tests passed immediately on the freshly-rewritten scheduler (the scheduler GREEN from Task 1 already union-fetches Trips), so those tests landed "RED-confirmed-via-prior-behavior" rather than against a freshly-regressed target. TripEditSheet itself has no direct unit tests in this plan (UI integration is covered by the full lifecycle chain + manual simulator smoke in `<verification>`).

## Deviations from Plan

None — plan executed exactly as written. No Rule 1–4 invocations.

## TDD Gate Compliance

- Task 1 RED gate: `9e5d398` (`test(06-03): add failing tests...`).
- Task 1 GREEN gate: `525d296` (`feat(06-03): NotificationScheduler unions...`).
- Task 3 RED gate: `2fe719c` (`test(06-03): add trip lifecycle tests...`). *(Passed on landing because Task 1 GREEN already handles the unified pipeline — union scheduler was the enabling change for all lifecycle behaviors.)*
- Task 3 GREEN gate: `4916e67` (`feat(06-03): TripEditSheet Reminder Section...`).
- REFACTOR gate: not applicable.

## Self-Check: PASSED

- FOUND: Travellify/Shared/NotificationScheduler.swift
- FOUND: Travellify/App/AppState.swift
- FOUND: Travellify/App/AppDelegate.swift
- FOUND: Travellify/ContentView.swift
- FOUND: Travellify/Features/Trips/TripEditSheet.swift
- FOUND: TravellifyTests/NotificationSchedulerTests.swift
- FOUND: TravellifyTests/ReminderLifecycleTests.swift
- FOUND commits: 9e5d398, 525d296, 61a2daf, 2fe719c, 4916e67
- Build: SUCCEEDED on iPhone 16e (Xcode 26.2).
- Tests: ALL PASSED (full suite).
- NotificationScheduler.swift: exactly 1 `.prefix(64)` occurrence (landmine #1 verified).
- AppDestination.swift: not modified this plan (landmine #4 verified).
