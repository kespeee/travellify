# Phase 5: Notifications — Pattern Map

**Mapped:** 2026-04-22
**Files analyzed:** 16 (6 new source + 5 new tests + 5 modified)
**Analogs found:** 15 / 16 (AppDelegate has no in-repo analog — new territory)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Travellify/Shared/NotificationScheduler.swift` | Service (`@MainActor` class) | Event-driven + async system IO | `Travellify/Shared/ActivityDateLabels.swift` (pure static) | partial — same "Shared helper" slot, different shape (class vs enum) |
| `Travellify/Shared/ReminderLeadTime.swift` | Value type (enum) | Pure | `Travellify/Shared/ActivityDateLabels.swift` | role-match (Shared enum) |
| `Travellify/Shared/NotificationCenterProtocol.swift` | Protocol (testability) | N/A | no in-repo analog; closest is `ActivityDateLabels.swift` (Shared utility) | new pattern |
| `Travellify/App/AppDelegate.swift` | App-wiring (UIKit bridge) | Delegate callbacks | `Travellify/App/TravellifyApp.swift` (sibling in App/) | structural only — no prior UIApplicationDelegate in repo |
| `Travellify/Shared/ReminderPrimingSheet.swift` | View (sheet) | Request-response | `Travellify/Features/Activities/EmptyActivitiesView.swift` / `TripEmptyState.swift` | partial — centered content + single CTA |
| `Travellify/Models/Activity.swift` (modified) | Model | CRUD | precedent: its own D40 landing | exact (same additive pattern) |
| `Travellify/Features/Activities/ActivityEditSheet.swift` (modified) | View (Form sheet) | Request-response | itself (existing `Section`s + soft-warn row) | exact |
| `Travellify/Features/Activities/ActivityListView.swift` (modified) | View (list) | CRUD | itself (existing `delete(_:)` + `save` paths) | exact |
| `Travellify/App/TravellifyApp.swift` (modified) | App-wiring | Lifecycle | itself | exact |
| `Travellify/Features/Trips/TripListView.swift` (modified) | View | CRUD | itself (existing delete-confirm alert) | exact |
| `TravellifyTests/ReminderSchemaTests.swift` | Test (grep-gated) | Unit | `TravellifyTests/SchemaTests.swift` | exact |
| `TravellifyTests/ReminderFireDateTests.swift` | Test (pure-fn) | Unit | `TravellifyTests/DayLabelTests.swift` | role-match |
| `TravellifyTests/NotificationSchedulerTests.swift` | Test (service) | Unit w/ mock | `TravellifyTests/NextUpcomingTests.swift` (in-memory container + fixtures) | role-match |
| `TravellifyTests/ReminderLifecycleTests.swift` | Test (integration) | CRUD | `TravellifyTests/ActivityTests.swift` | exact |
| `TravellifyTests/PermissionStateTests.swift` | Test (VM-level) | Unit | `TravellifyTests/DayLabelTests.swift` | role-match |
| `Travellify.xcodeproj/project.pbxproj` (modified) | Build config | N/A | existing `ActivityEditSheet.swift` / `DayLabelTests.swift` entries | exact template |

---

## Pattern Assignments

### `Travellify/Shared/ReminderLeadTime.swift` (new, value enum)

**Analog:** `Travellify/Shared/ActivityDateLabels.swift` (slot-mate: Shared enum, pure, no dependencies).

**Shape to follow:** single-file enum, `Int`-raw-valued, `CaseIterable + Identifiable`, `id` computed from `rawValue`, static `.default`, `label: String` via `switch`.

**Canonical spec already in RESEARCH.md §"ReminderLeadTime preset enum" (lines 572–590).** Use it verbatim — values lock D50 presets (15/60/180/1440).

**CONVENTIONS hit:** none special (pure value type; no SwiftData, no concurrency surface).

---

### `Travellify/Shared/NotificationCenterProtocol.swift` (new, protocol)

**Analog:** no in-repo protocol abstraction over a system singleton exists; pattern is net-new.

**Canonical spec in RESEARCH.md §10 (lines 289–314) and §"NotificationCenterProtocol" (lines 596–605):**

```swift
protocol NotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func notificationSettings() async -> UNNotificationSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}
extension UNUserNotificationCenter: NotificationCenterProtocol {}
```

**CONVENTIONS hits:**
- Swift 6 Sendable: declare `: Sendable` on the protocol (UNUserNotificationCenter is Sendable, safe).
- **Do NOT** pass `UNNotificationRequest` / `UNMutableNotificationContent` across actor boundaries — they are non-Sendable. Protocol methods must be called from the same actor that constructs the request (see Pitfall 4 in RESEARCH).

---

### `Travellify/Shared/NotificationScheduler.swift` (new, `@MainActor` service class)

**Analog:** `Travellify/Shared/ActivityDateLabels.swift` is the closest slot-mate (Shared namespace) but shape differs — scheduler is `@MainActor final class` with injected dependency.

**Header imports pattern (from `ActivityDateLabels.swift:1`):**
```swift
import Foundation
import SwiftData            // new — NotificationScheduler needs ModelContext
import UserNotifications    // new
```

**Core pattern — use RESEARCH.md §"Core scheduler shape" (lines 458–554) verbatim.** Key invariants:

1. `@MainActor final class NotificationScheduler` with `static let shared` — mirrors existing singleton-like usage in `ActivityDateLabels` (enum with static members).
2. Init takes `center: NotificationCenterProtocol = UNUserNotificationCenter.current()` for testability.
3. `reconcile(modelContext: ModelContext) async` — the only public mutation entry.
4. Fetch via `FetchDescriptor<Activity>(predicate: #Predicate { $0.isReminderEnabled == true })`.
5. Soonest-64 selection: `.compactMap` → `.sorted { $0.1 < $1.1 }` → `.prefix(64)`.
6. Diff by `identifier == activity.id.uuidString` (Set intersection/subtraction).
7. Per-request error: `do { try await center.add(request) } catch { /* log + continue; never abort */ }`.
8. `reuse of` `ActivityDateLabels.timeLabel(for:)` inside `body(for:in:fireDate:)` — see `ActivityDateLabels.swift:66–68`.

**fireDate helper pattern — RESEARCH §"fireDate helper" (lines 559–567):** pure function, nil-returning guard chain. Place it as a nested `enum ReminderFireDate` in `NotificationScheduler.swift` OR split to its own file (context implies single file; planner's call).

**Calendar trigger construction — RESEARCH §4 (lines 132–143):**
```swift
var calendar = Calendar.current
calendar.timeZone = .current
var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
components.timeZone = .current    // CRITICAL — else GMT interpretation
return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
```

**CONVENTIONS hits:**
- **Swift 6 concurrency (CONVENTIONS §"Swift 6 concurrency"):** `@MainActor` on the class. Do NOT use `Task.detached` for body construction — non-Sendable `UNMutableNotificationContent` cannot cross actors. The `await center.pendingNotificationRequests()` call naturally yields the main thread without `Task.detached`.
- **CloudKit-safe (CONVENTIONS §"SwiftData"):** scheduler reads via `FetchDescriptor`, does not write to models.
- **pbxproj 4-entry** required (see §"pbxproj additions" below).
- **Reuse `ActivityDateLabels.timeLabel(for:)`** for `content.body` `timeString`.

---

### `Travellify/App/AppDelegate.swift` (new, UIKit bridge)

**Analog:** no prior in-repo `UIApplicationDelegate`. `Travellify/App/TravellifyApp.swift` is the sibling; AppDelegate lands next to it.

**Canonical spec — RESEARCH §2 (lines 70–89) + §3 (lines 97–120):**

```swift
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions:
                       [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions { [.banner, .sound] }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let s = info["activityID"] as? String,
              let uuid = UUID(uuidString: s) else { return }
        AppState.shared.pendingDeepLink = .activity(uuid)
    }
}
```

**CONVENTIONS hits:**
- **Swift 6 concurrency:** use `@preconcurrency UNUserNotificationCenterDelegate` (Travellify is on Swift 6.0, not 6.2). Track as tech debt (RESEARCH Pitfall 9).
- **Always `async` delegate methods**, never completion-handler forms (crash under Swift 6 — RESEARCH Pitfall 1, Apple Forum 762217).
- **pbxproj 4-entry** required, placed in the same `App/` group as `TravellifyApp.swift` and `AppDestination.swift`.

---

### `Travellify/Shared/ReminderPrimingSheet.swift` (new, View)

**Analog — layout shape:** `Travellify/Features/Activities/EmptyActivitiesView.swift` / `Travellify/Features/Trips/TripEmptyState.swift` (centered icon + title + message + CTA). Read one of these for the exact stack layout + accessibility modifiers.

**Canonical behaviour — RESEARCH §7 (lines 206–257):** presented via `.sheet(isPresented:)` from inside `ActivityEditSheet` (iOS 17+ supports nested sheets). Single "Enable reminders" button flips `UserDefaults` `hasSeenReminderPriming`, calls `requestAuthorization`, then dismisses.

**CONVENTIONS hits:**
- **SwiftUI §"Large @ViewBuilder bodies":** keep priming sheet body concise; extract helper views if it grows past ~80 lines.
- **SwiftUI §"PhotosPicker inside Menu" is NOT applicable**, but general "no sheet-inside-odd-container" caution applies — keep the sheet presentation at `ActivityEditSheet`'s top-level modifier chain, not nested inside a `Section { ... }.sheet(...)`.

---

### `Travellify/Models/Activity.swift` (MODIFIED — additive)

**Analog:** itself. D40 (Phase 4) already landed additive fields (`title`, `startAt`, `location`, `notes`, `createdAt`) in `SchemaV1`. D52 is the same pattern.

**Current shape (lines 5–19):**
```swift
extension TravellifySchemaV1 {
    @Model
    final class Activity {
        var id: UUID = UUID()
        var trip: Trip?
        var title: String = ""
        var startAt: Date = Date()
        var location: String?
        var notes: String?
        var createdAt: Date = Date()
        init() {}
    }
}
```

**Additions (D52) — append before `init()`:**
```swift
// Phase 5 additions (D52) — additive, defaults ensure SwiftData lightweight
// migration stays inside SchemaV1. CloudKit-safe (no @Attribute, no .unique).
var isReminderEnabled: Bool = false
var reminderLeadMinutes: Int? = nil
```

**CONVENTIONS hits (non-negotiable):**
- **Default values on every stored property** (SwiftData lightweight migration requirement).
- **No `@Attribute(.unique)`**, **no `@Attribute(.externalStorage)`**, **no new `@Model`** (stays at 6 models — asserted by `SchemaTests.schemaV1HasSixModels` at `SchemaTests.swift:18`).
- **Additive-only → stays in SchemaV1** (no V2, no migration stage). `TravellifyMigrationPlan.stages` must remain empty per `SchemaTests.swift:22–25`.

---

### `Travellify/Features/Activities/ActivityEditSheet.swift` (MODIFIED)

**Analog:** itself.

**Existing imports (lines 1–2):** `import SwiftUI` + `import SwiftData`. Add `import UserNotifications` for `UNAuthorizationStatus`.

**Existing soft-warn row pattern (lines 58–69) — REUSE VERBATIM for denied-state row:**
```swift
HStack(spacing: 6) {
    Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
        .imageScale(.small)
    Text("Outside trip dates")
        .font(.caption)
        .foregroundStyle(.secondary)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Warning: activity is outside trip dates")
```

For D54 denied-state, adapt this shape: swap symbol to `"bell.slash"` (or keep `"exclamationmark.triangle.fill"` with `.orange` for consistency — see D41 precedent), text `"Notifications disabled."`, add a `Button("Open Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }` row below.

**Section placement pattern (D64) — insert new `Section("Reminder")` BETWEEN existing `Section("Notes")` (lines 77–80) and closing brace of `Form` (line 81).**

**State additions — follow existing `@State` block (lines 11–15):**
```swift
@State private var isReminderEnabled: Bool = false
@State private var leadMinutes: Int = ReminderLeadTime.default.rawValue   // D51
@State private var authStatus: UNAuthorizationStatus = .notDetermined
@State private var isPrimingShown: Bool = false
@Environment(\.scenePhase) private var scenePhase
```

**loadInitialValuesIfNeeded pattern (lines 103–114) — MIRROR for new fields:**
```swift
if let activity {
    isReminderEnabled = activity.isReminderEnabled
    leadMinutes = activity.reminderLeadMinutes ?? ReminderLeadTime.default.rawValue
}
```

**save() pattern (lines 118–144) — add dirty-check then reconcile hook:**
```swift
// ... existing mutations ...
let reminderChanged = /* detect isReminderEnabled/leadMinutes/startAt delta */
do {
    try modelContext.save()
    if reminderChanged {
        Task { await NotificationScheduler.shared.reconcile(modelContext: modelContext) }
    }
} catch { assertionFailure(...) }
```
(Per Pitfall 6: only call `reconcile()` when reminder-affecting fields mutated.)

**Auth refresh on reappear — add `.task { await refreshAuthStatus() }` and `.onChange(of: scenePhase)` (RESEARCH §8 lines 263–277).**

**Nested sheet — add `.sheet(isPresented: $isPrimingShown) { ReminderPrimingSheet(...) }` at the NavigationStack level (line 98), not inside `Section`.**

**CONVENTIONS hits:**
- **SwiftUI §"Large @ViewBuilder bodies":** this Form is already ~40 lines; adding Reminder Section + denied row may push past the safe limit. If the type-checker complains, split the Reminder Section into a `@ViewBuilder` private func `reminderSection()`.
- **SwiftUI §"@FocusState race":** not applicable; no new focus state added.

---

### `Travellify/Features/Activities/ActivityListView.swift` (MODIFIED)

**Analog:** itself — existing `delete(_:)` and `save(_:)` pattern at lines 120–128.

**Existing pattern (lines 120–128):**
```swift
private func delete(_ activity: Activity) {
    modelContext.delete(activity)
    save("Couldn't delete activity. Please try again.")
}
private func save(_ failureMessage: String) {
    do { try modelContext.save() }
    catch { errorMessage = failureMessage }
}
```

**Modification — call `reconcile()` after the save succeeds:**
```swift
private func save(_ failureMessage: String) {
    do {
        try modelContext.save()
        Task { await NotificationScheduler.shared.reconcile(modelContext: modelContext) }
    } catch { errorMessage = failureMessage }
}
```

(Cheap to over-call from pure delete paths; D57 says `reconcile()` is idempotent.)

---

### `Travellify/App/TravellifyApp.swift` (MODIFIED)

**Analog:** itself (28 lines total — read in full above).

**Current shape (lines 4–27):** `@main struct TravellifyApp: App` with `init()` that builds `ModelContainer`, and `body` that hosts `ContentView().modelContainer(container).preferredColorScheme(.dark)`.

**Modifications:**

1. **Add `@UIApplicationDelegateAdaptor`** (RESEARCH §2 line 77):
```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
@Environment(\.scenePhase) private var scenePhase
```

2. **ScenePhase → reconcile (D57)** — add to body's WindowGroup (RESEARCH §"ScenePhase reconcile hook" lines 614–625):
```swift
WindowGroup {
    ContentView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
.onChange(of: scenePhase) { _, new in
    if new == .active {
        Task { @MainActor in
            await NotificationScheduler.shared.reconcile(modelContext: container.mainContext)
        }
    }
}
```

**CONVENTIONS hits:**
- **Explicit model list on `ModelContainer`** already followed (line 11–13). Leave unchanged; Activity is already registered.
- **pbxproj 4-entry** for the new `AppDelegate.swift` in the `App/` group.

---

### `Travellify/Features/Trips/TripListView.swift` (MODIFIED)

**Analog:** itself — existing delete-confirmation alert (lines 60–87).

**Existing pattern (lines 67–80):**
```swift
Button("Delete", role: .destructive) {
    let tripIDString = trip.id.uuidString
    modelContext.delete(trip)
    do {
        try modelContext.save()
        try? FileStorage.removeTripFolder(tripIDString: tripIDString)
    } catch { /* keep file state consistent */ }
    tripPendingDelete = nil
}
```

**Modification — append reconcile after successful save, BEFORE file cleanup** (cascade has already nulled activities in the store, so `reconcile()` will see them gone and cancel their pending requests):
```swift
try modelContext.save()
Task { await NotificationScheduler.shared.reconcile(modelContext: modelContext) }
try? FileStorage.removeTripFolder(tripIDString: tripIDString)
```

Note: same reconcile hook pattern applies to any other trip-delete site (e.g., `TripDetailView` if it exposes delete — planner to verify).

---

### `TravellifyTests/ReminderSchemaTests.swift` (new)

**Analog:** `TravellifyTests/SchemaTests.swift` (exact match — grep-gate pattern).

**Copy structure from `SchemaTests.swift:1–46`:**

```swift
import Testing
import SwiftData
@testable import Travellify

@MainActor
struct ReminderSchemaTests {
    @Test func activityHasReminderFieldsWithDefaults() throws {
        let path = "Travellify/Models/Activity.swift"
        guard let src = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        #expect(src.contains("var isReminderEnabled: Bool = false"))
        #expect(src.contains("var reminderLeadMinutes: Int?"))
        #expect(!src.contains("@Attribute(.unique)"))
        #expect(!src.contains("@Attribute(.externalStorage)"))
    }

    @Test func schemaV1StillHasSixModels() {
        #expect(TravellifySchemaV1.models.count == 6)   // D52 additive → unchanged
    }

    @Test func migrationPlanStillHasNoStages() {
        #expect(TravellifyMigrationPlan.stages.isEmpty)
    }

    @Test func newActivityDefaultsAreReminderOff() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            configurations: config
        )
        let a = Activity()
        container.mainContext.insert(a)
        try container.mainContext.save()
        #expect(a.isReminderEnabled == false)
        #expect(a.reminderLeadMinutes == nil)
    }
}
```

**CONVENTIONS hits:** grep-gate path `"Travellify/Models/Activity.swift"` — tests must tolerate cwd resolution failure (`guard let src = ... else { return }`, as `SchemaTests.swift:30–31`).

---

### `TravellifyTests/ReminderFireDateTests.swift` (new)

**Analog:** `TravellifyTests/DayLabelTests.swift` (pure-function tests with fixed `Date` inputs).

**Structure pattern — from `DayLabelTests.swift` (header `@MainActor struct`, Swift Testing `@Test`):**

```swift
import Testing
import Foundation
@testable import Travellify

@MainActor
struct ReminderFireDateTests {
    @Test func fireDateSubtractsLeadMinutes() { ... }
    @Test func returnsNilWhenReminderDisabled() { ... }
    @Test func returnsNilWhenLeadMinutesNil() { ... }
    @Test func respectsDSTBoundary() { ... }
}
```

---

### `TravellifyTests/NotificationSchedulerTests.swift` (new)

**Analog:** `TravellifyTests/NextUpcomingTests.swift` — in-memory `ModelContainer` + fixture insertion + assertion on pure logic (also `ActivityGroupingTests.swift` for the 64-selection sort).

**Fixture pattern — from `NextUpcomingTests.swift:9–38`:**
```swift
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: config
    )
}
private func makeTrip(in context: ModelContext) -> Trip { ... }
private func insertActivity(title:startAt:trip:in:) { ... }
```

**Mock injection pattern — RESEARCH §10 (lines 296–314):** build `@MainActor final class MockNotificationCenter` conforming to `NotificationCenterProtocol`, keep `pending: [UNNotificationRequest]` and `authStatus`. Inject into `NotificationScheduler(center:)`.

**Key tests to implement:**
- `soonestSixtyFour` — seed 100 activities, expect exactly 64 scheduled, all with earliest `fireDate`s.
- `diffIdempotent` — call `reconcile()` twice, assert same pending set.
- `pastDatesIgnored` — past `fireDate` not scheduled.
- `identifierMatchesUUID` — `request.identifier == activity.id.uuidString`.

**CONVENTIONS hits:**
- **Swift 6:** MockNotificationCenter must be `@MainActor` (its mutable `pending` array). See RESEARCH §10 note on `@unchecked Sendable` as alternative.
- **Non-Sendable UNNotificationRequest:** construct requests inside mock's main-actor methods; never pass across `Task.detached`.

---

### `TravellifyTests/ReminderLifecycleTests.swift` (new)

**Analog:** `TravellifyTests/ActivityTests.swift` (exact — same integration shape: in-memory container, trip + activity fixture, mutate + save + assert).

**Helper copy from `ActivityTests.swift:11–27`:**
```swift
private func makeContainer() throws -> ModelContainer { ... }
private func makeTrip(in context: ModelContext) -> Trip { ... }
```

**Tests map (from RESEARCH Phase Requirements → Test Map):**
- `scheduleOnEnable` (ACT-07)
- `rescheduleOnDateChange` (ACT-08)
- `cancelOnDelete` (ACT-08)
- `cancelOnTripCascade` (ACT-08) — mirrors existing `ActivityTests.deleteTripCascadesToActivities` at lines 104–121.

All tests use injected `MockNotificationCenter` (shared fixture from NotificationSchedulerTests or a test-only `Support/MockNotificationCenter.swift`).

---

### `TravellifyTests/PermissionStateTests.swift` (new)

**Analog:** `TravellifyTests/DayLabelTests.swift` (pure-function-ish, value-in/value-out assertions).

**Tests:** VM-level derivation — given `UNAuthorizationStatus` input, expected toggle-enabled-state + row-shown state. Does not touch real `UNUserNotificationCenter`.

---

## Shared Patterns

### Swift Testing framework boilerplate

**Source:** `TravellifyTests/SchemaTests.swift:1–6`, `ActivityTests.swift:1–18`, `NextUpcomingTests.swift:1–25`
**Apply to:** every new test file.

```swift
import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct <Name>Tests {
    // @Test funcs
}
```

Every test that touches SwiftData uses the same `makeContainer()` helper — always includes the full 6-model list (`Trip, Destination, Document, PackingItem, PackingCategory, Activity`) and always uses `ModelConfiguration(isStoredInMemoryOnly: true)`.

### Soft-warn row (D41)

**Source:** `ActivityEditSheet.swift:58–69`
**Apply to:** D54 denied-permission row inside the new Reminder Section.

(See excerpt in the ActivityEditSheet section above.)

### reconcile() call-site pattern

**Source:** this phase (new).
**Apply to:** every mutation path that could change reminder state — `ActivityEditSheet.save()`, `ActivityListView.save()`, `TripListView` delete alert, any future activity-delete path.

```swift
Task { await NotificationScheduler.shared.reconcile(modelContext: modelContext) }
```

Idempotent and cheap; prefer over-calling to under-calling.

### In-memory `ModelContainer` fixture

**Source:** `ActivityTests.swift:11–18`, `NextUpcomingTests.swift:9–16`, `ActivityGroupingTests.swift:9–16`, `#Preview`s in `ActivityListView.swift:135–182`
**Apply to:** all new test files + any `#Preview` blocks in new SwiftUI files.

Always list all 6 models explicitly (CONVENTIONS §SwiftData).

### pbxproj 4-entry registration

**Source templates (from `project.pbxproj`):**
- New source file in `Shared/` group → template is `ActivityDateLabels.swift` at lines 44, 85, 275, 484.
- New source file in `Features/Activities/` → template is `ActivityEditSheet.swift` at lines 45, 86, 198, 485.
- New source file in `App/` → template is `TravellifyApp.swift` (look up its four entries in pbxproj).
- New test file → template is `DayLabelTests.swift` at lines 51, 92, 264, 460 (or `NextUpcomingTests.swift` at 70, 145, 265, 461).

**Four entries per new `.swift` file (CONVENTIONS §"project.pbxproj"):**
1. `PBXBuildFile` section — `AD<uniq>01 /* <File>.swift in Sources */ = {isa = PBXBuildFile; fileRef = AD<uniq>02 ...};`
2. `PBXFileReference` section — `AD<uniq>02 /* <File>.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = <File>.swift; sourceTree = "<group>";};`
3. `PBXGroup` children list — `AD<uniq>02 /* <File>.swift */,` in the group matching its on-disk folder.
4. `PBXSourcesBuildPhase` files list — `AD<uniq>01 /* <File>.swift in Sources */,` on the Travellify (or TravellifyTests) target.

Missing any ONE → silent link failure or "Cannot find type X" at build time.

**Files requiring new pbxproj entries (10 × 4 = 40 lines added):**
- `Shared/NotificationScheduler.swift`, `Shared/ReminderLeadTime.swift`, `Shared/NotificationCenterProtocol.swift`, `Shared/ReminderPrimingSheet.swift` → `Shared/` group
- `App/AppDelegate.swift` → `App/` group
- `TravellifyTests/ReminderSchemaTests.swift`, `ReminderFireDateTests.swift`, `NotificationSchedulerTests.swift`, `ReminderLifecycleTests.swift`, `PermissionStateTests.swift` → `TravellifyTests/` group (+ optional `Support/MockNotificationCenter.swift` per RESEARCH Wave 0 Gap).

---

## Project-Specific Gotchas Applicable to Phase 5

(All sourced from `.planning/CONVENTIONS.md`.)

| Gotcha | Phase 5 touchpoint |
|--------|--------------------|
| **DEVELOPER_DIR prefix** required on every `xcodebuild` | All test commands in RESEARCH §"Validation Architecture" (already prefixed). |
| **Canonical simulator = `iPhone 16e`** | All test commands must target this. |
| **pbxproj 4-entry rule** | 10 new files × 4 entries each. |
| **Stale SourceKit diagnostics** | Expect red squiggles on new `NotificationScheduler.swift` / `AppDelegate.swift` references; trust `xcodebuild` output. |
| **CloudKit-safe SwiftData** | D52 additive fields (Bool with default, Int? optional) — compliant. No `@Attribute(.unique)`, no `.externalStorage`. No new `@Model`. |
| **Additive → SchemaV1, no V2** | `TravellifyMigrationPlan.stages` stays empty. `TravellifySchemaV1.models.count == 6` unchanged. |
| **Swift 6 static View helper `@MainActor` inference** | `NotificationScheduler.shared` entry is `@MainActor`. Do NOT call it from `Task.detached` with non-Sendable args. |
| **`Task.detached` only captures Sendable primitives** | `UNNotificationRequest` and `UNMutableNotificationContent` are NOT Sendable — construct and consume on the same `@MainActor` (RESEARCH §6, Pitfall 4). Never cross actor boundaries with them. |
| **`@Model` never crosses actor boundary** | Pass `Activity.id: UUID` (Sendable) into any background task, not the `Activity` itself. Scheduler stays on `@MainActor` so this mostly doesn't bite. |
| **`static let` in VersionedSchema** | Not relevant (no new VersionedSchema). |
| **SwiftUI large `@ViewBuilder` bodies** | `ActivityEditSheet` may grow past safe limit; extract `@ViewBuilder private func reminderSection() -> some View` if type-checker times out. |
| **`@FocusState` race** | N/A — no new focus state. |
| **`PhotosPicker` inside `Menu`** | N/A, but reminder: priming sheet must be a `.sheet(isPresented:)` at view top level, not nested weirdly. |
| **Routing uses `PersistentIdentifier`** | Deep-link payload is `UUID` (not `PersistentIdentifier`) because `PersistentIdentifier` doesn't round-trip through `userInfo` (RESEARCH §12). Resolve UUID → Activity → `trip.persistentModelID` → `AppDestination.activityList(…)`. |

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Travellify/App/AppDelegate.swift` | UIKit delegate bridge | Delegate callbacks | No prior `UIApplicationDelegate` in repo. Follow RESEARCH §2–§3 verbatim. |
| `Travellify/Shared/NotificationCenterProtocol.swift` | Testability protocol over system singleton | N/A | No prior protocol abstraction; pattern introduced fresh per RESEARCH §10. |

Planner should reference RESEARCH.md directly for these two.

---

## Metadata

**Analog search scope:** `Travellify/` (all subdirectories), `TravellifyTests/`, `Travellify.xcodeproj/project.pbxproj`.
**Files read:** `CONTEXT.md`, `RESEARCH.md`, `CONVENTIONS.md`, Phase-4 `CONTEXT.md`, `ActivityDateLabels.swift`, `ActivityEditSheet.swift`, `ActivityListView.swift`, `Activity.swift`, `TravellifyApp.swift`, `TripListView.swift`, `SchemaTests.swift`, `ActivityTests.swift`, `ActivityGroupingTests.swift`, `NextUpcomingTests.swift` head, pbxproj (grepped).
**Pattern extraction date:** 2026-04-22

## PATTERN MAPPING COMPLETE
