# Phase 5: Notifications — CONTEXT

**Gathered:** 2026-04-22
**Status:** Ready for research + planning
**Goal:** Users can opt in to a local reminder per activity, with full lifecycle (reschedule on edit, cancel on delete) and a 64-cap scheduler.
**Requirements:** ACT-07, ACT-08, ACT-09.
**Depends on:** Phase 4 (complete + verified).

<domain>
## Phase Boundary

Per-activity local notification with:
1. Opt-in toggle + lead-time picker in `ActivityEditSheet`.
2. Lifecycle: schedule on enable, reschedule when `startAt` or `reminderLeadMinutes` changes, cancel on disable / activity-delete / trip-cascade-delete.
3. A global `NotificationScheduler` that respects iOS's 64-pending-request cap by keeping only the soonest 64 globally-ranked reminders scheduled.

**Not in scope** (explicitly deferred):
- Tap-actions (Mark done / Snooze) — requires UNNotificationCategory plumbing + completion-state model changes.
- Background refresh (BGTaskScheduler) — relies on non-guaranteed iOS background execution.
- Global / per-trip mute. No trip-level reminder default.
- Activity-detail screen. Reminder controls live inside the existing edit sheet.
- Snooze / repeat. One-shot UNCalendarNotificationTrigger per activity.
</domain>

## Inherited (locked by prior phases — do not re-decide)

- **Stack:** SwiftUI + SwiftData, iOS 17+, Swift 6 strict concurrency, Swift Testing.
- **CloudKit-safe SwiftData:** UUID defaults on all `@Model`, optional inverses, no `@Attribute(.unique)`, no `@Attribute(.externalStorage)`, no `.deny` delete rules. Grep-gated in `SchemaTests`.
- **Additive schema changes stay in SchemaV1** (no V2 migration needed — confirmed Phases 2 and 4).
- **Single add+edit sheet pattern** — `ActivityEditSheet(activity: Activity?, trip: Trip)`. Reminder controls live inside this sheet (Section after Notes).
- **Soft-warn pattern** — non-blocking inline warning row with orange SF Symbol for advisory UI (see D41 in 04-CONTEXT.md).
- **Task.detached** may only capture Sendable primitives (String, Data, URL, Int, UUID). No `@Model` across actor boundaries. All notification-center calls stay on a background Task; model mutations stay on `@MainActor`.
- **Canonical simulator:** `iPhone 16e`. **Build prefix:** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **pbxproj hand-edit rule:** every new Swift file gets 4 entries (PBXBuildFile, PBXFileReference, PBXGroup child, Sources build-phase). No XcodeGen.

<decisions>
## Implementation Decisions

### Lead-time UX

- **D50 — Preset picker, not custom minutes.** Reminder lead-time is a `Picker` with four presets: **15 min / 1 hour / 3 hours / 1 day**, stored as `Int` minutes (15, 60, 180, 1440). No custom stepper, no "at time of event" (0-minute) option.
- **D51 — Default lead-time is 1 hour** (matches Apple Calendar default). Applied on first toggle-on when `reminderLeadMinutes == nil`.
- **D52 — Schema additions on `Activity` (additive, SchemaV1):**
  ```swift
  var isReminderEnabled: Bool = false
  var reminderLeadMinutes: Int? = nil   // minutes before startAt; nil when reminder off
  ```
  CloudKit-safe: both have defaults; no new `@Model`; no relationship. SchemaV1 model count stays at 6.

### Permission priming + denied state

- **D53 — Lazy permission with custom priming sheet.** On the first time a user toggles a reminder ON, show a Travellify-branded `.sheet` explaining "Travellify reminds you before each activity so you're never late." with a single "Enable reminders" button that triggers `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])`. Do NOT fire the authorization request at app launch. Matches ROADMAP success criteria #1 verbatim.
- **D54 — Denied/revoked permission UX.** Reminder toggle is rendered `.disabled(true)` with a subtitle row `"Notifications disabled. Enable in Settings."` and a `Button` (plain style) `"Open Settings"` that calls `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`. Authorization status re-checked every time `ActivityEditSheet` appears (`.task {}`) so the state refreshes when the user returns from Settings.
- **D55 — Priming sheet is one-shot.** Track `hasSeenReminderPriming` in `UserDefaults`. Once dismissed (regardless of grant/deny), future toggle-ons skip the priming and go straight to the system dialog if status is `.notDetermined`, or straight to scheduling if `.authorized`.

### 64-cap scheduler policy

- **D56 — Eviction policy: soonest-64 globally.** `NotificationScheduler.reconcile()` ranks all `Activity` rows where `isReminderEnabled == true && fireDate > now` by absolute `fireDate` ascending, takes the first 64, and schedules exactly those. Older (already-fired) fire dates are ignored. Crosses trip boundaries — no per-trip quota.
- **D57 — Re-evaluate triggers:**
  1. App foreground (`ScenePhase == .active` transition).
  2. Any activity add / edit / delete / toggle change (called from `ActivityEditSheet.save`, `ActivityListView.delete`, and `TripDetailView`/`TripListView` delete paths).
  - Both triggers call the same `reconcile()` entry point. Idempotent.
  - No `BGTaskScheduler` in v1.
- **D58 — Source of truth: SwiftData user-intent + system-state reconciliation.**
  - `Activity.isReminderEnabled` + `reminderLeadMinutes` = user intent (what the user wants scheduled).
  - `UNUserNotificationCenter.pendingNotificationRequests` = system truth (what iOS has actually scheduled).
  - `reconcile()` fetches both, diffs by identifier, and calls `add(_:)` / `removePendingNotificationRequests(withIdentifiers:)` to bring system state to match user intent (capped at 64).
  - No separate SwiftData mirror of "what's scheduled" — avoids drift.
- **D59 — Silent eviction in v1.** When >64 reminders are enabled, evicted ones keep `isReminderEnabled == true` but simply aren't scheduled. No UI badge, no toast. Acceptable because (a) it's a power-user edge case, (b) evicted reminders auto-schedule as earlier ones fire and `reconcile()` runs on foreground. Revisit in Polish phase if real users hit it.
- **D60 — Notification request identifier = activity UUID (stringified).** One `UNNotificationRequest` per activity. `removePendingNotificationRequests(withIdentifiers: [uuid.uuidString])` cleanly cancels. No composite keys.

### Notification content + edit-sheet placement

- **D61 — Notification content format:**
  - `content.title` = `activity.title`
  - `content.body` = `"\(trip.name) · \(timeString) · \(location)"` — location segment omitted (no trailing separator) when `activity.location` is nil or empty.
  - `content.sound` = `.default`.
  - `content.userInfo["activityID"]` = activity UUID string for deep-link on tap.
  - Example: `"Louvre tour"` / `"Paris trip · 2:00 PM · Rue de Rivoli"`.
- **D62 — No tap actions in v1.** No `UNNotificationCategory`, no "Mark done", no "Snooze". Tapping the notification launches the app and routes to the activity via `userInfo["activityID"]` → lookup `Activity` by UUID → push `AppDestination.activityList(trip.persistentModelID)` + open `ActivityEditSheet(activity:, trip:)`. Deep-link plumbing is a single handler in `TravellifyApp.onReceive(NotificationCenter... UNUserNotificationCenter delegate)`.
- **D63 — Trigger type: `UNCalendarNotificationTrigger`** (not `UNTimeIntervalNotificationTrigger`). Reason: respects DST and user's locale calendar; naturally tied to a `DateComponents` derived from `startAt.addingTimeInterval(-TimeInterval(leadMinutes * 60))`. Non-repeating.
- **D64 — Edit-sheet placement: dedicated Reminder Section after Notes.**
  - Form layout order (ActivityEditSheet):
    1. Title
    2. Date & time (compact DatePicker)
    3. Location
    4. Notes
    5. **Reminder** (new Section, D64):
       - `Toggle("Reminder", isOn: $isReminderEnabled)`
       - When `isReminderEnabled == true` AND authorization is `.authorized` or `.notDetermined`: show `Picker("Notify", selection: $leadMinutes) { … }` with 4 preset cases.
       - When denied/revoked: the Toggle is `.disabled(true)` with subtitle "Notifications disabled" + "Open Settings" button.
    6. Inline out-of-range soft-warn row (existing D41).

### Claude's Discretion

- Internal organization of `NotificationScheduler` (class vs actor vs struct with static methods). Must be `@MainActor`-safe entry points but heavy work (fetching `pendingNotificationRequests`) should run on a background `Task`.
- Priming-sheet visual design — match Settings-section aesthetic; copy can be refined during implementation.
- Whether the priming sheet is a `.sheet` or a full-screen modal; both acceptable if the single "Enable" CTA is obvious.
- Error handling inside `reconcile()` — log + continue on individual request failures; do not let one bad request abort the batch.
- Whether `reconcile()` is debounced when fired from consecutive mutations; implement if needed after profiling.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project planning
- `.planning/PROJECT.md` — Vision, stack constraints (iOS 17+, SwiftUI, SwiftData, Swift 6).
- `.planning/REQUIREMENTS.md` — ACT-07/08/09 definitions.
- `.planning/ROADMAP.md` §"Phase 5: Notifications" — Goal + 4 Success Criteria (the acceptance bar).
- `.planning/STATE.md` — Current milestone state.
- `.planning/CONVENTIONS.md` — 10+ project-wide gotchas (pbxproj 4-entry, CloudKit-safe SwiftData, Swift 6 `@MainActor` rules, `Task.detached` Sendable-only rule, stale SourceKit diagnostics).

### Prior phase contexts that feed Phase 5
- `.planning/phases/01-foundation-trips/01-CONTEXT.md` — Schema V1 + CloudKit-safe rules + NavigationStack routing pattern.
- `.planning/phases/04-activities-core/04-CONTEXT.md` — Activity schema, ActivityEditSheet structure (D43), edit-sheet placement rules (D41 soft-warn row), AppDestination.activityList routing (D47).
- `.planning/phases/04-activities-core/04-VERIFICATION.md` — Confirmed Phase 4 pass state; Phase 5 builds on a verified baseline.

### Code anchors (read before planning)
- `Travellify/Models/Activity.swift` — adds `isReminderEnabled: Bool` + `reminderLeadMinutes: Int?`.
- `Travellify/Models/SchemaV1.swift` — no model-list change; Activity field additions only.
- `Travellify/Models/Trip.swift` — cascade `.activities` must also result in pending-notification cancellation (via `reconcile()` after save).
- `Travellify/Features/Activities/ActivityEditSheet.swift` — new Reminder Section after Notes (D64).
- `Travellify/Features/Activities/ActivityListView.swift` — call `reconcile()` after `delete(activity)`.
- `Travellify/App/TravellifyApp.swift` — install `UNUserNotificationCenterDelegate` for deep-link handling (D62); wire `ScenePhase` → `reconcile()` on `.active` (D57).
- `Travellify/Shared/` — new `NotificationScheduler.swift` + `ReminderLeadTime.swift` land here (sibling to `ActivityDateLabels.swift`).

### External / Apple references (open questions for researcher)
- Apple — `UNUserNotificationCenter`, `UNCalendarNotificationTrigger`, `UNNotificationContent`, `UNNotificationRequest`.
- Apple HIG — Notifications + the "ask in context" priming pattern.
- Apple — `UIApplication.openSettingsURLString` pattern for denied permissions.
- WWDC — "What's new in User Notifications" sessions (any iOS 17 / 18 guidance on authorization UX).
- Known constraint: iOS caps **pending** notification requests at 64 per app (documented). Need to confirm behavior when `add(_:)` is called for the 65th request — does it fail silently, error, or evict?

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ActivityEditSheet.swift` — existing Form scaffolding, soft-warn row pattern (D41) directly reusable for the "Notifications disabled" advisory row.
- `ActivityDateLabels.swift` — existing cached `DateFormatter` and time-label helpers. The notification body's `timeString` can reuse `ActivityDateLabels.timeLabel(for:)`.
- `AppDestination.activityList(PersistentIdentifier)` (D47) — already in place; notification tap re-uses this route without enum changes.
- `TravellifyApp.swift` — existing ModelContainer setup point; add UNUserNotificationCenterDelegate + ScenePhase observer here.

### Established Patterns
- **Trip-scoped @Query + Dictionary(grouping:)** — for the global 64-cap reconcile we instead need an **unscoped** `@Query` or a direct `modelContext.fetch(FetchDescriptor<Activity>)` spanning all trips. Prefer the direct fetch inside `NotificationScheduler.reconcile()` so we don't pin a view to a giant query.
- **Single edit sheet for create + edit** (D43) — keep all reminder controls in the one sheet.
- **Additive SwiftData fields stay in SchemaV1** (D10, D40 precedents) — same approach for D52.
- **Swift 6 `@MainActor` inference** on static View helpers — applies to any View-adjacent notification handlers. Scheduler logic runs on a background Task to keep main thread clear.

### Integration Points
- `Trip.activities` delete-cascade already exists. The cascade itself doesn't call UNUserNotificationCenter — we call `reconcile()` right after trip save, which will see the activity rows gone and cancel their pending requests.
- Activity row tap / row swipe-delete in `ActivityListView` — add a `reconcile()` call after the save.
- `ActivityEditSheet.save()` — call `reconcile()` after the `modelContext.save()` whenever a save mutates `isReminderEnabled`, `reminderLeadMinutes`, or `startAt`.

</code_context>

<specifics>
## Specific Ideas

- Copy for the priming sheet (not locked — implementation detail):
  > **Travellify wants to send reminders**
  > Get a heads-up before each activity so you're never late.
  > [Enable reminders]
- Notification body example: `"Paris trip · 2:00 PM · Rue de Rivoli"` (`trip.name · time · location`). Separator is `" · "` (space + middle-dot + space) matching existing day-label / next-up card style from Phase 4.
- Identifier scheme: raw `activity.id.uuidString`. No prefix. If collisions with future phases are a concern, prefix `"activity-"` — researcher may call this.
</specifics>

<deferred>
## Deferred Ideas

- **Tap actions** (Mark done / Snooze) — requires `UNNotificationCategory` registration + an `isCompleted` / `snoozedUntil` field. Out of scope for Phase 5. Candidate for Phase 6 Polish or a post-v1 milestone.
- **Global notifications mute** — single Settings toggle that disables all reminders app-wide. Not a phase-5 requirement. Candidate for Phase 6 Polish alongside DOC-08 Face ID.
- **Per-trip notifications mute** — "Mute all reminders for this trip." Defer.
- **Snooze / repeat reminders** — needs non-trivial UX + handling. Defer.
- **Badge on affected activity rows when evicted by the 64-cap** (D59 counter-proposal) — revisit if users hit it.
- **BGTaskScheduler background refresh** — iOS doesn't guarantee execution; foreground + mutation triggers are sufficient for v1.
- **Remember last lead-time choice per user** — UserDefaults state. Small UX polish, not phase-critical.
- **"At time of event" (0-minute lead)** preset — usually too late to act on.

</deferred>

## Test coverage (for gsd-planner to include)

- **`ReminderSchemaTests`** — Activity gains `isReminderEnabled` (default false) + `reminderLeadMinutes` (default nil); CloudKit-safe grep gates still pass; SchemaV1 model count unchanged.
- **`ReminderFireDateTests`** — pure function `fireDate(for: Activity) -> Date` computes `startAt - leadMinutes * 60` correctly across DST boundaries; returns nil when `isReminderEnabled == false` or `reminderLeadMinutes == nil`.
- **`NotificationSchedulerTests`** — given N mock activities with known `fireDate`s, `reconcile()` selects the soonest-64 globally; past `fireDate`s are ignored; identifiers match activity UUIDs. Exercised with an injected mock `NotificationCenterProtocol` (not the real `UNUserNotificationCenter`).
- **`ReminderLifecycleTests`** — integration: toggling reminder on/off schedules/cancels the expected identifier; changing `startAt` updates the trigger; deleting activity cancels; deleting trip (cascade) cancels all its activities' reminders.
- **`PermissionStateTests`** — authorization state transitions (`notDetermined` → `authorized` → denied-via-Settings) produce the expected enabled/disabled UI state derivation.

## Open questions for gsd-phase-researcher

1. Does `UNUserNotificationCenter.add(_:)` fail silently, throw, or evict when called for the 65th pending request? (Affects D56 reconciler correctness.)
2. iOS 17+ best-practice pattern for the `UNUserNotificationCenterDelegate` lifecycle — adopt in `@main App` via `@UIApplicationDelegateAdaptor`, or assign delegate on a view-lifecycle hook?
3. Swift 6 strict-concurrency annotation pattern for `UNUserNotificationCenterDelegate` methods (they're called from a non-main queue). Pattern: async bridge onto `@MainActor` for model lookups.
4. Correct idiom to derive `DateComponents` for `UNCalendarNotificationTrigger` from an absolute `Date` — `Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)`?
5. Behavior of pending requests after force-quit / device reboot / app update — are they preserved? (Affects whether the foreground `reconcile()` is sufficient after reinstall.)
6. Any Xcode 26 / Swift 6 quirks with `UNNotificationRequest` Sendable warnings when crossing actor boundaries.

## Next steps

Run `/gsd-plan-phase 5`. The planner should break work into 4 plans:
1. **05-01** — Activity schema additions (D52) + ReminderLeadTime enum + `fireDate` helper + schema tests (ReminderSchemaTests, ReminderFireDateTests).
2. **05-02** — `NotificationScheduler.swift` + permission gateway + reconcile() logic + NotificationSchedulerTests with injected mock notification center.
3. **05-03** — `ActivityEditSheet` Reminder Section (D64) + priming sheet (D53) + denied-state UI (D54) + reconcile hooks on save.
4. **05-04** — App-level wiring: UNUserNotificationCenterDelegate (D62 deep-link) + ScenePhase → reconcile (D57) + trip/activity delete reconcile hooks + ReminderLifecycleTests.

---

*Phase: 05-notifications*
*Context gathered: 2026-04-22*
