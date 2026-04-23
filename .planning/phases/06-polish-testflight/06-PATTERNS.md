# Phase 6: Polish + TestFlight Prep — Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 19 (14 source, 5 test)
**Analogs found:** 18 / 19 (one new file — PrivacyInfo.xcprivacy — has no Swift analog; Apple-spec plist)

## File Classification

| File | New/Modified | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| `Travellify/Models/SchemaV1.swift` | modified | schema-manifest | config | (no change — additive on Trip) | n/a |
| `Travellify/Models/Trip.swift` | modified | model (@Model) | storage/CRUD | `Travellify/Models/Activity.swift` (D52 reminder fields precedent) | exact |
| `Travellify/Shared/TripReminderLeadTime.swift` | NEW | enum / presets | pure-value | `Travellify/Shared/ReminderLeadTime.swift` | exact |
| `Travellify/Shared/ReminderFireDate.swift` | modified | pure helper | pure-value | (self — extend existing; add primitive + Trip overload) | exact |
| `Travellify/Shared/NotificationScheduler.swift` | modified | @MainActor service | event-driven / reconcile | (self — extend reconcile with union) | exact |
| `Travellify/App/AppState.swift` | modified | observable singleton | state | (self — extend `PendingDeepLink` enum) | exact |
| `Travellify/App/AppDelegate.swift` | modified | UIKit bridge / notification delegate | event-driven | (self — extend `didReceive` branch) | exact |
| `Travellify/App/AppDestination.swift` | UNCHANGED | routing enum | state | (already has `.tripDetail`) | n/a — no change |
| `Travellify/ContentView.swift` | modified | root view / router | request-response | (self — extend `.onChange` switch) | exact |
| `Travellify/Features/Trips/TripEditSheet.swift` | modified | SwiftUI form sheet | CRUD + request-response | `Travellify/Features/Activities/ActivityEditSheet.swift` | exact |
| `Travellify/Features/Documents/DocumentListView.swift` | modified | SwiftUI grid/list | read | (self — layout-only tweaks; keep LazyVGrid) | exact |
| `Travellify/Features/Documents/DocumentRow.swift` | modified | grid card view | presentation | (self — VStack text-align tweak only) | exact |
| `Travellify/Features/Documents/DocumentThumbnail.swift` | modified | image view | presentation | (self — one-line aspectRatio) | exact |
| `Travellify/Features/Documents/Import/DocumentImporter.swift` | modified | utility (importer) | file-I/O + CRUD | (self — add helper + replace 3 naming sites) | exact |
| `Travellify/Features/Packing/EmptyPackingListView.swift` | modified | empty state view | presentation | (self — wrap in Spacer pair) | exact |
| `Travellify/Features/Activities/ActivityEditSheet.swift` | modified | SwiftUI form sheet | CRUD | (self — add `in:` range to DatePicker) | exact |
| `Travellify/Assets.xcassets/AppIcon.appiconset/Contents.json` | modified | asset manifest | config | (self — add `filename` key) | exact |
| `Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png` | NEW | asset (PNG) | binary | (no analog — generated placeholder) | no-analog |
| `Travellify/PrivacyInfo.xcprivacy` | NEW | Apple privacy manifest (plist) | config | (no analog — Apple-spec, new for v1) | no-analog |
| `TravellifyTests/TripReminderFireDateTests.swift` | NEW | unit test (Swift Testing) | pure-value | `TravellifyTests/ReminderFireDateTests.swift` | exact |
| `TravellifyTests/ReminderSchemaTests.swift` | extended | unit test (schema grep) | config | (self) | exact |
| `TravellifyTests/ReminderLifecycleTests.swift` | extended | integration test | event-driven | (self — add trip variants) | exact |
| `TravellifyTests/NotificationSchedulerTests.swift` | extended | integration test | event-driven | (self — add union + prefix tests) | exact |
| `TravellifyTests/ImportTests.swift` | extended | unit test | pure-value | (self — add `nextDefaultName` tests) | exact |
| `TravellifyTests/ActivityTests.swift` | extended | unit test | pure-value | (self — preserve day-level compare) | exact |

---

## Pattern Assignments

### `Travellify/Models/Trip.swift` (model, additive)

**Analog:** `Travellify/Models/Activity.swift` Phase 5 D52 precedent — identical shape.

**Additive-field pattern** (mirrors D52 on Activity, lightweight migration, CloudKit-safe):
```swift
// Phase 6 (D76) — additive inside SchemaV1; defaults CloudKit-safe.
var isReminderEnabled: Bool = false
var reminderLeadMinutes: Int? = nil
```

Placement: after `var createdAt: Date = Date()` (Trip.swift:12), before the `@Relationship` block (Trip.swift:15). Do NOT add `@Attribute(.unique)` / `@Attribute(.externalStorage)` — forbidden by CLAUDE.md and grep-gated by `ReminderSchemaTests`.

**No SchemaV1 edit.** `TravellifySchemaV1.models.count == 6` invariant preserved (SchemaV1.swift:6-14). No `V2` enum. `TravellifyMigrationPlan.stages` stays empty (SchemaV1.swift:20).

---

### `Travellify/Shared/TripReminderLeadTime.swift` (NEW — enum)

**Analog:** `Travellify/Shared/ReminderLeadTime.swift` (complete file, 20 lines).

**Copy-shape verbatim** — same `Int, CaseIterable, Identifiable` conformance, `id: Int { rawValue }`, `static let default`, `var label`. Substitute cases + values per D77. Add `bodyPhrase` per D80 (needed for notification body `"\(trip.name) · \(preset.bodyPhrase)"`).

Full shape (from RESEARCH.md Track 2 D77, matches ReminderLeadTime.swift:3-20 structure):
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

**pbxproj:** 4 entries required under `Shared/` group (sibling of ReminderLeadTime.swift — PBXBuildFile + PBXFileReference + PBXGroup child + Sources build-phase).

---

### `Travellify/Shared/ReminderFireDate.swift` (modified — extend)

**Analog:** self (existing file lines 6-12).

**Current shape** (ReminderFireDate.swift:6-12):
```swift
enum ReminderFireDate {
    static func fireDate(for activity: Activity) -> Date? {
        guard activity.isReminderEnabled,
              let minutes = activity.reminderLeadMinutes else { return nil }
        return activity.startAt.addingTimeInterval(-TimeInterval(minutes * 60))
    }
}
```

**Pattern to apply** — add a primitive + Trip overload, refactor Activity overload to call primitive. **DO NOT create parallel `TripReminderFireDate.swift`** (RESEARCH §Don't Hand-Roll, row 1).

```swift
static func fireDate(start: Date, leadMinutes: Int) -> Date {
    start.addingTimeInterval(-TimeInterval(minutes * 60))
}
static func fireDate(for activity: Activity) -> Date? { /* existing guards → return fireDate(start:leadMinutes:) */ }
static func fireDate(for trip: Trip) -> Date? {
    guard trip.isReminderEnabled, let minutes = trip.reminderLeadMinutes else { return nil }
    return fireDate(start: trip.startDate, leadMinutes: minutes)
}
```

All existing call sites (NotificationScheduler.swift:35, ReminderFireDateTests) continue to compile.

---

### `Travellify/Shared/NotificationScheduler.swift` (modified — union fetch)

**Analog:** self (existing `reconcile` at lines 25-77 + `schedule(activity:fireDate:)` at lines 109-140).

**Imports pattern** (NotificationScheduler.swift:1-3) — unchanged:
```swift
import Foundation
import SwiftData
import UserNotifications
```

**@MainActor class shell** (lines 13-22) — unchanged. `static let shared`, `NotificationCenterProtocol` injection, constructor unchanged.

**Union pattern to apply** — introduce private `ScheduledReminder` Sendable value type (RESEARCH §D79, lines 318-333). Replace the `[(Activity, Date)]` pipeline with `[ScheduledReminder]`:

1. Fetch both — mirror existing descriptor shape (line 27-30):
   ```swift
   let activityDescriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.isReminderEnabled == true })
   let tripDescriptor     = FetchDescriptor<Trip>(predicate: #Predicate { $0.isReminderEnabled == true })
   ```
2. Map each to `ScheduledReminder` — activity identifier is bare `a.id.uuidString`; trip identifier is `"trip-\(t.id.uuidString)"` (D79).
3. `(activityReminders + tripReminders).sorted { $0.fireDate < $1.fireDate }.prefix(64)` — **single global cap** (RESEARCH Pitfall 1).
4. Diff loop (lines 49-67) keys on `identifier` which ALREADY distinguishes trip vs activity — **no shape change needed**, just iterate over `[ScheduledReminder]` not `[(Activity, Date)]`.

**Rename `schedule(activity:fireDate:)` → `schedule(reminder: ScheduledReminder)`.** Rewrite body to read from `reminder.title`, `reminder.body`, `reminder.userInfoKey`, `reminder.userInfoValue`, `reminder.identifier`. Preserve `components.timeZone = .current` invariant (line 124 — CRITICAL comment).

**Trip body** (D80): `content.title = "Trip starting soon"`, `content.body = "\(trip.name) · \(preset.bodyPhrase)"`, `content.userInfo = ["tripID": trip.id.uuidString]` (bare UUID — NOT the prefixed identifier, see Pitfall 8).

**Activity `body` static helper** (lines 142-148) — keep for backward compatibility, or inline into the `.activity` mapper branch.

---

### `Travellify/App/AppState.swift` (modified — extend enum)

**Analog:** self (existing enum at lines 17-19).

**Current** (AppState.swift:17-19):
```swift
enum PendingDeepLink: Equatable {
    case activity(UUID)
}
```

**Apply D81:**
```swift
enum PendingDeepLink: Equatable {
    case activity(UUID)
    case trip(UUID)
}
```

`@Observable @MainActor final class` shell (lines 9-15) and `static let shared = AppState()` + private init — unchanged.

---

### `Travellify/App/AppDelegate.swift` (modified — branch)

**Analog:** self (existing `didReceive` at lines 30-38).

**Current** (AppDelegate.swift:30-38):
```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse) async {
    let info = response.notification.request.content.userInfo
    guard let uuidString = info["activityID"] as? String,
          let uuid = UUID(uuidString: uuidString) else { return }
    AppState.shared.pendingDeepLink = .activity(uuid)
}
```

**Apply D81** — replace the single `guard` with two branches, activity first (preserves order), trip second:
```swift
let info = response.notification.request.content.userInfo
if let s = info["activityID"] as? String, let uuid = UUID(uuidString: s) {
    AppState.shared.pendingDeepLink = .activity(uuid); return
}
if let s = info["tripID"] as? String, let uuid = UUID(uuidString: s) {
    AppState.shared.pendingDeepLink = .trip(uuid)
}
```

**Keep `@preconcurrency UNUserNotificationCenterDelegate`** (line 22) and async delegate form (the comment at lines 18-21 locks this — DO NOT migrate to completion-handler variants).

---

### `Travellify/ContentView.swift` (modified — switch)

**Analog:** self (existing `.onChange` at lines 26-36).

**Current shape** uses `guard case .activity(let uuid) = deepLink else { return }` (single-case consume). **Switch to `switch` statement** per RESEARCH §D81 (lines 430-447):
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
    case .none: break
    }
    appState.pendingDeepLink = nil
}
```

`AppDestination.tripDetail(PersistentIdentifier)` already exists at `AppDestination.swift:5` — do NOT add a new case.

---

### `Travellify/Features/Trips/TripEditSheet.swift` (modified — add Reminder Section)

**Analog:** `Travellify/Features/Activities/ActivityEditSheet.swift` (complete file — the reference implementation of Reminder Section wiring).

**Imports pattern** to add (ActivityEditSheet.swift:1-3):
```swift
import SwiftUI
import SwiftData
import UserNotifications   // NEW — required for UNAuthorizationStatus / UNUserNotificationCenter
```

**State additions** (mirror ActivityEditSheet.swift:19-28):
```swift
// Reminder state (Phase 6 D76/D82)
@State private var isReminderEnabled: Bool = false
@State private var leadMinutes: Int = TripReminderLeadTime.default.rawValue
@State private var authStatus: UNAuthorizationStatus = .notDetermined
@State private var showDeniedAlert: Bool = false

// Dirty-tracking snapshot — TRIP version uses startDate (not startAt)
@State private var initialIsReminderEnabled: Bool = false
@State private var initialLeadMinutes: Int? = nil
@State private var initialStartDate: Date = Date()
```

**scenePhase environment** to add: `@Environment(\.scenePhase) private var scenePhase` (ActivityEditSheet.swift:11).

**Reminder Section @ViewBuilder** — copy ActivityEditSheet.swift:132-148 verbatim, substitute:
- `ReminderLeadTime.allCases` → `TripReminderLeadTime.allCases`
- Section placement: after Destinations (TripEditSheet.swift:65-81), before the `.navigationTitle` modifier (line 83).

**Toggle + auth flow** — copy ActivityEditSheet.swift:152-179 verbatim (`handleToggleChange`, `requestAuthAndEnable`, `refreshAuthStatus`). No changes.

**Lifecycle hooks** — add to the NavigationStack's modifier chain (mirrors ActivityEditSheet.swift:112-126):
```swift
.task { await refreshAuthStatus() }
.onChange(of: scenePhase) { _, new in
    if new == .active { Task { await refreshAuthStatus() } }
}
.alert("Notifications are off", isPresented: $showDeniedAlert) { /* Open Settings / Cancel */ }
    message: { Text("Enable them in Settings to get activity reminders.") }
```

**loadInitialValuesIfNeeded** (TripEditSheet.swift:98-110) — extend with reminder snapshot (mirrors ActivityEditSheet.swift:183-200):
```swift
if case .edit(let trip) = mode {
    // ... existing name/startDate/endDate/destinations load ...
    isReminderEnabled = trip.isReminderEnabled
    leadMinutes = trip.reminderLeadMinutes ?? TripReminderLeadTime.default.rawValue
}
initialIsReminderEnabled = isReminderEnabled
initialLeadMinutes = {
    if case .edit(let trip) = mode { return trip.reminderLeadMinutes } else { return nil }
}()
initialStartDate = startDate
```

**save() dirty check** — mirror ActivityEditSheet.swift:232-243:
```swift
let newLeadMinutes: Int? = isReminderEnabled ? leadMinutes : nil
// write trip.isReminderEnabled = isReminderEnabled, trip.reminderLeadMinutes = newLeadMinutes
let reminderChanged = isReminderEnabled != initialIsReminderEnabled
    || newLeadMinutes != initialLeadMinutes
    || startDate != initialStartDate
    || (if-create-mode-unconditional)
try modelContext.save()
if reminderChanged {
    let context = modelContext
    Task { await NotificationScheduler.shared.reconcile(modelContext: context) }
}
```

**D74 additional changes (unrelated to reminders):**
1. Line 57 — change `DatePicker("End Date", selection: $endDate, displayedComponents: .date)` to `DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)`.
2. Add `.onChange(of: startDate) { _, newStart in if newStart > endDate { endDate = newStart } }` on the `$endDate` picker.
3. Delete `showEndDateError` branch (lines 58-62) and the computed property (lines 29-31).
4. Simplify `isValid` (line 25-27) to `true` (name-fallback handled in save).

---

### `Travellify/Features/Documents/DocumentThumbnail.swift` (modified — 1 line)

**Analog:** self.

**Current** (DocumentThumbnail.swift:23): `.aspectRatio(1, contentMode: .fit)`.
**Apply D70:** `.aspectRatio(3.0/4.0, contentMode: .fit)`.

Leave `.clipped()` (line 24) and `scaledToFill()` (line 15) unchanged. PDFKit path (line 57-63) is aspect-agnostic.

---

### `Travellify/Features/Documents/DocumentRow.swift` (modified — text alignment)

**Analog:** self. RESEARCH flagged CONTEXT's "HStack + chevron" description does NOT match code. Stay with the VStack grid-card (confirmed with DocumentListView.swift:68 `LazyVGrid`).

**Current** (DocumentRow.swift:20-25):
```swift
Text(document.displayName)
    .font(.subheadline)
    .foregroundStyle(.primary)
    .lineLimit(2)
    .multilineTextAlignment(.leading)
    .frame(maxWidth: .infinity, alignment: .leading)
```

**Apply D71:** change both alignments to `.center`:
```swift
.multilineTextAlignment(.center)
.frame(maxWidth: .infinity, alignment: .center)
```

Leave VStack (line 16), `.contentShape(Rectangle())` (line 27), and accessibility (line 28-29) unchanged.

---

### `Travellify/Features/Documents/DocumentListView.swift` (modified — optional)

**Analog:** self. Per D70/D71/D72, no direct edit required in DocumentListView unless the importer call sites need trip pass-through (already passed — lines 128, 144, 154).

**Confirm invariants:**
- `isImporting` serialization gate (line 27, 51-52) — preserved. D72 depends on this for @Query stability (RESEARCH Pitfall 1).
- `LazyVGrid` columns (lines 30-33) — preserved; `GridItem(.flexible())` drives width so the 3:4 aspect ratio derives height (RESEARCH §D70 Pitfall).

---

### `Travellify/Features/Documents/Import/DocumentImporter.swift` (modified — add helper + replace 3 sites)

**Analog:** self.

**Existing @MainActor static methods** (lines 11-103): `importScanResult`, `importPhotosItem`, `importFileURL` — all follow identical pattern: compute path, `Task.detached { write/copy }`, build `Document()`, `modelContext.insert`, `modelContext.save()`.

**Add helper after `localizedDateString()` (line 109)** — match existing private static helper style (line 107):
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

**Replace three displayName call sites:**
- Line 29: `doc.displayName = "Scan " + Self.localizedDateString()` → `doc.displayName = Self.nextDefaultName(in: trip)`
- Line 63: `doc.displayName = "Photo " + Self.localizedDateString()` → `doc.displayName = Self.nextDefaultName(in: trip)`
- Line 96: `doc.displayName = sourceName.isEmpty ? "Document" : sourceName` → `doc.displayName = Self.nextDefaultName(in: trip)`

`localizedDateString()` helper becomes unused if no other callers — safe to delete, but keeping is also fine.

---

### `Travellify/Features/Packing/EmptyPackingListView.swift` (modified — add Spacers)

**Analog:** self.

**Current** (EmptyPackingListView.swift:4-20): `VStack(spacing: 0) { Image; Text; Text }.padding(.horizontal, 32).frame(maxWidth: .infinity, maxHeight: .infinity)`.

**Apply D73** — wrap inner content with `Spacer(minLength: 0)` pair:
```swift
VStack(spacing: 0) {
    Spacer(minLength: 0)
    Image(systemName: "checklist") ...
    Text("No Categories Yet") ...
    Text("Tap + in the top right ...") ...
    Spacer(minLength: 0)
}
.padding(.horizontal, 32)
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

Leave accessibility (lines 21-22) unchanged.

---

### `Travellify/Features/Activities/ActivityEditSheet.swift` (modified — add `in:` to DatePicker)

**Analog:** self.

**Current** (ActivityEditSheet.swift:64-68):
```swift
DatePicker(
    "Starts",
    selection: $startAt,
    displayedComponents: [.date, .hourAndMinute]
)
```

**Apply D75:** add `in: trip.startDate...trip.endDate` parameter:
```swift
DatePicker(
    "Starts",
    selection: $startAt,
    in: trip.startDate...trip.endDate,
    displayedComponents: [.date, .hourAndMinute]
)
```

**Do NOT delete** the `isOutsideTripRange` soft-warn branch (lines 37-43, 71-82) — required for legacy state per D75 + RESEARCH Pitfall 5.

---

### `Travellify/Assets.xcassets/AppIcon.appiconset/Contents.json` + `icon-1024.png`

**Analog:** Contents.json itself already matches iOS 17+ single-size format (lines 1-13). One edit only — add `"filename"` key:

```json
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

**PNG constraints** (RESEARCH Pitfall 6): 1024x1024 exact, no alpha (`sips -g hasAlpha` → `hasAlpha: no`). No pbxproj entry (Assets.xcassets already registered).

---

### `Travellify/PrivacyInfo.xcprivacy` (NEW — no code analog)

**Reference:** Apple TN3183 spec. File contents exact per RESEARCH §D86 (lines 534-565) — CA92.1 + C617.1 reasons, tracking false, collected data empty.

**pbxproj additions (4 entries, Resources variant — NOT Sources):**
1. PBXFileReference with `lastKnownFileType = text.plist.xml`.
2. PBXBuildFile referencing it.
3. PBXGroup child under the top-level `Travellify/` group (sibling of ContentView.swift — **NOT** inside App/ or Shared/ subgroup, or the manifest will not copy to bundle root; RESEARCH Pitfall 7).
4. PBXResourcesBuildPhase entry (target's Resources phase at pbxproj line 470-476).

---

### `TravellifyTests/TripReminderFireDateTests.swift` (NEW — unit test)

**Analog:** `TravellifyTests/ReminderFireDateTests.swift` (complete file, 62 lines).

**Copy shape verbatim** — same `@MainActor struct`, same `fixedStart` Date fixture, same `@Test` functions. Substitute:
- `Activity` → `Trip`
- `a.startAt` → `t.startDate`
- Expected rawValues (line 15): `[15, 60, 180, 1440]` → `[1440, 4320, 10080, 20160]`
- Default test (lines 18-21): `.oneHour` / `60` → `.threeDays` / `4320`

**Imports pattern** (ReminderFireDateTests.swift:1-3):
```swift
import Testing
import Foundation
@testable import Travellify
```

**Fixture pattern** (lines 8-10):
```swift
private var fixedStart: Date {
    Date(timeIntervalSince1970: 1_700_000_000)
}
```

**Test pattern per case** (lines 25-32) — mirror for `fireDate(for: Trip)`:
```swift
@Test func fireDateIsStartMinusLeadWhenEnabled() {
    let t = Trip()
    t.startDate = fixedStart
    t.isReminderEnabled = true
    t.reminderLeadMinutes = 1440
    let expected = fixedStart.addingTimeInterval(-TimeInterval(1440 * 60))
    #expect(ReminderFireDate.fireDate(for: t) == expected)
}
// ... disabled → nil; leadMinutes nil → nil (mirror lines 34-48)
```

**pbxproj:** 4 entries under `TravellifyTests/` group.

---

### `TravellifyTests/ReminderSchemaTests.swift` (extended)

**Analog:** self (existing `activityHasReminderFieldsWithDefaults` test at lines 9-23).

**Add mirrored test** for Trip — same grep-gated shape:
```swift
@Test func tripHasReminderFieldsWithDefaults() {
    let tripPath = "Travellify/Models/Trip.swift"
    guard let src = try? String(contentsOfFile: tripPath, encoding: .utf8) else { return }
    #expect(src.contains("var isReminderEnabled: Bool = false"))
    #expect(src.contains("var reminderLeadMinutes: Int?"))
    #expect(!src.contains("@Attribute(.unique)"))
    #expect(!src.contains("@Attribute(.externalStorage)"))
}

@Test func newTripDefaultsAreReminderOff() throws {
    // Mirror lines 33-47 — insert Trip(), assert isReminderEnabled == false, reminderLeadMinutes == nil
}
```

`schemaV1StillHasSixModels` (line 25) and `migrationPlanStillHasNoStages` (line 29) — unchanged; they continue to pass since Phase 6 is additive.

---

### `TravellifyTests/ReminderLifecycleTests.swift` (extended)

**Analog:** self. Existing tests at lines 58-194 (`scheduleOnEnable`, `rescheduleOnDateChange`, `cancelOnDelete`, `cancelOnTripCascade`) are the shape template.

**Fixture extensions** (add after line 35):
```swift
private func enableTripReminder(_ trip: Trip, leadMinutes: Int = 4320) {
    trip.isReminderEnabled = true
    trip.reminderLeadMinutes = leadMinutes
}
```

**Add tests mirroring existing shape:**
- `tripToggleOffCancels` (TRIP-08) — mirror `cancelOnDelete` at lines 130-157; flip `trip.isReminderEnabled = false` instead of `ctx.delete`.
- `tripDateEditReschedules` (TRIP-08) — mirror `rescheduleOnDateChange` at lines 83-128; change `trip.startDate` instead of `activity.startAt`. Assert `identifier == "trip-\(trip.id.uuidString)"` stable across reconcile (drift Rule 1).
- `tripDeleteCancels` (TRIP-08) — mirror `cancelOnDelete`; `ctx.delete(trip)`.

**Critical pattern to preserve** (line 12-13 comment + lines 113-114, 154, 191):
```swift
// MockNotificationCenter.remove(...) dispatches via Task { @MainActor in },
// so after any cancel path: await Task.yield() before asserting mock.pending.
```

---

### `TravellifyTests/NotificationSchedulerTests.swift` (extended)

**Analog:** self. `soonestSixtyFour` at lines 52-77 is the shape template for union + cap.

**Add tests:**
- `unionSoonest64` (TRIP-09) — seed N activities + M trips with staggered fireDates; assert `mock.pending.count == 64` and identifier set matches sorted-union prefix. Use `"trip-\(t.id.uuidString)"` expectation for the trip slice.
- `tripIdentifierPrefix` (TRIP-09) — seed one trip reminder, assert `mock.pending.first?.identifier.hasPrefix("trip-")` AND `UUID(uuidString: identifier.dropFirst(5)) != nil`. Assert `userInfo["tripID"]` is the BARE uuid (no prefix) — critical disambiguation per RESEARCH Pitfall 8.

**Fixture pattern** (lines 31-48) — existing `insertActivity` helper; add parallel `insertTripReminder`:
```swift
@discardableResult
private func insertTripReminder(name: String, startDate: Date, leadMinutes: Int = 4320,
                                in context: ModelContext) -> Trip {
    let t = Trip()
    t.name = name
    t.startDate = startDate
    t.endDate = startDate.addingTimeInterval(86_400 * 7)
    t.isReminderEnabled = true
    t.reminderLeadMinutes = leadMinutes
    context.insert(t)
    return t
}
```

---

### `TravellifyTests/ImportTests.swift` (extended)

**Analog:** self. `makeContainer` + `makeTrip` fixtures at lines 16-32.

**Add tests** for `DocumentImporter.nextDefaultName(in:)`:
```swift
@Test func defaultNameStartsAtOne() throws {
    let container = try makeContainer()
    let ctx = ModelContext(container)
    let trip = makeTrip(in: ctx)
    #expect(DocumentImporter.nextDefaultName(in: trip) == "doc-1")
}

@Test func defaultNameIncrementsPastMax() throws {
    // Insert doc-1, doc-3 (non-contiguous per D72 — no gap reuse)
    // Expect doc-4
}

@Test func defaultNameIgnoresNonMatching() throws {
    // Insert "Passport.pdf" + "doc-2" → expect doc-3
}
```

---

### `TravellifyTests/ActivityTests.swift` (extended)

**Analog:** self.

**Add test** to lock `isOutsideTripRange` day-level compare semantics per D75 (ActivityEditSheet.swift:37-43):
```swift
@Test func outsideRangeIsDayLevel() {
    // Activity startAt = trip.endDate + 1 second same-day → NOT outside (day-level).
    // Activity startAt = trip.endDate + 86_400 → outside.
}
```

---

## Shared Patterns

### Pattern: @MainActor SwiftData + SwiftUI form sheet
**Source:** `Travellify/Features/Activities/ActivityEditSheet.swift`
**Apply to:** `TripEditSheet` Reminder Section additions.

Key invariants (copy verbatim):
- `@State var didLoadInitialValues = false` + `loadInitialValuesIfNeeded()` guard (ActivityEditSheet.swift:17, 183-200).
- Snapshot initial values AFTER load for dirty tracking (lines 196-199).
- `Task { await NotificationScheduler.shared.reconcile(modelContext: context) }` fire-and-forget on save (lines 240-242). Capture `modelContext` into a local `context` constant BEFORE the Task — do not close over the environment directly.

### Pattern: Denied-alert + scenePhase auth refresh
**Source:** `ActivityEditSheet.swift:113-126, 152-179`
**Apply to:** `TripEditSheet` Reminder Section.

Lock the alert copy exactly as-is: title `"Notifications are off"`, message `"Enable them in Settings to get activity reminders."`, buttons `Open Settings` / `Cancel`. Phase 6 research flags generalization as out of scope.

### Pattern: CloudKit-safe additive @Model field
**Source:** `Travellify/Models/Activity.swift` D52 precedent + `TravellifyTests/ReminderSchemaTests.swift`
**Apply to:** Trip.swift additions.

- Both fields MUST have defaults.
- No `@Attribute(.unique)`, no `@Attribute(.externalStorage)`, no `.deny` delete rule.
- SchemaTests / ReminderSchemaTests grep-gate these invariants — adding the mirrored test is the safety net.

### Pattern: Swift Testing @MainActor struct + in-memory ModelContainer
**Source:** `TravellifyTests/ReminderLifecycleTests.swift:14-26, ReminderFireDateTests.swift:5-10`
**Apply to:** all new tests (TripReminderFireDateTests + all extensions).

```swift
import Testing
import SwiftData
import Foundation
@preconcurrency import UserNotifications   // only when touching UNUserNotificationCenter
@testable import Travellify

@MainActor
struct SomeTests {
    private func makeContainer() throws -> ModelContainer { /* ModelConfiguration(isStoredInMemoryOnly: true) */ }
}
```

Critical: `await Task.yield()` after any reconcile cancel path before asserting `mock.pending` (MockNotificationCenter dispatches remove via `Task { @MainActor in }`).

### Pattern: pbxproj 4-entry hand-edit for new Swift file
**Source:** CLAUDE.md + CONTEXT.md line 47.
**Apply to:** `TripReminderLeadTime.swift`, `TripReminderFireDateTests.swift`.

Each needs PBXBuildFile + PBXFileReference + PBXGroup child + Sources build-phase entry. Place under `Shared/` group and `TravellifyTests/` group respectively.

**For `PrivacyInfo.xcprivacy`:** same 4-count but the last entry goes to the **Resources** build-phase, not Sources, and `lastKnownFileType = text.plist.xml`. Parent PBXGroup MUST be the top-level `Travellify/` group.

---

## No Analog Found

| File | Role | Reason | Reference |
|---|---|---|---|
| `Travellify/PrivacyInfo.xcprivacy` | Apple privacy manifest (plist) | First privacy manifest in repo; no prior plist of this category | Apple TN3183 + RESEARCH §D86 (verbatim plist in research doc) |
| `Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png` | binary asset | No prior branded icon | Placeholder PNG — RESEARCH §D85 |

Planner should pull content verbatim from RESEARCH.md for these two (plist body lines 534-565; PNG constraints from Pitfall 6).

---

## Metadata

**Analog search scope:** `Travellify/` + `TravellifyTests/` (full in-repo scan via Bash ls).
**Files read:** Trip.swift, SchemaV1.swift, AppState.swift, AppDelegate.swift, AppDestination.swift, ContentView.swift, ActivityEditSheet.swift, TripEditSheet.swift, DocumentRow.swift, DocumentThumbnail.swift, DocumentListView.swift, DocumentImporter.swift, EmptyPackingListView.swift, ReminderLeadTime.swift, ReminderFireDate.swift, NotificationScheduler.swift, ReminderFireDateTests.swift, ReminderLifecycleTests.swift, ReminderSchemaTests.swift, NotificationSchedulerTests.swift, ImportTests.swift, Assets.xcassets/AppIcon.appiconset/Contents.json.
**Pattern extraction date:** 2026-04-24.
