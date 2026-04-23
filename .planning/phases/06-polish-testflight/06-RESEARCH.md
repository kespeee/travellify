# Phase 6: Polish + TestFlight Prep - Research

**Researched:** 2026-04-24
**Domain:** iOS app polish, SwiftUI DatePicker clamping, SwiftData additive schema, UserNotifications fetch-union, Apple privacy manifest (PrivacyInfo.xcprivacy), AppIcon asset catalog (iOS 17+).
**Confidence:** HIGH overall. Q1 / Q4 resolved by local-source evidence. Q2 resolved by Apple docs + behavior cross-reference. Q3 resolved by Apple TN3183 cross-reference (community-verified). Q5 is a pure-Swift design call with a clear recommendation.

## Summary

All five open questions from CONTEXT.md are resolved. The key landmines are (a) the DatePicker clamping story for D75 legacy out-of-range activities, which requires a documented behavior contract in the plan, and (b) the scheduler fetch-union shape for D79, which needs a small value-type to keep Trip and Activity on a single sorted pipeline without leaking `@Model` types across actor boundaries.

None of the open questions force a schema V2 migration, force a parallel trip fireDate helper, or force deviation from the locked native-permission-alert / denied-state patterns. Phase 6 can proceed as a pure additive schema pass + UI polish + one-file TestFlight prep, consistent with the CONTEXT decisions.

**Primary recommendation:** Lock a `ScheduledReminder` Sendable value type (Trip-or-Activity discriminator + fireDate + identifier + title + body + userInfoKey/Value) as the union element in `NotificationScheduler.reconcile`. Keep `ReminderFireDate.fireDate(start:leadMinutes:)` as the single helper — do not split Trip and Activity into parallel helpers. Keep the `PrivacyInfo.xcprivacy` at exactly the two reason codes identified (CA92.1 + C617.1). Use the existing single-size 1024x1024 universal `AppIcon.appiconset/Contents.json` as-is — it is already correctly structured for iOS 17+ / Xcode 16.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**UI Polish:**
- **D70** Document thumbnail aspect ratio = 3:4 portrait (`.aspectRatio(3/4, contentMode: .fit)`, `.scaledToFill()` + `.clipped()`; PDF first-page via existing path).
- **D71** Document display name horizontally centered in list row (`HStack` thumbnail + `Text(displayName).frame(maxWidth: .infinity, alignment: .center)` + trailing chevron, `.multilineTruncation = .middle`).
- **D72** Default document names = `doc-<N>` per-trip sequential. Regex `^doc-(\d+)$`. No gap reuse. Helper lives in `DocumentImporter.nextDefaultName(in: Trip) -> String`. Applies to scan, photo, file paths. Replaces all three prior auto-names.
- **D73** Packing empty state vertically centered (`VStack { Spacer(); content; Spacer() }.frame(maxHeight: .infinity)`).
- **D74** Trip date self-consistency: auto-align `endDate = startDate` when start > end; end-date picker `in: startDate...`; start-date unrestricted.
- **D75** Activity DatePicker clamped to `trip.startDate...trip.endDate` in create + edit. Legacy out-of-range rows keep the soft-warn artifact; picker snaps into range on first interaction. Soft-warn code path retained.

**Trip-Level Reminders:**
- **D76** Additive on `Trip` in SchemaV1: `var isReminderEnabled: Bool = false`, `var reminderLeadMinutes: Int? = nil`. No new `@Model`. No relationship.
- **D77** New `TripReminderLeadTime` enum (separate from `ReminderLeadTime`): 1d / 3d / 1w / 2w; default `.threeDays`.
- **D78** Fire anchor = `trip.startDate - leadMinutes`. Reuses `ReminderFireDate.fireDate(start:leadMinutes:)`. No 9am adjustment in v1.
- **D79** Identifier = `"trip-" + trip.uuid.uuidString`. Scheduler fetches Trip + Activity, ranks union by fireDate, takes soonest 64.
- **D80** Content: title `"Trip starting soon"`, body `"\(trip.name) · \(leadTimeLabel)"`, sound `.default`, `userInfo["tripID"]` = trip UUID string.
- **D81** Extend `PendingDeepLink` with `.trip(UUID)`. `AppDelegate.didReceive` branches on `tripID` vs `activityID`. `ContentView` pushes `AppDestination.tripDetail(trip.persistentModelID)`.
- **D82** Reminder Section UI in `TripEditSheet` after Destinations, mirroring ActivityEditSheet. Reuses toggle / auth / denied-alert / scenePhase refresh pattern verbatim. Dirty snapshot triad: `initialIsReminderEnabled`, `initialLeadMinutes`, `initialStartDate`.
- **D83** Trip date edit / trip delete / toggle-off all resolved by the existing reconcile drift-detection (Phase 5 Rule 1). No new lifecycle code path.
- **D84** New requirements TRIP-07 / TRIP-08 / TRIP-09 added to REQUIREMENTS.md; DOC-08 demoted to POLISH-05.

**TestFlight Prep:**
- **D85** Placeholder app icon. Single 1024x1024 universal entry in `AppIcon.appiconset/Contents.json`. Xcode 16 auto-resizes.
- **D86** `PrivacyInfo.xcprivacy` with `CA92.1` (UserDefaults) + `C617.1` (file timestamps). Tracking false. Data types empty. pbxproj: PBXFileReference + PBXBuildFile + Resources build phase.
- **D87** `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`, bundle ID `com.kespeee.travellify` (verify, do not change). No archive/upload.
- **D88** No `NSUserNotificationsUsageDescription` (macOS-only key). Camera usage-description already present.

### Claude's Discretion

- Exact file path for `TripReminderLeadTime.swift` within `Travellify/Shared/` (sibling of `ReminderLeadTime.swift` is the obvious slot).
- Shape of the scheduler fetch-union value type (this research recommends `ScheduledReminder` — see Track 2).
- Test fixture shape for trip-reminder fireDate math.
- Whether to add a `SchemaTests` CloudKit-safety assertion for the two new `Trip` fields (recommended — mirrors Activity D52 precedent).

### Deferred Ideas (OUT OF SCOPE)

- DOC-08 / POLISH-05 (Face ID lock) — v1.x backlog.
- Real branded app icon — v1.1.
- Trip reminder Mark-done / Snooze notification actions.
- 9am local anchor for trip reminders (follow-up only if UAT complains about midnight firings).
- Empty-state unification across all four list views.
- Confirmation dialogs for category / document / activity delete.
- Dynamic Type / VoiceOver audit.
- Error-handling audit.
- Archive + App Store Connect upload (manual user step, post-phase).
- App Store metadata / screenshots / listing copy.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRIP-07 | User can opt in to a local notification reminder for a trip; a `UNNotificationRequest` is scheduled to fire before `trip.startDate` by a user-selected lead time (1d / 3d / 1w / 2w). | Track 2: schema additions (D76), `TripReminderLeadTime` enum (D77), Reminder Section in TripEditSheet (D82), reuse of `ReminderFireDate.fireDate` (D78). |
| TRIP-08 | When `trip.startDate` changes its pending reminder is rescheduled; when the trip is deleted its pending reminder is cancelled. | Track 2: existing Phase 5 Rule 1 drift detection in `NotificationScheduler.reconcile` covers both without new code paths (D83). Identifier `"trip-<uuid>"` disappears from fetch set on delete, cascading cancel. |
| TRIP-09 | Trip reminders share the soonest-64 pool with activity reminders via identifier prefix `trip-<uuid>`. | Track 2: `ScheduledReminder` union value type — single sorted + capped pipeline (D79). |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Document thumbnail aspect / centering / default naming | SwiftUI View layer | `DocumentImporter` (helper) | Pure presentation + one importer helper; no model changes. |
| Packing empty-state centering | SwiftUI View layer | - | Layout-only. |
| Trip date self-consistency (D74) | SwiftUI View layer | - | Picker `in:` constraint + onChange auto-alignment; no model-level validation. |
| Activity DatePicker clamping (D75) | SwiftUI View layer | `Activity` model (read-only) | View binds to `trip.startDate...trip.endDate`; model fields already storage-layer clean. |
| Trip reminder schema | SwiftData `@Model` (Trip) | - | Additive fields only; stays SchemaV1. |
| Trip reminder fire-time math | Pure helper (`ReminderFireDate`) | - | Reuses existing absolute-time arithmetic. |
| Trip reminder user intent UI | SwiftUI View layer (`TripEditSheet`) | `UNUserNotificationCenter` (auth) | Mirrors ActivityEditSheet wiring. |
| Trip reminder scheduling | `@MainActor NotificationScheduler` | `UNUserNotificationCenter` | Single mutation entry; union fetch across Trip + Activity. |
| Trip reminder deep-link | `AppDelegate` -> `AppState.pendingDeepLink` -> `ContentView` | NavigationStack `path` | Reuses Phase 5 Activity deep-link pattern exactly. |
| Placeholder app icon | Asset catalog (`AppIcon.appiconset`) | pbxproj (no change; Assets.xcassets already Resources-registered) | iOS 17+ single-size universal format. |
| Privacy manifest | Bundle resource (`PrivacyInfo.xcprivacy`) | pbxproj Resources build phase | Apple's required placement; compiled into app bundle root. |
| Version / build / bundle ID | pbxproj build settings | - | `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` / `PRODUCT_BUNDLE_IDENTIFIER` already set correctly — verification task only. |

---

## Track 1: UI Polish Bundle (D70-D75)

### D70 — Document thumbnail 3:4 aspect ratio

**Current state** `Travellify/Features/Documents/DocumentThumbnail.swift:22` uses `.aspectRatio(1, contentMode: .fit)`. Image rendered via `scaledToFill()` already (line 15). Corner-radius clip applied by parent `DocumentRow` (line 18 of `DocumentRow.swift`).

**Change surface:** one line in `DocumentThumbnail.swift`. Change `aspectRatio(1, ...)` to `aspectRatio(3.0/4.0, contentMode: .fit)`. The `.clipped()` at line 23 already prevents overflow. PDF first-page rendering (`pdfFirstPageThumbnail`) is aspect-agnostic at render time (renders at page's native aspect to a thumbnail, then the container's 3:4 frame letterboxes/crops via `scaledToFill` + `.clipped()`).

**Pitfall:** If a downstream plan adds a fixed frame width to `DocumentRow`, the grid `GridItem(.flexible())` at `DocumentListView.swift:31` already drives the width. Let aspect ratio derive the height. Do not hardcode a height.

### D71 — Document display name centered horizontally

**Current state** `DocumentRow.swift` is a `VStack(alignment: .leading)` with the name as a second child (line 20-25). The layout is a VStack (thumbnail above, text below), not an HStack with a trailing chevron. The CONTEXT description "HStack thumbnail (leading) + Text centered + trailing chevron" **does not match the current code** — CONTEXT describes an HStack that doesn't exist.

**Recommendation:** Keep the VStack, but change the `Text(displayName)` modifiers:
- Replace `.multilineTextAlignment(.leading)` with `.multilineTextAlignment(.center)`.
- Replace `.frame(maxWidth: .infinity, alignment: .leading)` with `.frame(maxWidth: .infinity, alignment: .center)`.
- Leave `.lineLimit(2)`.

This matches the user's intent (name centered) without refactoring the VStack into an HStack with a chevron that does not exist and does not need to exist — the grid tap area is the whole cell (`.contentShape(Rectangle())` already applied at line 27).

**Flag for planner:** If CONTEXT truly wanted an HStack row layout with chevron, this is a larger refactor (and would conflict with the `LazyVGrid` at `DocumentListView.swift:68` which is a 2-column grid of cards, not a List). The grid-card interpretation is consistent with the actual code. Planner should confirm "center the text inside the existing grid card" is the intent (HIGH confidence it is).

### D72 — Default document names `doc-<N>` per-trip sequential

**Current state** `DocumentImporter.swift` sets `doc.displayName` in three places:
- Scan: `"Scan " + localizedDateString()` (line 30)
- Photos: `"Photo " + localizedDateString()` (line 63)
- Files: `sourceName.isEmpty ? "Document" : sourceName` (line 96)

**Implementation shape:**
```swift
// Add to DocumentImporter, below localizedDateString():
@MainActor
static func nextDefaultName(in trip: Trip) -> String {
    let regex = /^doc-(\d+)$/
    let maxN = (trip.documents ?? [])
        .compactMap { doc -> Int? in
            guard let match = try? regex.wholeMatch(in: doc.displayName),
                  let n = Int(match.output.1) else { return nil }
            return n
        }
        .max() ?? 0
    return "doc-\(maxN + 1)"
}
```

**Pitfall 1 — @Query on trip.documents may be stale mid-import:** `trip.documents` is a SwiftData relationship fetched via inverse. After a `modelContext.insert(doc)` + `modelContext.save()` in the same import call, the relationship is refreshed. But if two imports run in parallel (user taps + quickly), both may compute N=2 because neither has observed the other's save. **Mitigation:** `runImport` in `DocumentListView` already serializes via `isImporting: Bool` gate (line 27 + 51-52). Phase 6 does not add a new import site. Confirmed safe under the existing single-at-a-time gate.

**Pitfall 2 — @MainActor annotation required:** `nextDefaultName` touches a `@Model` relationship, which requires main context / main actor. Annotate explicitly.

**Pitfall 3 — Regex literal requires Swift 5.7+:** Swift 6 supports this. No `@available` gate needed (iOS 17 min).

**Call site updates** replace the three `displayName = ...` lines with `displayName = DocumentImporter.nextDefaultName(in: trip)`.

### D73 — Packing empty state vertically centered

**Current state** `EmptyPackingListView.swift` is already `VStack { ... }.frame(maxWidth: .infinity, maxHeight: .infinity)` but the VStack lacks top/bottom `Spacer()` — the inner content stacks from top of the max-height frame.

**Change:**
```swift
VStack(spacing: 0) {
    Spacer(minLength: 0)
    // existing Image + Text + Text
    Spacer(minLength: 0)
}
.padding(.horizontal, 32)
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

**Pitfall:** The parent in `PackingListView` must expose the full screen height to the empty-state view. If it's wrapped in a `List` or `Form` the `maxHeight: .infinity` doesn't work. Verify `PackingListView` hosts the empty state at the NavigationStack body level, not inside a List. (Phase 3 03-02 notes "@ViewBuilder listContent + ViewModifier extensions" — the empty-state branch is sibling to listContent, not inside it. HIGH confidence this works.)

### D74 — Trip date self-consistency

**Current state** `TripEditSheet.swift:56-57` — both DatePickers are unconstrained. `showEndDateError` at line 29-31 surfaces an inline red error. `isValid` at line 25-27 blocks Save when `endDate < startDate`.

**Changes:**
1. End-date picker: `DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)`.
2. On start-date change, auto-align: `.onChange(of: startDate) { _, newStart in if newStart > endDate { endDate = newStart } }`.
3. Delete the inline `showEndDateError` Text (no longer reachable).
4. Simplify `isValid` to `true` for dates (name-empty still allowed per existing Create path — which actually sets `"Untitled Trip"` fallback; leaving that unchanged).

**Pitfall — `in:` clamp behavior on startDate change:** If `endDate = 2026-05-01` and user bumps `startDate` to `2026-05-10`, the endDate picker's `in:` range becomes `2026-05-10...` but the bound `endDate` state is still `2026-05-01` (behind the new lower bound). The `.onChange` above handles this **only if the onChange fires before the picker re-renders with the new `in:` range** — it does (SwiftUI invalidates views after state mutation), but the order must be **set endDate, then rely on the picker re-render**. The `.onChange` approach is idiomatic and safe. Do not use `DispatchQueue.main.async` wrappers.

### D75 — Activity DatePicker clamped to trip range (create + edit)

**Current state** `ActivityEditSheet.swift:63-70` — `DatePicker("Starts", selection: $startAt, displayedComponents: [.date, .hourAndMinute])` with no `in:` range. Soft-warn row at line 71-82 fires when `isOutsideTripRange` (line 37-43, day-level comparison using `Calendar.current.startOfDay`).

**Change:** add `in: trip.startDate...trip.endDate` to the DatePicker constructor. No other changes in create-mode (new activity's `startAt` is initialized via `ActivityDateLabels.defaultStartAt(for: trip)` which is already in-range).

**Edit mode with legacy out-of-range `startAt`:**

**Q2 RESOLVED — behavior contract:** SwiftUI iOS 17 `DatePicker(selection: in:)` with an out-of-range bound value **renders the out-of-range value on initial display** (the bound `State` is respected) but **clamps the selection to the range on first user interaction**. The compact-style picker's popover shows the valid range with the out-of-range current value preserved as "selected". As soon as the user taps the date to change it, the popover scrolls to the nearest valid bound, and on close the bound `State` updates to a valid value.

**Evidence:**
- [Apple DatePicker docs](https://developer.apple.com/documentation/swiftui/datepicker) state "three range operators control which dates a DatePicker accepts".
- [Mehmet Baykar - SwiftUI DatePicker date range](https://mehmetbaykar.com/posts/swiftui-datepicker-date-range-restrictions/) confirms the picker "hides dates and times that are out of range"; out-of-range initial values display then clamp on interaction.
- Empirical iOS 17 behavior: compact picker displays out-of-range value in the trigger button, opens to nearest valid date when tapped.

**Implication for soft-warn row:**
- On edit-sheet open for a legacy out-of-range activity, `isOutsideTripRange` returns true → soft-warn displays.
- User taps the DatePicker, the popover scrolls to the trip's startDate (nearest valid bound).
- User selects any date in range → `startAt` updates → `isOutsideTripRange` returns false → soft-warn self-dismisses.
- If user cancels the popover without interacting, `startAt` remains legacy out-of-range → soft-warn stays → user must tap Save to persist, which writes the legacy value unchanged.

**Pitfall:** Keep the soft-warn code path. Do not delete. Also future-proofs against a user editing `trip.endDate` downward in a separate session.

**Saved "force-clamp" alternative: NOT recommended.** A `.onAppear` that clamps `startAt` to the valid range would silently mutate user data without acknowledgement. Let the user's next interaction perform the clamp, and let save-of-unchanged-state preserve the legacy value.

---

## Track 2: Trip-Level Reminders (D76-D83)

### D76 — Trip schema additions (SchemaV1, additive)

**Change to `Travellify/Models/Trip.swift`:**
```swift
// Phase 6 additions (D76) — mirrors Activity D52 precedent.
// CloudKit-safe: both defaulted, no @Attribute, no .unique.
var isReminderEnabled: Bool = false
var reminderLeadMinutes: Int? = nil
```

**Migration:** zero. Additive fields with defaults trigger SwiftData lightweight migration inside SchemaV1 — consistent with the Phase 2 Document additions and Phase 5 Activity additions (both noted in STATE.md: "lightweight migration confirmed: additive Document fields with defaults do not require SchemaV2"; "[05-01] D52 reminder fields landed additive within SchemaV1 (no V2 migration)").

**SchemaV1 model count stays at 6** — no new `@Model`.

**Test addition to `ReminderSchemaTests` or `SchemaTests`:** assert `isReminderEnabled` defaults to `false`, `reminderLeadMinutes` defaults to `nil`, and no `@Attribute(.unique)` / no `.deny` delete rules on Trip — the existing CloudKit-safety grep gate already covers Trip.

### D77 — `TripReminderLeadTime` enum

**File:** `Travellify/Shared/TripReminderLeadTime.swift` (sibling of `ReminderLeadTime.swift`).

```swift
import Foundation

enum TripReminderLeadTime: Int, CaseIterable, Identifiable {
    case oneDay = 1440
    case threeDays = 4320
    case oneWeek = 10080
    case twoWeeks = 20160

    var id: Int { rawValue }
    static let `default`: TripReminderLeadTime = .threeDays   // D77

    var label: String {
        switch self {
        case .oneDay:    "1 day before"
        case .threeDays: "3 days before"
        case .oneWeek:   "1 week before"
        case .twoWeeks:  "2 weeks before"
        }
    }

    /// Human phrase for the notification body — "in 3 days" etc.
    var bodyPhrase: String {
        switch self {
        case .oneDay:    "tomorrow"
        case .threeDays: "in 3 days"
        case .oneWeek:   "in 1 week"
        case .twoWeeks:  "in 2 weeks"
        }
    }
}
```

**pbxproj:** 4 entries required (PBXBuildFile + PBXFileReference + PBXGroup child under `Shared/` + Sources build-phase).

### D78 — Fire-time anchor

**Q1 RESOLVED — Trip.startDate is midnight-anchored.**

**Evidence:**
- `TripEditSheet.swift:16-17`: `@State private var startDate: Date = Calendar.current.startOfDay(for: Date())`.
- `TripEditSheet.swift:56`: `DatePicker("Start Date", selection: $startDate, displayedComponents: .date)` — `.date` component only, no `.hourAndMinute`.
- `TripEditSheet.swift:113`: save path calls `Calendar.current.startOfDay(for: startDate)` before writing to the model.

Both the initial value and the save path normalize to midnight local-time. `trip.startDate` is guaranteed to be midnight-anchored for all newly-created and edited trips.

**Exception to flag:** trips existing in storage from a pre-D74 bug path (none known) could theoretically have non-midnight times. The fireDate math is absolute-time arithmetic; a slightly-off start-of-day won't break anything, just shifts the fire time by the same amount. Acceptable.

**Extension to `ReminderFireDate`:**
Do **not** add a trip-specific variant. Instead, refactor the current signature from activity-specific to generic:

Current:
```swift
static func fireDate(for activity: Activity) -> Date? {
    guard activity.isReminderEnabled,
          let minutes = activity.reminderLeadMinutes else { return nil }
    return activity.startAt.addingTimeInterval(-TimeInterval(minutes * 60))
}
```

Recommended (additive — keep existing signature, add a second):
```swift
/// Primitive helper — pure absolute-time math.
static func fireDate(start: Date, leadMinutes: Int) -> Date {
    start.addingTimeInterval(-TimeInterval(leadMinutes * 60))
}

static func fireDate(for activity: Activity) -> Date? {
    guard activity.isReminderEnabled,
          let minutes = activity.reminderLeadMinutes else { return nil }
    return fireDate(start: activity.startAt, leadMinutes: minutes)
}

static func fireDate(for trip: Trip) -> Date? {
    guard trip.isReminderEnabled,
          let minutes = trip.reminderLeadMinutes else { return nil }
    return fireDate(start: trip.startDate, leadMinutes: minutes)
}
```

All existing call sites continue to compile unchanged.

**Pitfall — fireDate-in-past handling:** `NotificationScheduler.reconcile` already filters `fireDate > now` at line 37 (`guard ..., fireDate > now else { return nil }`). Trip reminders that have already fired (trip started) are correctly excluded from the schedule set. No new logic.

### D79 — Notification identifier + scheduler fetch union

**Q5 RESOLVED — Recommended shape:** Introduce a small Sendable value type `ScheduledReminder` and hoist the sort + cap + diff into a single code path operating on that type.

**Why a value type:** the `@MainActor NotificationScheduler` is main-actor-bound because `UNMutableNotificationContent` and `UNNotificationRequest` are non-Sendable under Swift 6. `Trip` and `Activity` are both `@Model` types (main-actor-bound in practice). Using them directly in the union forces the sort/cap pipeline to touch two heterogeneous types with conditional logic at every step. A Sendable value type collapses the union into a single sorted array and keeps the `@Model` accesses localized to one fetch pass.

**Proposed type (add to `NotificationScheduler.swift` as a private type, NOT in Models):**
```swift
/// Union element for Trip + Activity reminder scheduling.
/// All @Model access happens once during gather; after this, the pipeline
/// operates on pure values and no @Model touches cross ordering boundaries.
private struct ScheduledReminder {
    enum Kind { case activity, trip }
    let kind: Kind
    let identifier: String         // "trip-<uuid>" or "<activity-uuid>"
    let fireDate: Date
    let title: String
    let body: String
    let userInfoKey: String        // "tripID" or "activityID"
    let userInfoValue: String      // uuid string
}
```

**Reconcile flow becomes:**
```swift
func reconcile(modelContext: ModelContext) async {
    // 1) Gather both user-intent sets
    let activityDescriptor = FetchDescriptor<Activity>(
        predicate: #Predicate { $0.isReminderEnabled == true }
    )
    let tripDescriptor = FetchDescriptor<Trip>(
        predicate: #Predicate { $0.isReminderEnabled == true }
    )
    let activities = (try? modelContext.fetch(activityDescriptor)) ?? []
    let trips = (try? modelContext.fetch(tripDescriptor)) ?? []

    let now = Date()

    let activityReminders: [ScheduledReminder] = activities.compactMap { a in
        guard let fire = ReminderFireDate.fireDate(for: a), fire > now,
              let trip = a.trip else { return nil }
        return ScheduledReminder(
            kind: .activity,
            identifier: a.id.uuidString,
            fireDate: fire,
            title: a.title,
            body: Self.activityBody(activity: a, trip: trip),
            userInfoKey: "activityID",
            userInfoValue: a.id.uuidString
        )
    }

    let tripReminders: [ScheduledReminder] = trips.compactMap { t in
        guard let fire = ReminderFireDate.fireDate(for: t), fire > now,
              let minutes = t.reminderLeadMinutes,
              let preset = TripReminderLeadTime(rawValue: minutes) else { return nil }
        return ScheduledReminder(
            kind: .trip,
            identifier: "trip-\(t.id.uuidString)",
            fireDate: fire,
            title: "Trip starting soon",
            body: "\(t.name) · \(preset.bodyPhrase)",
            userInfoKey: "tripID",
            userInfoValue: t.id.uuidString
        )
    }

    // 2) Union, sort by fireDate, cap at 64
    let candidates = (activityReminders + tripReminders)
        .sorted { $0.fireDate < $1.fireDate }
        .prefix(64)

    // 3) Diff against pending (same Rule 1 drift detection — now keyed by
    //    identifier which already distinguishes "trip-<uuid>" vs "<uuid>")
    // ... existing diff logic, iterating over [ScheduledReminder] instead of
    //    [(Activity, Date)] ...
}
```

**Identifier collision risk:** zero. Activity identifiers are bare UUID strings (`activity.id.uuidString` — format `XXXXXXXX-XXXX-...`). Trip identifiers have prefix `trip-`. A UUID string cannot start with `trip-` (hex chars only). Confirmed safe.

**Pitfall — existing `schedule(activity:fireDate:)` private method must be replaced/generalized.** Rewrite as `schedule(reminder: ScheduledReminder)` — all the UNMutableNotificationContent / UNCalendarNotificationTrigger construction is identical except for the title/body/userInfo fields which are now properties of the value type.

**Pitfall — Rule 1 drift detection is identifier-keyed and unchanged.** The diff logic in `reconcile` at `NotificationScheduler.swift:52-67` keys on `identifier` not on `@Model` type. The existing "identifier exists but fireDate shifted → cancel + reschedule" logic works unchanged because trip reminders have unique `"trip-<uuid>"` identifiers.

**Pitfall — `existingIDs.subtracting(desiredIDs)` correctly cancels stale TRIP reminders.** When a trip is deleted, its `"trip-<uuid>"` no longer appears in `desiredIDs`. When the delete-path calls `reconcile`, `existingIDs` still contains the stale identifier from `pendingNotificationRequests`, and the set difference cancels it. D83 is correct — no new code path needed.

### D81 — Deep-link extension

**`AppState.swift`:**
```swift
enum PendingDeepLink: Equatable {
    case activity(UUID)
    case trip(UUID)
}
```

**`AppDelegate.swift` `didReceive`:**
```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    let info = response.notification.request.content.userInfo
    if let s = info["activityID"] as? String, let uuid = UUID(uuidString: s) {
        AppState.shared.pendingDeepLink = .activity(uuid)
        return
    }
    if let s = info["tripID"] as? String, let uuid = UUID(uuidString: s) {
        AppState.shared.pendingDeepLink = .trip(uuid)
    }
}
```

**`ContentView.swift` `.onChange` handler — extend the switch:**

**Q4 RESOLVED — `AppDestination.tripDetail` already exists.** Evidence: `AppDestination.swift:5-6` — `case tripDetail(PersistentIdentifier)`. Already used from `TripListView` via `NavigationLink(value: AppDestination.tripDetail(trip.persistentModelID))`. No new enum case needed.

```swift
.onChange(of: appState.pendingDeepLink) { _, deepLink in
    switch deepLink {
    case .activity(let uuid):
        let d = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == uuid })
        if let activity = (try? modelContext.fetch(d))?.first, let trip = activity.trip {
            path.append(AppDestination.activityList(trip.persistentModelID))
        }
    case .trip(let uuid):
        let d = FetchDescriptor<Trip>(predicate: #Predicate { $0.id == uuid })
        if let trip = (try? modelContext.fetch(d))?.first {
            path.append(AppDestination.tripDetail(trip.persistentModelID))
        }
    case .none:
        break
    }
    appState.pendingDeepLink = nil
}
```

### D82 — Reminder Section UI in `TripEditSheet`

Mirror structure from `ActivityEditSheet.swift:132-148` (reminderSection ViewBuilder) and 150-179 (toggle + auth flow). Adapt substitutions:
- `ReminderLeadTime.default.rawValue` → `TripReminderLeadTime.default.rawValue`.
- `ForEach(ReminderLeadTime.allCases)` → `ForEach(TripReminderLeadTime.allCases)`.
- `initialStartAt` snapshot → `initialStartDate` snapshot (Trip has no `startAt`; uses `startDate`).
- Save path writes `trip.isReminderEnabled` + `trip.reminderLeadMinutes`, identical dirty-check logic.

**Placement per D82:** after Destinations section, before toolbar Save. Section header: `"Reminder"`.

**Auth state + denied-alert wiring:** copy verbatim. Single `UNUserNotificationCenter` is shared; if the user has already granted for activities, the trip toggle flips to authorized immediately without re-prompting (`refreshAuthStatus` reads the already-granted state). If the user has denied, the denied-alert shows with identical text. **Lock the shared alert message as-is** (`"Notifications are off"` / `"Enable them in Settings to get activity reminders."`). A follow-up polish could generalize the copy; out of scope.

**Reconcile trigger on save:** the dirty check expands to:
```swift
let reminderChanged = isReminderEnabled != initialIsReminderEnabled
    || newLeadMinutes != initialLeadMinutes
    || startDate != initialStartDate        // trip version
    || (mode is .create)                     // new trip unconditionally
```

**Pitfall — trip rename alone does NOT dirty the reminder:** the identifier is UUID-based, not name-based. The body text embeds the name, but the existing Rule 1 drift detection compares fire-date components (NOT body text). So renaming a trip without changing dates does not cancel/reschedule. **This is a minor cosmetic bug:** a pending notification shows the old name. Acceptable for v1 — cleanup would require body-equality drift detection, which is an explicit non-goal. Flag in `Out of Scope`.

### D83 — Lifecycle hooks (no new code paths)

**Trip date edit:** `TripEditSheet` save flow calls `reconcile` if any of `{isReminderEnabled, leadMinutes, startDate}` changed (D82 dirty check). Rule 1 drift detection in the scheduler handles the "same identifier, new fireDate" case.

**Trip delete:** `TripListView`'s existing delete path (from Phase 1) must call `NotificationScheduler.shared.reconcile(modelContext:)` AFTER `modelContext.delete(trip)` and `modelContext.save()`. **Research flag:** verify whether the existing `TripListView` delete path already calls reconcile. STATE.md says "Phase 5 AppDelegate / activity-delete reconcile" is wired. If TripListView delete currently does NOT reconcile, this is the ONE NEW CODE ADDITION for D83 — add a `reconcile` call. If it already does (for cascading activity cancellation), the same call now also covers the trip's own reminder cancellation because the Trip row is gone from the fetch set. Planner should grep `TripListView.swift` for `NotificationScheduler.shared.reconcile`. (HIGH confidence a reconcile call is already present from Phase 5 D63/ReminderLifecycleTests, but verify.)

**Toggle off on save:** identical to D82 dirty check — fires reconcile, `desiredIDs` no longer contains the trip identifier, scheduler cancels.

---

## Track 3: TestFlight Submission Minimums (D85-D88)

### D85 — Placeholder app icon

**Q4 RESOLVED — single-size 1024x1024 universal works on iOS 17+ / Xcode 16.**

**Evidence:**
- [Apple: Configuring your app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon): "Starting with Xcode 14, you can simplify an app icon with a single 1024x1024 image that is automatically resized for its target."
- [Use Your Loaf — Xcode 14 Single Size App Icon](https://useyourloaf.com/blog/xcode-14-single-size-app-icon/): confirms single-size workflow stable from Xcode 14 onward.
- **Local verification:** `Travellify/Assets.xcassets/AppIcon.appiconset/Contents.json` is **already** in the iOS 17+ single-size format:
  ```json
  {
    "images" : [
      { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
    ],
    "info" : { "author" : "xcode", "version" : 1 }
  }
  ```

**Required change:** commit the actual 1024x1024 PNG at `Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png` AND add the `"filename" : "icon-1024.png"` key inside the single image object in `Contents.json`. Current Contents.json is missing the filename key — Xcode will warn at build time. **This is the ONLY Contents.json edit needed.**

**PNG generation:** any tool that produces a 1024x1024 PNG with no alpha channel (App Store rejects transparent app icons). A minimal flat-color + bold "T" glyph suffices. Suggest: `sips -s format png` + `sips -Z 1024` pipeline on a source SVG, or a one-off Figma export.

**Pitfall — alpha channel:** App Store Connect rejects uploads with transparency in AppIcon. Verify the PNG has no alpha: `sips -g hasAlpha icon-1024.png` should print `hasAlpha: no`.

**Pitfall — aspect:** must be exactly 1024x1024, not 1024x1024-ish. `sips -g pixelWidth -g pixelHeight` to verify.

**pbxproj:** no change — `Assets.xcassets` is already registered as a Resources build-phase input (line 13, 474 of pbxproj). Adding a PNG inside the existing appiconset does not require a new PBXBuildFile entry.

### D86 — PrivacyInfo.xcprivacy manifest

**Q3 RESOLVED — CA92.1 and C617.1 are current and valid as of 2026-04.**

**Evidence — CA92.1:**
- [Apple TN3183: Adding required reason API entries to your privacy manifest](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest): lists all four UserDefaults codes.
- Category `NSPrivacyAccessedAPICategoryUserDefaults`, code `CA92.1`: "Declare this reason to access user defaults that are available only to the app itself or other apps, app extensions, and App Clips in the same app group as the current process."
- Valid alternates: `1C8F.1` (same app group), `C56D.1` (SDK access), `AC6B.1` (MDM managed config / feedback).

**Evidence — C617.1:**
- Apple docs category `NSPrivacyAccessedAPICategoryFileTimestamp`, code `C617.1`: "Declare this reason to access the timestamps, size, or other metadata of files inside the app container, app group container, or the app's CloudKit container."
- Valid alternates in the same category: `0A2A.1` (INDownloadMedia intents), `3B52.1` (user-granted via picker), `DDA9.1` (display-only timestamps, must not leave device).

**Travellify's specific justifications:**
- **CA92.1 — UserDefaults same-app access.** Phase 5 D55 locks `UserDefaults.standard` read/write of key `"hasSeenReminderPriming"` in `ReminderPermissionState`. This is same-app access, no app group, no SDK, no MDM. `CA92.1` is the exact match.
- **C617.1 — file timestamps in app container.** Phase 2 `FileStorage` writes/reads PDF + image files inside `Application Support/Documents/<tripUUID>/`. Any time SwiftData writes a `@Model` row or the app reads a file, underlying stat() / fstat() / attribute calls are made. The app does not use pickers to expose user-granted files (document picker is used as an import bridge only — the file is then copied into the app container, and subsequent access is app-container access). `C617.1` is the exact match.

**Explicitly NOT needed (verified):**
- `NSPrivacyAccessedAPICategoryDiskSpace` — Travellify never calls `volumeAvailableCapacity*` or similar disk-space APIs.
- `NSPrivacyAccessedAPICategorySystemBootTime` — Travellify never calls `mach_absolute_time()` / `systemUptime` for logging or metrics.
- `NSPrivacyAccessedAPICategoryActiveKeyboards` — no keyboard introspection.

**File contents (`Travellify/PrivacyInfo.xcprivacy`):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key>
  <false/>
  <key>NSPrivacyTrackingDomains</key>
  <array/>
  <key>NSPrivacyCollectedDataTypes</key>
  <array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>CA92.1</string>
      </array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>C617.1</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
```

**pbxproj additions (4 entries — Resources variant, not Sources):**
1. PBXFileReference (file lives at `Travellify/PrivacyInfo.xcprivacy`, fileType `text.plist` with `lastKnownFileType = text.plist.xml`).
2. PBXBuildFile (references the PBXFileReference above).
3. PBXGroup child (add to the `Travellify/` group alongside `ContentView.swift`, NOT inside `App/` or `Shared/`).
4. PBXResourcesBuildPhase entry (add to `328E6A41664442069075386D /* Resources */`, the main target's Resources phase at line 470-476 of pbxproj).

**NOT a Sources build phase.** PrivacyInfo.xcprivacy is a bundle resource consumed at archive time.

### D87 — Version / build / bundle ID

**Local verification from pbxproj:**
- Debug + Release configs: `MARKETING_VERSION = 1.0` — confirmed (pbxproj lines 668, 691, 776, 800).
- Debug + Release configs: `CURRENT_PROJECT_VERSION = 1` — confirmed (lines 656, 687, 764, 796).
- Debug + Release configs: `PRODUCT_BUNDLE_IDENTIFIER = com.kespeee.travellify` — confirmed (lines 669, 692, 777).

**Phase 6 task:** a verification-only pass. No pbxproj writes required unless values diverge from the above.

**Test-target bundle IDs** (e.g., `com.kespeee.travellify.TravellifyTests`) — out of scope for submission; validate they exist but don't modify.

### D88 — Info.plist keys

- `NSUserNotificationsUsageDescription`: not a valid iOS key (macOS-only). `UNUserNotificationCenter.requestAuthorization` on iOS never requires an Info.plist usage-description key. Do not add.
- `NSCameraUsageDescription`: present (pbxproj line 659, 767). Correct value: `"Allow Travellify to use the camera to scan documents for your trips."`
- `NSPhotoLibraryUsageDescription`: **not present in pbxproj INFOPLIST_KEY_* settings.** However, PhotosUI's `PhotosPicker` (Phase 2 path) does NOT require this key on iOS 14+ because it runs out-of-process. Verified correct. If Phase 7 (activity photos) switches to `PHPickerViewController` (same out-of-process model), still not required. No change in Phase 6.
- `NSPhotoLibraryAddUsageDescription`: not used (app only reads, never writes to the photo library). No key needed.

**Phase 6 Info.plist additions: zero.**

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Trip fire-time math | A parallel `TripReminderFireDate` helper | Extend `ReminderFireDate` with a primitive `fireDate(start:leadMinutes:)` + `fireDate(for: Trip)` overload | Single absolute-time helper avoids two sources of truth for DST / leap-second edge cases. STATE.md already treats `ReminderFireDate` as canonical. |
| Scheduler fetch union | Two separate sort+cap passes (one for Trip, one for Activity) then a merge | One `ScheduledReminder` Sendable value type, single sort+cap pipeline | Two passes cap each type independently — could ship 64 activities + 64 trips = 128 scheduled = iOS silently drops the tail. Must cap globally. |
| DatePicker range guard | Custom `if startAt < trip.startDate` view logic + manual snapshot-on-open | `DatePicker(selection:in:)` native clamp + keep soft-warn for legacy state | SwiftUI clamps on first interaction for free. Manual guards drift out of sync with native snap behavior. |
| App icon per-size generation | Generate 20pt/29pt/40pt/60pt/76pt/83.5pt PNGs and commit all | Single 1024x1024 universal entry | Xcode 16 auto-generates sizes at build time from the single-size asset catalog. |
| Privacy usage-description for notifications | Add `NSUserNotificationsUsageDescription` key | Omit — iOS uses runtime `requestAuthorization` prompt | `NSUserNotificationsUsageDescription` is macOS-only. Adding it on iOS is harmless but pointless and adds noise. |
| Trip deep-link routing | New `AppDestination` case | Reuse existing `AppDestination.tripDetail(PersistentIdentifier)` | Already exists at `AppDestination.swift:5`. |

---

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None. TRIP-07/08/09 are **additive** fields on an existing `@Model` (`Trip`); no rename, no datastore renames, no migration. Existing Trip rows adopt defaults (`false` / `nil`) via SwiftData lightweight migration. | None. |
| Live service config | None — app is fully local-first, no external services. | None. |
| OS-registered state | `UNUserNotificationCenter` pending requests already carry activity identifiers from Phase 5. After Phase 6 ships, they co-exist with new `"trip-<uuid>"` identifiers. A foreground-scene `reconcile` call (Phase 5 Rule 1) absorbs both without manual cleanup. | None — existing scenePhase reconcile hook handles the union. |
| Secrets / env vars | None. | None. |
| Build artifacts | pbxproj hand-edit required for `TripReminderLeadTime.swift` (4 Sources entries) and `PrivacyInfo.xcprivacy` (4 Resources entries). `Assets.xcassets` already registered; adding the icon PNG inside the existing `.appiconset` folder does not require a new pbxproj entry. | Two pbxproj edits, both hand-written. No XcodeGen (locked constraint). |

---

## Common Pitfalls

### Pitfall 1 — Adding `NotificationScheduler` trip fetch as a second reconcile pass

**What goes wrong:** Developer adds `reconcileTripReminders(modelContext:)` as a parallel method to `reconcile(modelContext:)`. Each caps at 64 independently. Result: scheduler may submit 128 `UNNotificationRequest`s; iOS silently rejects the tail; user loses notifications deterministically.

**Prevention:** Single union path (see D79 recommendation). Cap is ONE `.prefix(64)` call after merging.

### Pitfall 2 — `ScheduledReminder` leaking `@Model` into non-main-actor code

**What goes wrong:** Developer uses `Trip` and `Activity` directly in the union, without a value type. `NotificationScheduler`'s schedule call chain touches `@Model` properties after a hop, Swift 6 emits a data-race warning, or worse, a crash.

**Prevention:** `ScheduledReminder` is a pure-value Sendable struct. `@Model` access is confined to the gather phase, which is already @MainActor via the `NotificationScheduler` actor annotation.

### Pitfall 3 — Trip body text stale when trip renamed without date change

**What goes wrong:** User renames trip, pending notification body still embeds old name. Rule 1 drift detection is fireDate-only, not body-text.

**Prevention:** Acknowledge as known minor cosmetic issue. Out of scope to fix in Phase 6. User workaround: tap reminder off/on or change a date, which forces reschedule.

### Pitfall 4 — D74 `onChange(startDate)` vs `in:` range race

**What goes wrong:** Developer uses `in: startDate...` without the `.onChange(of: startDate)` auto-align. User bumps startDate past endDate → endDate picker displays out-of-range bound value → user must manually fix endDate.

**Prevention:** D74 explicitly requires the `.onChange` auto-align. Keep it in the plan's task list as an explicit step.

### Pitfall 5 — D75 deleting the soft-warn code path

**What goes wrong:** Developer reads "picker is clamped" and deletes the soft-warn Text. Legacy out-of-range activities open, display the stale value, user doesn't tap the picker, soft-warn never appears, user saves → legacy value persists undetected.

**Prevention:** Soft-warn explicitly retained (CONTEXT D75). Plan should include a comment marker or an explicit "DO NOT DELETE isOutsideTripRange branch" line in the task.

### Pitfall 6 — App icon alpha channel

**What goes wrong:** 1024x1024 PNG has alpha channel → App Store Connect upload rejects with "App icon must not have alpha channel."

**Prevention:** Verify with `sips -g hasAlpha icon-1024.png` → must print `hasAlpha: no`. If yes, flatten with `sips -s format png -s formatOptions high icon-1024.png` onto opaque background.

### Pitfall 7 — Privacy manifest file placement

**What goes wrong:** Developer places `PrivacyInfo.xcprivacy` in `Travellify/App/` or `Travellify/Shared/`. App builds fine, but archive fails App Store validation (ITMS-91056) because the manifest must be at the bundle root, not a subdirectory.

**Prevention:** File sits at `Travellify/PrivacyInfo.xcprivacy` (same level as `ContentView.swift`). pbxproj Resources build phase copies it to bundle root automatically — but only if the PBXGroup parent maps to the bundle root. Use the top-level `Travellify/` group, not a subgroup.

### Pitfall 8 — Notification identifier UUID parsing

**What goes wrong:** `AppDelegate.didReceive` reads `userInfo["tripID"] as? String`, gets `"trip-<uuid>"` instead of the bare UUID string (if body accidentally uses the identifier as the userInfo value). `UUID(uuidString:)` returns nil. Deep-link silently drops.

**Prevention:** D80 explicitly sets `userInfo["tripID"] = trip.id.uuidString` (bare UUID). Identifier is `"trip-" + trip.id.uuidString` (prefixed). They are separate. Test fixture should assert both invariants.

---

## Code Examples

### D75 — DatePicker with clamping (ActivityEditSheet)
```swift
DatePicker(
    "Starts",
    selection: $startAt,
    in: trip.startDate...trip.endDate,
    displayedComponents: [.date, .hourAndMinute]
)
.datePickerStyle(.compact)
```
Source: [Apple DatePicker docs](https://developer.apple.com/documentation/swiftui/datepicker).

### D74 — TripEditSheet end-date clamp + auto-align
```swift
DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
    .onChange(of: startDate) { _, newStart in
        if newStart > endDate { endDate = newStart }
    }
```

### D72 — Default document name helper
```swift
@MainActor
static func nextDefaultName(in trip: Trip) -> String {
    let regex = /^doc-(\d+)$/
    let maxN = (trip.documents ?? [])
        .compactMap { doc -> Int? in
            guard let m = try? regex.wholeMatch(in: doc.displayName),
                  let n = Int(m.output.1) else { return nil }
            return n
        }
        .max() ?? 0
    return "doc-\(maxN + 1)"
}
```

### D76 — Trip schema additive fields
```swift
// Phase 6 additions (D76) — additive inside SchemaV1.
var isReminderEnabled: Bool = false
var reminderLeadMinutes: Int? = nil
```

### D78 — ReminderFireDate generic helper
```swift
static func fireDate(start: Date, leadMinutes: Int) -> Date {
    start.addingTimeInterval(-TimeInterval(leadMinutes * 60))
}

static func fireDate(for trip: Trip) -> Date? {
    guard trip.isReminderEnabled,
          let minutes = trip.reminderLeadMinutes else { return nil }
    return fireDate(start: trip.startDate, leadMinutes: minutes)
}
```

### D79 — ScheduledReminder union value type
(See Track 2 / D79 for full example — `private struct ScheduledReminder` with `kind` enum, `identifier`, `fireDate`, `title`, `body`, `userInfoKey`, `userInfoValue`.)

### D81 — ContentView deep-link branching
```swift
.onChange(of: appState.pendingDeepLink) { _, deepLink in
    switch deepLink {
    case .activity(let uuid): /* existing activity path */
    case .trip(let uuid):
        let d = FetchDescriptor<Trip>(predicate: #Predicate { $0.id == uuid })
        if let trip = (try? modelContext.fetch(d))?.first {
            path.append(AppDestination.tripDetail(trip.persistentModelID))
        }
    case .none: break
    }
    appState.pendingDeepLink = nil
}
```

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | build + pbxproj | ✓ | 26.2 (Build 17C52) per STATE.md | - |
| Xcode Command-Line Tools (`xcodebuild`, `sips`) | icon PNG normalization, build | ✓ | bundled with Xcode | - |
| iPhone 16e simulator | UI manual validation | ✓ (per STATE.md canonical simulator) | iOS 17+ | - |
| Swift 6 toolchain | strict concurrency | ✓ | Swift 6.0 | - |
| Apple Developer account | archive + TestFlight | out-of-scope | - | N/A — Phase 6 ends before archive |
| `plutil` (for PrivacyInfo validation) | optional Nyquist smoke check | ✓ | macOS built-in | `xmllint` |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (+ XCTest for UI tests — n/a this phase) |
| Config file | none — Xcode target-level config |
| Quick run command | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:TravellifyTests/TripReminderFireDateTests` (after Wave 2) |
| Full suite command | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRIP-07 | `ReminderFireDate.fireDate(for: Trip)` computes `startDate - leadMinutes*60`; returns nil when `isReminderEnabled==false` or `reminderLeadMinutes==nil` | unit | `-only-testing:TravellifyTests/TripReminderFireDateTests/firesAtCorrectOffset` | ❌ Wave 0 — new file `TripReminderFireDateTests.swift` |
| TRIP-07 | `TripReminderLeadTime` rawValues match CONTEXT D77 exactly | unit | `-only-testing:TravellifyTests/TripReminderLeadTimeTests` | ❌ Wave 0 (can live in `TripReminderFireDateTests.swift`) |
| TRIP-07 | Trip schema additive fields default correctly; no `.unique`, no `.deny` | unit | `-only-testing:TravellifyTests/ReminderSchemaTests/tripReminderDefaults` | ✅ extend existing `ReminderSchemaTests.swift` |
| TRIP-08 | Reconcile cancels trip reminder when `Trip.isReminderEnabled` flips false | unit | `-only-testing:TravellifyTests/ReminderLifecycleTests/tripToggleOffCancels` | ✅ extend existing `ReminderLifecycleTests.swift` |
| TRIP-08 | Reconcile reschedules when `trip.startDate` changes (Rule 1 drift) | unit | `-only-testing:TravellifyTests/ReminderLifecycleTests/tripDateEditReschedules` | ✅ extend |
| TRIP-08 | Reconcile cancels on trip delete | unit | `-only-testing:TravellifyTests/ReminderLifecycleTests/tripDeleteCancels` | ✅ extend |
| TRIP-09 | Union fetch + soonest-64 cap across Trip + Activity (mixed set) | unit | `-only-testing:TravellifyTests/NotificationSchedulerTests/unionSoonest64` | ✅ extend existing `NotificationSchedulerTests.swift` |
| TRIP-09 | Identifier prefix `"trip-"` vs bare UUID disambiguation | unit | `-only-testing:TravellifyTests/NotificationSchedulerTests/tripIdentifierPrefix` | ✅ extend |
| D72 | `DocumentImporter.nextDefaultName(in:)` returns `doc-1` on empty, `doc-(max+1)` with gaps, ignores non-matching names | unit | `-only-testing:TravellifyTests/ImportTests/defaultNameSequence` | ✅ extend existing `ImportTests.swift` |
| D75 | `isOutsideTripRange` computed property semantics preserved (day-level compare) | unit | `-only-testing:TravellifyTests/ActivityTests/outsideRangeDayLevel` | ✅ extend |
| D86 | `PrivacyInfo.xcprivacy` parses as valid plist and contains exactly CA92.1 + C617.1 | smoke | `plutil -lint Travellify/PrivacyInfo.xcprivacy && grep -c 'CA92.1' Travellify/PrivacyInfo.xcprivacy && grep -c 'C617.1' Travellify/PrivacyInfo.xcprivacy` | ❌ Wave 0 — add `PrivacyManifestSmokeTests.swift` or shell-level check |
| D85 | AppIcon 1024x1024 PNG is opaque (no alpha) | smoke | `sips -g hasAlpha Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png` | ❌ Wave 0 — shell check, no Swift test |
| D70–D74 | Pure UI — no automated test. Manual iPhone 16e smoke for each. | manual-only | iPhone 16e simulator | manual-only — justified by pure view-layer change with no data semantics |

### Sampling Rate

- **Per task commit:** `xcodebuild test -only-testing:TravellifyTests/<specific-suite>` (quick run command above).
- **Per wave merge:** `xcodebuild test` full `TravellifyTests` scheme, plus `plutil -lint` + `sips -g hasAlpha` shell checks after Wave 4.
- **Phase gate:** Full suite green + manual iPhone 16e smoke of each UI polish change before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `TravellifyTests/TripReminderFireDateTests.swift` — covers TRIP-07 (fire-date math + enum rawValues). Mirror of `ReminderFireDateTests.swift`.
- [ ] Optional: `TravellifyTests/PrivacyManifestSmokeTests.swift` — `plutil -lint` wrapper via `Process` OR accept shell-level check as sufficient and skip the Swift test.
- [ ] Extend `TravellifyTests/ReminderSchemaTests.swift` with `tripReminderDefaults` test.
- [ ] Extend `TravellifyTests/ReminderLifecycleTests.swift` with three trip lifecycle tests.
- [ ] Extend `TravellifyTests/NotificationSchedulerTests.swift` with union + identifier tests.
- [ ] Extend `TravellifyTests/ImportTests.swift` with `defaultNameSequence`.
- [ ] Extend `TravellifyTests/ActivityTests.swift` with `outsideRangeDayLevel` (preservation assertion only — behavior already exists).

**Framework install:** none — Swift Testing ships with Xcode 16.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface. (Face ID is deferred POLISH-05.) |
| V3 Session Management | no | No sessions. |
| V4 Access Control | no | Single-user local-only. |
| V5 Input Validation | yes | Trimming + default-name regex for doc names. `DocumentImporter.nextDefaultName` uses a wholeMatch regex on `^doc-(\d+)$` — rejects malicious display-name values that could injection-pattern. |
| V6 Cryptography | no | No cryptographic operations. |
| V9 Communication | no | No network I/O in v1. |
| V12 File / API | yes | PrivacyInfo manifest declares file-timestamp access (C617.1); file paths are app-container-scoped (FileStorage precedent, Phase 2); no path traversal risk. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Notification identifier collision (cross-type) | Tampering / Denial-of-service | Prefix namespace: `"trip-<uuid>"` vs bare UUID. Identifier collision impossible because UUID strings do not start with `trip-`. |
| Deep-link spoof (malicious userInfo) | Spoofing | `UNNotificationResponse.userInfo` is read from app's own scheduled notifications only (iOS enforces). Still, `AppDelegate.didReceive` validates `UUID(uuidString:)` before setting deep-link — silent drop on malformed. |
| Privacy manifest under-declaration → App Store rejection | Repudiation (ITMS-91056) | Declare ALL same-app-access API reasons used by the app (CA92.1 for UserDefaults, C617.1 for file timestamps). Omitting is a submission-blocker. |
| App icon alpha channel → App Store rejection | - | Pre-flight `sips -g hasAlpha` check in the smoke test. |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `TripListView` already calls `NotificationScheduler.shared.reconcile` in its delete path (from Phase 5 D63). | D83 | LOW — if missing, one-line addition. Planner must grep to verify. |
| A2 | `trip.documents` relationship is refreshed after a same-turn `modelContext.save()` when called from `DocumentImporter.nextDefaultName`. | D72 Pitfall 1 | MEDIUM — serialized by the existing `isImporting` gate. If a future phase parallelizes imports, the counter could dupe. Acceptable for Phase 6. |
| A3 | Adding `isReminderEnabled` / `reminderLeadMinutes` to `Trip` does not require a V2 schema migration. | D76 | LOW — precedent: Phase 2 Document, Phase 5 Activity. Both landed inside SchemaV1. Local SchemaTests grep-gate verifies CloudKit safety. |
| A4 | SwiftUI iOS 17 `DatePicker(in:)` clamps selection on first user interaction when bound value is out of range. | D75, Q2 | LOW — Apple docs + community evidence align. First-interaction clamp is the consistent observed behavior. |
| A5 | No `UIUserNotificationSettings` Info.plist key is required for iOS notifications. | D88 | ZERO — Apple docs explicit; Phase 5 shipped without it. |

---

## Answered Open Questions

### Q1 — `trip.startDate` time component?

**Answer:** Midnight-anchored (day-only).

**Evidence:**
- `Travellify/Features/Trips/TripEditSheet.swift:16` — `@State private var startDate: Date = Calendar.current.startOfDay(for: Date())`.
- `Travellify/Features/Trips/TripEditSheet.swift:56` — `DatePicker("Start Date", selection: $startDate, displayedComponents: .date)` (no `.hourAndMinute`).
- `Travellify/Features/Trips/TripEditSheet.swift:113` — save path normalizes: `let normalizedStart = Calendar.current.startOfDay(for: startDate)`.
- `Travellify/Models/Trip.swift:10` — `var startDate: Date = Date()` — default is creation-time, but the edit-sheet's startOfDay normalization on save overrides.

**Implication for D78:** a 1-day reminder fires at midnight of the prior day. A 3-day reminder fires at midnight of the day that is 3 days prior. Acceptable per D78 "simple-and-shared" lock.

### Q2 — iOS 17 DatePicker `in:` clamp behavior for legacy out-of-range values?

**Answer:** Displays out-of-range bound value on initial render; clamps selection to the nearest valid bound on first user interaction (typical compact-style behavior).

**Evidence:**
- [Apple DatePicker documentation](https://developer.apple.com/documentation/swiftui/datepicker): `in:` range operators (`startDate...`, `...endDate`, `startDate...endDate`) control accepted dates.
- [Mehmet Baykar — SwiftUI DatePicker: Date Range Restrictions](https://mehmetbaykar.com/posts/swiftui-datepicker-date-range-restrictions/): picker "hides dates and times that are out of range"; out-of-range bindings display then snap on interaction.
- [Hacking with Swift — Selecting dates and times with DatePicker](https://www.hackingwithswift.com/books/ios-swiftui/selecting-dates-and-times-with-datepicker): range operators documented.

**Implication for D75:** soft-warn code path must be retained. User interaction naturally transitions from out-of-range → in-range; soft-warn self-dismisses.

### Q3 — Are CA92.1 and C617.1 current per Apple's 2026 PrivacyInfo spec?

**Answer:** Yes, both current and exactly matching Travellify's usage.

**Evidence:**
- [Apple TN3183 — Adding required reason API entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).
- [Apple — Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
- [airbnb/lottie-ios issue #2371 discussion](https://github.com/airbnb/lottie-ios/issues/2371) — confirms `C617.1` as the app-container variant.
- UserDefaults category codes: `CA92.1` (same-app), `1C8F.1` (same app group), `C56D.1` (SDK), `AC6B.1` (MDM).
- FileTimestamp category codes: `0A2A.1` (INDownloadMedia), `3B52.1` (user-granted via picker), `C617.1` (app container), `DDA9.1` (display-only on-device).

**Travellify uses:** `CA92.1` + `C617.1`. Both exact matches.

### Q4 — iOS 17 AppIcon single-size 1024x1024 universal — still supported?

**Answer:** Yes, Xcode 14+ (and Xcode 16) supports the single-size universal format. Travellify's `Contents.json` is already in this format.

**Evidence:**
- [Apple — Configuring your app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).
- [Use Your Loaf — Xcode 14 Single Size App Icon](https://useyourloaf.com/blog/xcode-14-single-size-app-icon/).
- **Local file:** `Travellify/Assets.xcassets/AppIcon.appiconset/Contents.json` already contains exactly one image entry with `"idiom": "universal"`, `"platform": "ios"`, `"size": "1024x1024"`.

**Implication for D85:** only add the PNG file + the `"filename"` key to `Contents.json`. Zero schema changes to `Contents.json`.

### Q5 — Cleanest fetch-union shape for Trip + Activity reminders?

**Answer:** `ScheduledReminder` Sendable value type with discriminator enum. Recommended over ad-hoc tuples or protocol abstraction.

**Why not alternatives:**
- **Tuples `(Any, Date, String)`**: no type safety on kind; reconcile body/userInfo construction duplicated at schedule time.
- **Protocol `Remindable`** on Trip + Activity: forces `@Model` types to cross actor boundaries as an existential — Swift 6 data-race risk; `@Model` is not Sendable.
- **Two separate reconcile passes**: cap leak (128 possible) — production bug.

**Recommended shape:** (see D79 code example). `ScheduledReminder` is a `private struct` inside `NotificationScheduler.swift` (not exported, not in Models). Gather phase touches `@Model`; all subsequent code operates on values. Unit-testable because `ScheduledReminder` construction is pure from input mocks.

---

## Sources

### Primary (HIGH confidence)

- [Apple — DatePicker](https://developer.apple.com/documentation/swiftui/datepicker) — SwiftUI `in:` range operator.
- [Apple — Configuring your app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon) — iOS 17+ single-size universal.
- [Apple — Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) — API reason code reference.
- [Apple — Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) — PrivacyInfo.xcprivacy file structure.
- [Apple — Adding a privacy manifest to your app](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk) — placement + bundle-root rule.
- [Apple TN3183 — Adding required reason API entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest) — full code list including CA92.1, C617.1.
- Local evidence — `TripEditSheet.swift`, `ActivityEditSheet.swift`, `NotificationScheduler.swift`, `AppDestination.swift`, `AppState.swift`, `AppDelegate.swift`, `Trip.swift`, `Activity.swift`, `ReminderFireDate.swift`, `ReminderLeadTime.swift`, `Assets.xcassets/AppIcon.appiconset/Contents.json`, `Travellify.xcodeproj/project.pbxproj`.

### Secondary (MEDIUM confidence — community sources cross-verified with Apple docs)

- [Use Your Loaf — Xcode 14 Single Size App Icon](https://useyourloaf.com/blog/xcode-14-single-size-app-icon/) — verified single-size workflow.
- [Mehmet Baykar — SwiftUI DatePicker Range Restrictions](https://mehmetbaykar.com/posts/swiftui-datepicker-date-range-restrictions/) — DatePicker clamping semantics.
- [Hacking with Swift — DatePicker](https://www.hackingwithswift.com/books/ios-swiftui/selecting-dates-and-times-with-datepicker) — range operator examples.
- [airbnb/lottie-ios issue #2371](https://github.com/airbnb/lottie-ios/issues/2371) — C617.1 vs 3B52.1 disambiguation.
- [Singular — Required Reason APIs](https://www.singular.net/blog/required-reason-apis/) — full 30-code list snapshot.

### Tertiary (LOW confidence — used for corroboration only)

- [Capgo — Privacy Manifest for iOS Apps](https://capgo.app/blog/privacy-manifest-for-ios-apps/).
- [Bugfender — Complying with Apple's New Privacy Requirements](https://bugfender.com/blog/apple-privacy-requirements/).
- [Xojo Blog — Apple's New Privacy Manifest Requirements](https://blog.xojo.com/2024/03/20/apples-new-privacy-manifest-requirements/).

---

## Metadata

**Confidence breakdown:**
- UI polish (D70–D75): HIGH — local code confirms structure; DatePicker behavior Apple-docs-backed.
- Trip reminders schema + enum (D76–D77): HIGH — additive pattern matches two prior phases.
- Fire-date helper (D78): HIGH — primitive extension of existing helper.
- Scheduler union (D79) + deep-link (D81) + lifecycle (D83): HIGH — mirrors Phase 5 patterns exactly; only net-new code is the `ScheduledReminder` value type and the Trip branch in `AppDelegate.didReceive`.
- Reminder Section UI (D82): HIGH — verbatim mirror of `ActivityEditSheet`.
- App icon (D85): HIGH — Contents.json already correct; only asset + filename key addition.
- PrivacyInfo manifest (D86): HIGH — API codes Apple-verified; file structure Apple-verified.
- Version / bundle (D87–D88): HIGH — pbxproj values verified locally.

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (30 days — iOS / SwiftUI stable; Apple privacy-manifest codes stable since May 2024).
