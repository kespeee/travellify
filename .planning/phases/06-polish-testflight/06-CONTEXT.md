# Phase 6: Polish + TestFlight Prep — CONTEXT

**Gathered:** 2026-04-23
**Status:** Ready for research + planning
**Goal:** Ship a polished, internally-testable TestFlight build covering accumulated UI rough edges, trip-level reminders, and the minimum submission prerequisites.
**Requirements:** TRIP-07 / TRIP-08 / TRIP-09 (new — trip reminder lifecycle, defined below).
**Depends on:** Phase 5 (complete + verified + pushed).

<domain>
## Phase Boundary

Three parallel tracks:

1. **UI polish bundle** — six small, targeted fixes surfaced from Phase 1–5 UAT:
   - Document thumbnail aspect ratio = 3:4.
   - Document name horizontally centered in list row.
   - Default document names on import (`doc-1`, `doc-2`, …) per-trip sequential.
   - Packing empty state centered vertically (currently top-aligned).
   - TripEditSheet: if `startDate > endDate`, auto-align `endDate = startDate`; end-date picker clamped to `startDate...distantFuture`.
   - ActivityEditSheet: DatePicker clamped to `trip.startDate...trip.endDate` in both create + edit. Soft-warn row retained as a read-only artifact for legacy out-of-range activities until user reopens the picker (picker naturally snaps into range).

2. **Trip-level reminders (new feature, mirrors ACT-07/08/09)** — Reminder Section inside TripEditSheet. Fires before trip start. Shares `NotificationScheduler`, 64-cap, permission/denied-state patterns, and identifier-based reconciliation with activity reminders.

3. **TestFlight submission minimums** — placeholder app icon, `PrivacyInfo.xcprivacy`, version/build/bundle-ID verification. **No archive / upload step in this phase** — that's a manual user step post-phase.

**Explicitly out of scope** (deferred):

- **DOC-08 (Face ID / passcode lock on Documents)** — moved to v1.x polish backlog; not shipping in first TestFlight.
- Error-handling audit pass.
- Accessibility audit (Dynamic Type, VoiceOver).
- Additional confirmation dialogs (category / document / activity delete).
- Actual archive + App Store Connect upload (user-run step).
- App Store metadata / screenshots / listing copy.
- Real branded app icon (placeholder only).
</domain>

## Inherited (locked by prior phases — do not re-decide)

- **Stack:** SwiftUI + SwiftData, iOS 17+, Swift 6 strict concurrency, Swift Testing.
- **CloudKit-safe SwiftData:** UUID defaults on all `@Model`, optional inverses, no `@Attribute(.unique)`, no `@Attribute(.externalStorage)`, no `.deny` delete rules. Grep-gated in `SchemaTests`.
- **Additive schema changes stay in SchemaV1** (no V2 migration — confirmed Phases 2, 4, 5).
- **Native iOS permission alert pattern** — no custom priming sheet. `requestAuthorization` fires directly on first toggle-on; `.notDetermined` branch skips to request (locked Phase 5, commit 4b08141).
- **Denied-state tappable alert pattern** — toggle is NOT `.disabled`; tapping it in denied state presents `.alert("Notifications are off")` with Open Settings / Cancel buttons. No persistent disabled row (locked Phase 5, commit e6a95cc).
- **NotificationScheduler soonest-64 reconcile** — identifier-based diff against `pendingNotificationRequests`; Rule 1 fire-date drift detection (locked Phase 5, commit 9c20c82).
- **AppState deep-link singleton** — `pendingDeepLink` resolved at `ContentView` level, trip scope; notification tap routes via `userInfo["activityID"]` (Phase 5 D63).
- **Canonical simulator:** `iPhone 16e`. **Build prefix:** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **pbxproj hand-edit rule:** every new Swift file gets 4 entries (PBXBuildFile, PBXFileReference, PBXGroup child, Sources build-phase). No XcodeGen.
- **Info.plist auto-generated** via `INFOPLIST_KEY_*` build settings — additions (e.g., `NSUserNotificationsUsageDescription`) land in pbxproj, not a file.

<decisions>
## Implementation Decisions

### UI Polish

- **D70 — Document thumbnail aspect ratio is 3:4 portrait.** Applied in `DocumentRow` (DocumentListView). `.aspectRatio(3/4, contentMode: .fit)` with a fixed width; image filled via `.scaledToFill()` + `.clipped()`. PDF thumbnails rendered through existing PDFKit page-1 path, then letterboxed into the 3:4 frame.

- **D71 — Document display name is centered horizontally** in the row, not leading-aligned. `HStack` → thumbnail (leading) + `Text(displayName).frame(maxWidth: .infinity, alignment: .center)` + trailing chevron. Multiline truncation = `.middle`.

- **D72 — Default document names are `doc-<N>` per-trip sequential.**
  - On import (scan / photo / file), compute `N = max(existing doc-K integer suffix in this trip) + 1`, starting from 1.
  - Regex for extraction: `^doc-(\d+)$` — matches only exact `doc-N` names, ignoring user-renamed values.
  - If no matches exist, `N = 1`.
  - No gap reuse: if `doc-1`, `doc-3` exist (user deleted `doc-2`), next new doc is `doc-4`.
  - Applies to all three import paths — replaces prior auto-names (`Scan YYYY-MM-DD`, `Photo YYYY-MM-DD`, source filename).
  - Rename UI still available post-import; renamed docs are treated as non-matching for the counter.
  - Helper lives in `DocumentImporter` (not view layer): `nextDefaultName(in: Trip) -> String`.

- **D73 — Packing empty state centered vertically.** `EmptyPackingListView` wrapped in `VStack { Spacer(); content; Spacer() }.frame(maxHeight: .infinity)`. Preserves existing icon + copy + CTA; only layout changes.

- **D74 — Trip date self-consistency.** In `TripEditSheet`:
  - When `startDate` picker changes and new value > current `endDate`, auto-set `endDate = startDate`.
  - End-date picker uses `in: startDate...` range (closed lower bound on start date).
  - Start-date picker is unrestricted (travel can be planned into past for record-keeping, per Phase 1 behavior — do not regress).
  - No validation error UI needed — picker constraint makes invalid state unreachable post-fix.

- **D75 — Activity DatePicker clamped to trip range (create + edit).**
  - `DatePicker("Starts", selection: $startAt, in: trip.startDate...trip.endDate, displayedComponents: [.date, .hourAndMinute])`.
  - Applies identically to create mode and edit mode.
  - **Legacy rows:** pre-existing activities saved with `startAt` outside trip range still render the soft-warn row on edit-sheet open (their `startAt` state loads unchanged). The picker's `in:` range will visually snap/clamp the date wheel on first interaction; the soft-warn row self-dismisses as soon as `isOutsideTripRange` evaluates `false`.
  - Soft-warn code path is **retained** (not deleted) for this legacy case — also future-proofs against trip-date edits that push an activity out of range.

### Trip-Level Reminders

- **D76 — Schema additions on `Trip` (additive, SchemaV1):**
  ```swift
  var isReminderEnabled: Bool = false
  var reminderLeadMinutes: Int? = nil  // nil when reminder off
  ```
  CloudKit-safe: both defaulted; no new `@Model`; no relationship. SchemaV1 model count stays at 6.

- **D77 — Lead-time presets (trip scope, distinct from activity presets).**
  New enum `TripReminderLeadTime` (separate from `ReminderLeadTime`):
  - `.oneDay` = 1440 min
  - `.threeDays` = 4320 min
  - `.oneWeek` = 10080 min
  - `.twoWeeks` = 20160 min
  - Default = `.threeDays` on first toggle-on when `reminderLeadMinutes == nil`.
  - Rationale: trip planning horizon is days/weeks; the 15-min / 1-hour activity presets are nonsensical for trips.

- **D78 — Fire-time anchor = `trip.startDate − leadMinutes`.** Reuses the existing `ReminderFireDate.fireDate(start:leadMinutes:)` helper (signature already absolute-time math). No special 09:00-anchor adjustment in v1 — if `trip.startDate` is midnight-anchored (Phase 1 day-only DatePicker), a 1-day reminder fires at prior-day midnight. **Acceptance:** UAT will validate whether this feels right; if it surfaces complaints, a follow-up polish can shift to a 9am local anchor. Locked as "simple-and-shared" for this phase.

- **D79 — Notification identifier = `"trip-" + trip.uuid.uuidString`.**
  - Distinguishes trip reminders from activity reminders (activity identifiers are bare UUID strings per Phase 5 D60).
  - Scheduler reconcile logic remains unchanged — it fetches all `Trip` rows with `isReminderEnabled == true && fireDate > now` AND all `Activity` rows with same criteria, ranks the union by fire date, takes soonest 64.

- **D80 — Notification content format (trip):**
  - `content.title` = `"Trip starting soon"` (generic; trip name lives in body for visual hierarchy).
  - `content.body` = `"\(trip.name) · \(leadTimeLabel)"` — e.g., `"Paris trip · in 3 days"`. Destination omitted in v1 (keeps body single-line on narrow devices; destinations can be multi-stop so joining is noisy).
  - `content.sound` = `.default`.
  - `content.userInfo["tripID"]` = trip UUID string.

- **D81 — Deep-link on trip notification tap → trip detail screen.**
  - Extend `PendingDeepLink` enum with `.trip(UUID)` case.
  - `AppDelegate.userNotificationCenter(_:didReceive:)` inspects `userInfo` — `"activityID"` routes to activity (existing), `"tripID"` routes to trip.
  - `ContentView.onChange(of: appState.pendingDeepLink)` resolves UUID → Trip → pushes `AppDestination.tripDetail(trip.persistentModelID)` — *new* case if not already present; if current router routes trips differently, mirror the activity deep-link pattern exactly.
  - Clears intent after push.

- **D82 — Reminder Section UI lives in `TripEditSheet`**, mirroring `ActivityEditSheet` structure.
  - Placement: after Destinations section, before toolbar Save.
  - Reuses the exact same `handleToggleChange` / `requestAuthAndEnable` / `refreshAuthStatus` / `showDeniedAlert` / native-permission-prompt flow from `ActivityEditSheet`.
  - Dirty-tracking snapshot extended: `initialIsReminderEnabled`, `initialLeadMinutes`, `initialStartDate` (not `initialStartAt` — trip version anchors on `startDate`).
  - Reconcile fires on save when any of the three reminder-affecting fields changed, or when trip is newly created.

- **D83 — Lifecycle hooks (TRIP-08, TRIP-09):**
  - **Trip date edit →** scheduler reconcile auto-handles reschedule via identifier drift detection (Phase 5 Rule 1 fix already accounts for it — `"trip-<uuid>"` identifier with changed fireDate triggers cancel + readd).
  - **Trip delete →** reconcile call in `TripListView` delete path already exists for activity cascade; it now also cancels the trip's own reminder because the `Trip` row is gone from the fetch set. No new code path.
  - **Toggle off on save →** reconcile fires; identifier removed from user-intent set; scheduler cancels.

- **D84 — New requirements in REQUIREMENTS.md:**
  - **TRIP-07**: User can opt in to a local notification reminder for a trip; when enabled, a `UNNotificationRequest` is scheduled to fire before the trip's start date.
  - **TRIP-08**: When a trip's start date changes, its pending notification is rescheduled; when deleted, its pending notification is cancelled.
  - **TRIP-09**: Trip reminders share the soonest-64 eviction pool with activity reminders (identifier-prefix `trip-` distinguishes them).
  - Update Traceability table: TRIP-07/08/09 → Phase 6 → Pending.
  - **DOC-08 moves from Phase 6 → v1.x POLISH backlog row** (add POLISH-05: Face ID / passcode lock on Documents section — LocalAuthentication framework).

### TestFlight Prep (Submission Minimums)

- **D85 — Placeholder app icon.**
  - Single 1024×1024 PNG (flat-color background + bold "T" glyph, SF-aligned) committed at `Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png`.
  - `Contents.json` populated for all required iOS 17+ sizes (single-size catalog uses Xcode's automatic resize when available; otherwise generate the full legacy size matrix via `sips` and commit all).
  - **Decision:** use iOS-17+ single-size asset catalog (`"size" : "1024x1024"`, `"idiom" : "universal"`) — drops the legacy-size matrix. Xcode 16 generates per-size assets at build time.
  - Placeholder acknowledged as temporary; real branded icon is a v1.1 task.

- **D86 — PrivacyInfo.xcprivacy manifest.** File committed at `Travellify/PrivacyInfo.xcprivacy`. Declares:
  - `NSPrivacyAccessedAPITypes` — `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (app access to own `UserDefaults` — covers `hasSeenReminderPriming`).
  - `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `C617.1` (file-attribute inspection for document storage).
  - `NSPrivacyAccessedAPICategoryDiskSpace` — not used; omit.
  - `NSPrivacyAccessedAPICategorySystemBootTime` — not used; omit.
  - `NSPrivacyCollectedDataTypes` = empty array (no data leaves the device).
  - `NSPrivacyTracking` = false. `NSPrivacyTrackingDomains` = empty.
  - pbxproj: add PBXFileReference + PBXBuildFile + Resources-build-phase entry for the manifest (it ships as a bundle resource).

- **D87 — Version + build + bundle ID.**
  - `MARKETING_VERSION = 1.0`.
  - `CURRENT_PROJECT_VERSION = 1`.
  - Bundle identifier: verify `com.kespeee.travellify` in pbxproj — no change unless user says otherwise.
  - Code signing left on "Automatic" — user's Apple Developer team must be selected in Xcode before archive (not a GSD task).
  - No archive / upload automation in this phase.

- **D88 — NSUserNotificationsUsageDescription key** not required for `UNUserNotificationCenter` on iOS (it's a macOS-only key). No Info.plist addition needed for notifications. Camera and Photos usage-description keys already exist from Phase 2 — verify in pbxproj `INFOPLIST_KEY_*` settings, do not re-add.
</decisions>

## Assumptions & Open Questions

1. **Trip start-date time component.** Assumption: `trip.startDate` is midnight-anchored (day-only picker from Phase 1). If not verified, the fire-time anchor per D78 may feel wrong — researcher should confirm and flag if `trip.startDate` carries a meaningful time component.
2. **Picker clamping UX for legacy out-of-range activities (D75).** Assumption: iOS `DatePicker` with `in:` range silently clamps on next interaction without visible user disruption. If it instead refuses to display the out-of-range value, the soft-warn row becomes unreachable and the edit sheet state is inconsistent — researcher should verify SwiftUI behavior on iOS 17.
3. **PrivacyInfo.xcprivacy API-reason accuracy (D86).** Assumption: `CA92.1` (UserDefaults same-app access) and `C617.1` (file timestamps for normal file-system ops) are current per Apple's May 2024 API-reason list. If Apple has updated codes by 2026-04, researcher should pull latest.
4. **`AppDestination.tripDetail` may already exist.** Mapper should confirm current enum cases before D81 specifies a new case — deep-link routing for trips may already have a case usable as-is.

## Out of Scope (Capture for Later)

- Real branded app icon (v1.1 or designer pass).
- Face ID / passcode lock on Documents (POLISH-05, v1.x).
- Trip reminder tap-actions (Mark done / Snooze).
- Per-trip reminder mute toggle that cascades to activity reminders.
- 9am local-time anchor for trip reminders (follow-up if D78 feels wrong in UAT).
- Empty-state unification across the four list views (already "clear enough" per Phase 6 scope decision).
- Confirmation dialogs for document / activity / category delete.
- Dynamic Type / VoiceOver accessibility pass.
- Archive + App Store Connect upload (user-driven manual step).

## Decision Dependencies

```
D72 (doc default naming) ── uses SwiftData @Query on Trip.documents
                            in DocumentImporter.nextDefaultName()
D76 (Trip schema) ─────────→ D82 (Reminder Section UI)
                         └─→ D83 (lifecycle hooks)
                         └─→ D84 (REQUIREMENTS.md update)
D79 (identifier prefix) ───→ NotificationScheduler fetch-union logic
D81 (deep-link) ───────────→ PendingDeepLink enum extension
                         └─→ AppDelegate didReceive handler
D86 (PrivacyInfo) ─────────→ pbxproj Resources-build-phase entry
D85 (AppIcon) ─────────────→ Assets.xcassets/AppIcon.appiconset/Contents.json
```

## Ready For

- `/gsd-plan-phase 6` — expect 3–4 waves:
  1. **UI polish bundle** (D70–D75) — independent file-level edits + DatePicker clamping.
  2. **Trip schema + TripReminderLeadTime enum + TripReminderFireDate tests** (D76, D77, D78).
  3. **TripEditSheet Reminder Section + scheduler union + deep-link extension** (D79–D83).
  4. **TestFlight minimums** (D85–D87) — icon, PrivacyInfo, version/build, pbxproj updates.
- Research focus: iOS 17 `DatePicker` clamping semantics; PrivacyInfo.xcprivacy API-reason current codes; SwiftData `@Query`-inside-importer threading (Phase 2 showed this is already patterned for main-context writes).
