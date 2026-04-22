---
phase: 05-notifications
plan: 04
subsystem: notifications
tags: [notifications, app-lifecycle, deep-link, appdelegate, scenephase, integration-tests]
wave: 4
requires:
  - 05-01-SUMMARY.md  # Activity reminder schema + helpers
  - 05-02-SUMMARY.md  # NotificationScheduler + NotificationCenterProtocol + Mock
  - 05-03-SUMMARY.md  # ActivityEditSheet Reminder Section
provides:
  - AppDelegate (UIKit bridge, @preconcurrency UNUserNotificationCenterDelegate)
  - AppState (@Observable @MainActor singleton carrying pendingDeepLink)
  - ScenePhase → NotificationScheduler.reconcile hook
  - Delete-path reconcile hooks (ActivityListView, TripListView)
  - ReminderLifecycleTests (4 integration tests, ACT-07/08)
  - Fireproof reschedule-on-edit in NotificationScheduler (Rule 1 fix)
affects:
  - Travellify/App/TravellifyApp.swift
  - Travellify/ContentView.swift
  - Travellify/Shared/NotificationScheduler.swift
  - Travellify/Features/Activities/ActivityListView.swift
  - Travellify/Features/Trips/TripListView.swift
tech-stack:
  added:
    - "@UIApplicationDelegateAdaptor (SwiftUI ↔ UIKit delegate bridge)"
    - "@preconcurrency UNUserNotificationCenterDelegate (Swift 6.0 mode)"
    - "@Observable AppState singleton for cross-layer deep-link intent"
  patterns:
    - "UUID round-trips through userInfo['activityID']; PersistentIdentifier never serialized"
    - "scenePhase .active → reconcile(modelContext: container.mainContext)"
    - "reconcile after modelContext.save() and BEFORE FileStorage.removeTripFolder"
    - "Swift Testing @MainActor struct + injected MockNotificationCenter via NotificationScheduler(center:)"
    - "await Task.yield() after reconcile to drain MockNotificationCenter.remove()'s Task dispatch"
key-files:
  created:
    - Travellify/App/AppDelegate.swift
    - Travellify/App/AppState.swift
    - TravellifyTests/ReminderLifecycleTests.swift
  modified:
    - Travellify/App/TravellifyApp.swift
    - Travellify/ContentView.swift
    - Travellify/Features/Activities/ActivityListView.swift
    - Travellify/Features/Trips/TripListView.swift
    - Travellify/Shared/NotificationScheduler.swift  # Rule 1 fix: reschedule on fireDate change
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "AppDelegate uses @preconcurrency on the UNUserNotificationCenterDelegate conformance (Swift 6.0 mode). Tech debt: migrate to Swift 6.2 isolated conformance when Xcode upgrades."
  - "Deep-link routing via AppState.pendingDeepLink ← .activity(UUID). ContentView observes pendingDeepLink (onChange), resolves UUID → Activity → trip.persistentModelID, pushes AppDestination.activityList, then consumes (sets nil)."
  - "ContentView NavigationPath was already @State path: [AppDestination]; deep-link routing is a plain onChange observer — no navigation semantics changed."
  - "Only one trip-delete site exists (TripListView alert). TripDetailView does NOT expose delete; no other hooks needed."
  - "NotificationScheduler.reconcile had a bug: it only re-scheduled NEW identifiers, never re-checked existing requests for stale triggers. Fixed to detect fireDate drift and cancel+re-add."
metrics:
  duration: ~18min
  completed: "2026-04-23"
---

# Phase 5 Plan 4: Notifications Lifecycle Wiring Summary

Wire the notification subsystem into the app lifecycle with `AppDelegate` (async-only `@preconcurrency UNUserNotificationCenterDelegate`), ScenePhase reconcile hook, delete-path reconcile in `ActivityListView` + `TripListView`, and deep-link routing via `AppState` — closing the ACT-07/08/09 loop. Fixed a latent Rule 1 bug in Wave 2 scheduler where `reconcile` never rescheduled existing requests when their fireDate drifted. 4 integration tests (`ReminderLifecycleTests`) cover schedule/reschedule/cancel/trip-cascade. Full test suite green (no regressions).

## Execution

### Task 1 — AppDelegate + AppState + scenePhase reconcile
Commit: `04813d0`

- Created `Travellify/App/AppState.swift` — `@Observable @MainActor final class AppState` with `static let shared` and `pendingDeepLink: PendingDeepLink?` (enum with `.activity(UUID)`).
- Created `Travellify/App/AppDelegate.swift` — `UIApplicationDelegate` installing `UNUserNotificationCenter.current().delegate = self` on `willFinishLaunchingWithOptions`. Extension with `@preconcurrency UNUserNotificationCenterDelegate` conformance, **async-only** `willPresent` (returns `[.banner, .sound]`) and `didReceive` (sets `AppState.shared.pendingDeepLink`). NO completion-handler variants (RESEARCH Pitfall 1 / Apple Forum 762217).
- Modified `TravellifyApp.swift` — added `@UIApplicationDelegateAdaptor(AppDelegate.self)`, `@Environment(\.scenePhase)`, and `.onChange(of: scenePhase)` on the `WindowGroup` scene. On `.active`, captures `container.mainContext` and spawns `Task { @MainActor in await NotificationScheduler.shared.reconcile(modelContext:) }`.
- Modified `ContentView.swift` — added `@Environment(\.modelContext)`, `private let appState = AppState.shared`, and `.onChange(of: appState.pendingDeepLink)` on the NavigationStack. Resolves the UUID via `FetchDescriptor<Activity>` predicate, appends `AppDestination.activityList(trip.persistentModelID)` to the existing `path`, and consumes the intent by setting `pendingDeepLink = nil`.
- pbxproj: registered `AppDelegate.swift`, `AppState.swift`, and `ReminderLifecycleTests.swift` (batched into Task 1 pbxproj edit to keep a single structurally-coherent diff; test file written in Task 2).

### Task 2 — Delete-path reconcile hooks + ReminderLifecycleTests
Commits: `9c20c82` (scheduler Rule 1 fix), `fedf01e` (delete hooks + tests)

- `ActivityListView.save(_:)` — after `try modelContext.save()` succeeds, spawns `Task { await NotificationScheduler.shared.reconcile(modelContext: ctx) }`. Covers the delete path (idempotent per D57).
- `TripListView` destructive alert — reconcile after `try modelContext.save()` succeeds AND before `try? FileStorage.removeTripFolder(...)`. Cascade has already nulled Activity rows, so `reconcile()` sees them gone and cancels their pending requests.
- Created `TravellifyTests/ReminderLifecycleTests.swift` — 4 `@Test` functions (Swift Testing, `@MainActor struct`):
  - `scheduleOnEnable` (ACT-07) — toggle enabled + leadMinutes=60, save + reconcile → `mock.pending.count == 1`, identifier == activity.id.uuidString
  - `rescheduleOnDateChange` (ACT-08) — after initial schedule, mutate `startAt += 1h`, reconcile → `pending.count == 1`, identifier unchanged, trigger hour advanced by 1 (mod 24)
  - `cancelOnDelete` (ACT-08) — delete activity + save + reconcile → `pending.isEmpty`
  - `cancelOnTripCascade` (ACT-08) — delete trip with 2 reminder-enabled activities + save + reconcile → `pending.isEmpty`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] NotificationScheduler never rescheduled existing requests when fireDate changed**

- **Found during:** Task 2 `rescheduleOnDateChange` test — failed on initial run.
- **Issue:** Wave 2 `NotificationScheduler.reconcile` diff logic was `toCancel = existingIDs − desiredIDs` and `toSchedule = candidates where !existingIDs.contains(id)`. When a user edits an activity's `startAt` (identifier stays the same UUID), the diff produced empty `toCancel` AND empty `toSchedule`, so iOS kept the stale trigger indefinitely. This silently broke ACT-08 (reschedule-on-edit) on device.
- **Fix:** Augmented the diff with a stale-trigger check. Build `pendingByID: [String: UNNotificationRequest]`, and for every `(activity, desiredFireDate)` candidate whose identifier IS in `existingIDs`, compare `normalizedComponents(from: desiredFireDate)` against `triggerFireDate(existing.trigger)`. If different → add id to `toCancelStale` AND append to `toSchedule`. Final `toCancel = toCancelMissing ∪ toCancelStale`.
- **Files modified:** `Travellify/Shared/NotificationScheduler.swift`
- **Commit:** `9c20c82`
- **Test result:** All 4 `ReminderLifecycleTests` green after fix; `NotificationSchedulerTests` still green (existing `diffIdempotent`/`rescheduleDiff` continue to pass — their expectations were on identifier diffs, which this change preserves).

Added two `private static` helpers: `normalizedComponents(from:)` and `triggerFireDate(_:)` — both strip calendar/timezone identity and extract only `[year, month, day, hour, minute]` into a plain `DateComponents` for value equality comparison. This avoids false "triggers differ" flags from `Calendar.current` capturing a different backing instance across reconcile calls.

## Auth Gates Encountered

None.

## Known Stubs

None.

## Output Notes (per plan's `<output>` block)

- **ContentView NavigationPath shape:** already `@State private var path: [AppDestination] = []` from Phase 4 — no restructuring needed. Deep-link intent is observed via a plain `.onChange(of: appState.pendingDeepLink)` on the NavigationStack.
- **Additional trip-delete sites:** none. `TripDetailView` has no delete button. Searched with `grep -rn "modelContext.delete" Travellify/` — only delete sites are `TripListView.swift:71` (trip alert) and `ActivityListView.swift:121` (activity swipe) for the subsystem reminder path. Other deletes (Document, PackingItem, PackingCategory, DestinationDraft) don't affect reminder schedule state.
- **@preconcurrency warnings under Swift 6.0:** none observed. `xcodebuild build` clean, no warnings on the delegate conformance.
- **Tech-debt note:** Migrate `AppDelegate`'s `UNUserNotificationCenterDelegate` conformance from `@preconcurrency` to Swift 6.2 isolated conformance (`nonisolated(unsafe)` on the protocol witness, or explicit `@MainActor` isolated conformance) when the project Xcode version bumps past Swift 6.0 (RESEARCH Pitfall 9).
- **pbxproj UUIDs used:**
  - `AppDelegate.swift` → buildFile `AD0504010203040506070801`, fileRef `AD0504010203040506070802`
  - `AppState.swift` → buildFile `AD0504010203040506070803`, fileRef `AD0504010203040506070804`
  - `ReminderLifecycleTests.swift` → buildFile `AD0504010203040506070805`, fileRef `AD0504010203040506070806`

## Verification

**Build:** `DEVELOPER_DIR=.../Xcode xcodebuild build -project Travellify.xcodeproj -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e'` → **BUILD SUCCEEDED** (no warnings).

**Full test suite:** `xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination '...iPhone 16e'` → **0 failures**.

Phase 5 Wave 0 gap closure — all 5 suites present and green:
- `TravellifyTests/ReminderSchemaTests` (05-01) — 4/4 passed
- `TravellifyTests/ReminderFireDateTests` (05-01) — 6/6 passed
- `TravellifyTests/NotificationSchedulerTests` (05-02) — 6/6 passed
- `TravellifyTests/PermissionStateTests` (05-03) — 6/6 passed
- `TravellifyTests/ReminderLifecycleTests` (05-04) — 4/4 passed

Phase 1–4 suites (TripTests, PartitionTests, SchemaTests, ActivityTests, PackingTests, DocumentTests, FileStorageTests, ImportTests, ViewerTests, SmokeTests, PackingProgressTests, ActivityGroupingTests, DayLabelTests, NextUpcomingTests) — all green, no regressions.

## Commits

| # | Commit    | Type  | Message                                                     |
|---|-----------|-------|-------------------------------------------------------------|
| 1 | `04813d0` | feat  | wire AppDelegate + AppState + scenePhase reconcile          |
| 2 | `9c20c82` | fix   | reschedule pending request when fireDate changes (Rule 1)   |
| 3 | `fedf01e` | feat  | delete-path reconcile + ReminderLifecycleTests              |

## Self-Check

- [x] `Travellify/App/AppDelegate.swift` exists
- [x] `Travellify/App/AppState.swift` exists
- [x] `TravellifyTests/ReminderLifecycleTests.swift` exists
- [x] Commit `04813d0` in git log
- [x] Commit `9c20c82` in git log
- [x] Commit `fedf01e` in git log

## Self-Check: PASSED
