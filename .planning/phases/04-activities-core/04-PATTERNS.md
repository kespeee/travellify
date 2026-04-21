# Phase 4: Activities (Core) — Pattern Map

**Mapped:** 2026-04-21
**Files analyzed:** 11 (6 new, 5 modified)
**Analogs found:** 11 / 11

## File Classification

### New files

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `Travellify/Features/Activities/ActivityListView.swift` | screen view | CRUD + trip-scoped @Query | `Travellify/Features/Packing/PackingListView.swift` | exact (tripID + #Predicate) |
| `Travellify/Features/Activities/ActivityEditSheet.swift` | sheet (add+edit) | form request-response | `Travellify/Features/Trips/TripEditSheet.swift` | exact (Mode enum + didLoadInitialValues) |
| `Travellify/Features/Activities/ActivityRow.swift` | row cell | read-only display | `Travellify/Features/Packing/PackingRow.swift` (structure) / `Travellify/Features/Documents/DocumentRow.swift` (date formatting) | exact |
| `Travellify/Features/Activities/ActivityDayHeader.swift` | section header | read-only display (derived label) | `Travellify/Features/Packing/CategoryHeader.swift` | role-match |
| `Travellify/Features/Activities/EmptyActivitiesView.swift` | empty state | read-only | `Travellify/Features/Packing/EmptyPackingListView.swift` | exact |
| `Travellify/Shared/ActivityDateLabels.swift` | pure utility | stateless transform | `Travellify/Features/Trips/TripPartition.swift` | role-match (pure static + now-param) |
| `TravellifyTests/ActivityTests.swift` | test | model round-trip | `TravellifyTests/PackingTests.swift` | exact |
| `TravellifyTests/ActivityGroupingTests.swift` | test | in-memory grouping | `TravellifyTests/PartitionTests.swift` | exact (static-fn + now injection) |
| `TravellifyTests/DayLabelTests.swift` | test | formatter determinism | `TravellifyTests/PartitionTests.swift` | role-match |
| `TravellifyTests/NextUpcomingTests.swift` | test | smart-card computation | `TravellifyTests/PartitionTests.swift` | exact |

### Modified files

| Modified File | Current Shape | Change Required |
|---------------|---------------|-----------------|
| `Travellify/Models/Activity.swift` | Placeholder: `id`, `trip` only | Add `title`, `startAt`, `location?`, `notes?`, `createdAt` (D40) |
| `Travellify/App/AppDestination.swift` | 3 cases (tripDetail, documentList, packingList) | Add `.activityList(PersistentIdentifier)` |
| `Travellify/ContentView.swift` | switch on 3 AppDestination cases | Add `.activityList` branch → `ActivityListView(tripID:)` |
| `Travellify/Features/Trips/TripDetailView.swift` | Activities SectionCard static placeholder @ lines 38-43 | Wrap in `NavigationLink(value: .activityList(...))` + computed `activitiesMessage(for:)` |
| `Travellify/Models/SchemaV1.swift` | Activity already in models array (line 13) | No structural change — field additions to Activity are additive within V1 |

---

## Pattern Assignments

### `ActivityListView.swift` (screen, CRUD + trip-scoped @Query)

**Analog:** `Travellify/Features/Packing/PackingListView.swift`

**Init + trip-scoped @Query pattern** (PackingListView.swift lines 25–51):
```swift
struct PackingListView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [PackingCategory]

    init(tripID: PersistentIdentifier) {
        self.tripID = tripID
        _categories = Query(
            filter: #Predicate<PackingCategory> { cat in
                cat.trip?.persistentModelID == tripID
            },
            sort: \PackingCategory.sortOrder,
            order: .forward
        )
    }
```

For Activities, use multi-key `SortDescriptor` array per D42 tiebreak:
```swift
_activities = Query(
    filter: #Predicate<Activity> { a in a.trip?.persistentModelID == tripID },
    sort: [SortDescriptor(\Activity.startAt, order: .forward),
           SortDescriptor(\Activity.createdAt, order: .forward)]
)
```

**Trip lookup pattern** (PackingListView.swift line 285 — trip resolution inside mutation):
```swift
cat.trip = modelContext.model(for: tripID) as? Trip
```
Also seen in `TripDetailView.swift` line 13: `modelContext.model(for: tripID) as? Trip`.

**Toolbar + button pattern** (PackingListView.swift lines 178–188):
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button {
            newCategoryName = ""
            isAddingCategory = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("New Category")
    }
}
```

**List styling pattern** (PackingListView.swift lines 173–177):
```swift
.listStyle(.insetGrouped)
.listRowSpacing(8)
.scrollDismissesKeyboard(.immediately)
.navigationTitle("Packing")
.navigationBarTitleDisplayMode(.large)
```

**Swipe-to-delete destructive pattern** (PackingListView.swift lines 247–251):
```swift
.swipeActions(edge: .trailing, allowsFullSwipe: true) {
    Button(role: .destructive) { deleteItem(item) } label: {
        Label("Delete", systemImage: "trash")
    }
}
```

**Delete mutation + save pattern** (PackingListView.swift lines 97–100, 119–122):
```swift
private func deleteItem(_ item: PackingItem) {
    modelContext.delete(item)
    save("Couldn't delete item. Please try again.")
}

private func save(_ failureMessage: String) {
    do { try modelContext.save() }
    catch { errorMessage = failureMessage }
}
```

**Error alert surface pattern** (PackingListView.swift lines 203–214):
```swift
.alert(
    "Something went wrong",
    isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
    ),
    presenting: errorMessage
) { _ in
    Button("OK", role: .cancel) { errorMessage = nil }
} message: { msg in
    Text(msg)
}
```

**Empty-state gating pattern** (PackingListView.swift lines 158–171; alt: `DocumentListView.swift` lines 62–88 uses `Group { if empty ... else ... }`). For Activities prefer the `DocumentListView` shape so `ContentUnavailableView` can fill the screen rather than sit in a list row.

**Preview pattern — in-memory container** (PackingListView.swift lines 388–401):
```swift
let container = try! ModelContainer(
    for: Trip.self, Destination.self, Document.self,
         PackingItem.self, PackingCategory.self, Activity.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
)
let trip = Trip()
trip.name = "Empty trip"
container.mainContext.insert(trip)
```

---

### `ActivityEditSheet.swift` (sheet, form request-response)

**Analog:** `Travellify/Features/Trips/TripEditSheet.swift`

**Mode enum + init pattern** (TripEditSheet.swift lines 4–10):
```swift
enum Mode {
    case create
    case edit(Trip)
}
let mode: Mode
```
For Activities, CONTEXT D43 mandates `init(activity: Activity?, trip: Trip)` (nil = create). Either keep an internal `Mode` enum or drop it and branch on `activity == nil`. Either works; Mode matches the established precedent.

**Environment + local draft state** (TripEditSheet.swift lines 12–20):
```swift
@Environment(\.dismiss) private var dismiss
@Environment(\.modelContext) private var modelContext

@State private var name: String = ""
@State private var startDate: Date = Calendar.current.startOfDay(for: Date())
@State private var endDate: Date = Calendar.current.startOfDay(for: Date())
@State private var destinations: [DestinationDraft] = []
@State private var didLoadInitialValues = false
```

**NavigationStack + Form + toolbar skeleton** (TripEditSheet.swift lines 47–96):
```swift
var body: some View {
    NavigationStack {
        Form {
            Section("Trip") {
                TextField("Trip name", text: $name)
                    .textInputAutocapitalization(.words)
            }
            Section("Dates") {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                if showEndDateError {
                    Text("End date must be on or after the start date.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            // ...
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(confirmButtonTitle) { save() }
                    .disabled(!isValid)
            }
        }
        .onAppear(perform: loadInitialValuesIfNeeded)
    }
}
```
Activities use `DatePicker("Starts", selection: $startAt, displayedComponents: [.date, .hourAndMinute]).datePickerStyle(.compact)` per D43. The soft-warn row (D41) mirrors the `showEndDateError` Text pattern above (inline in the same Section).

**Guarded initial-value load for edit mode** (TripEditSheet.swift lines 98–110):
```swift
private func loadInitialValuesIfNeeded() {
    guard !didLoadInitialValues else { return }
    didLoadInitialValues = true
    if case .edit(let trip) = mode {
        name = trip.name
        startDate = trip.startDate
        endDate = trip.endDate
        // ...
    }
}
```

**Save branching + dismiss** (TripEditSheet.swift lines 112–148):
```swift
private func save() {
    let normalizedStart = Calendar.current.startOfDay(for: startDate)
    // ...
    switch mode {
    case .create:
        let trip = Trip()
        trip.name = trimmedName.isEmpty ? "Untitled Trip" : trimmedName
        trip.startDate = normalizedStart
        modelContext.insert(trip)
        // ...
    case .edit(let trip):
        trip.name = trimmedName.isEmpty ? "Untitled Trip" : trimmedName
        trip.startDate = normalizedStart
        // ...
    }
    do { try modelContext.save() }
    catch { assertionFailure("modelContext.save failed: \(error)") }
    dismiss()
}
```
For Activities: in `.create`, instantiate `Activity()`, set `.trip = trip`, set `.startAt = <default from D44>`, `modelContext.insert(activity)`, then assign edited fields. D43 disallows a delete button in the sheet — delete is list-only.

**Save-disabled guard** (TripEditSheet.swift lines 21–27):
```swift
private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
private var isValid: Bool { endDate >= startDate }
```
Activities: `Save` disabled when `title.trimmingCharacters(in: .whitespaces).isEmpty`.

---

### `ActivityRow.swift` (row cell, read-only display)

**Analog (layout):** `Travellify/Features/Packing/PackingRow.swift`

**HStack + accessibility pattern** (PackingRow.swift lines 13–49):
```swift
var body: some View {
    HStack(spacing: 12) {
        // leading glyph / control
        // text content
        Text(item.name)
            .font(.body)
            .foregroundStyle(item.isChecked ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(item.isChecked ? "\(item.name), packed" : item.name)
}
```

**Analog (date formatting inside row):** `Travellify/Features/Documents/DocumentRow.swift` lines 11–13:
```swift
private var importedDateText: String {
    document.importedAt.formatted(.dateTime.year().month().day())
}
```
Activities should prefer a cached `DateFormatter` static (in `ActivityDateLabels`) over per-call `Date.formatted(...)` for the time label, to avoid repeat allocation in a day-grouped list.

**Activity row target shape:**
- Leading: time text (e.g. `2:30 pm`) in monospaced-digit secondary style
- Center: title (primary) + optional location line (secondary, smaller)
- No trailing chevron (row is tap-to-edit → triggers sheet; matches PackingRow's tap-to-edit)

---

### `ActivityDayHeader.swift` (section header)

**Analog:** `Travellify/Features/Packing/CategoryHeader.swift`

**Header layout + accessibility** (CategoryHeader.swift lines 12–30):
```swift
var body: some View {
    HStack {
        Text(category.name)
            .font(.headline)
            .foregroundStyle(.primary)
        Spacer()
        Text("\(checkedCount)/\(totalCount)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(category.name), \(checkedCount) of \(totalCount) packed")
}
```

For `ActivityDayHeader`:
- Input: `let day: Date`
- Body HStack: `Text(ActivityDateLabels.dayLabel(for: day, now: Date()))` (`.headline`, primary) + Spacer + optional activity count `.subheadline` secondary.
- No context menu (no rename/delete on day headers).

---

### `EmptyActivitiesView.swift` (empty state)

**Analog:** `Travellify/Features/Packing/EmptyPackingListView.swift`

**Full body — copy exactly, substitute strings + symbol** (EmptyPackingListView.swift lines 3–24):
```swift
struct EmptyPackingListView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            Text("No Categories Yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)
            Text("Tap + in the top right to add your first category.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No categories yet. Tap plus in the top right to add your first category.")
    }
}
```

For Activities (per D48): symbol `"calendar.badge.plus"`, title `"No activities yet"`, message `"Tap + in the top right to add your first activity."`. RESEARCH suggests `ContentUnavailableView` is the iOS 17 idiom, but the codebase precedent is a custom VStack — planner should match the codebase precedent for consistency unless explicitly flipped.

Also cf. `EmptyDocumentsView.swift` — identical structure with `"doc.text"` symbol.

---

### `ActivityDateLabels.swift` (pure utility, stateless transform)

**Analog:** `Travellify/Features/Trips/TripPartition.swift`

**Full file — pure-static + now-injection pattern** (TripPartition.swift lines 1–17):
```swift
import Foundation

enum TripPartition {
    static func upcoming(from trips: [Trip], now: Date = Date()) -> [Trip] {
        let today = Calendar.current.startOfDay(for: now)
        return trips
            .filter { $0.endDate >= today }
            .sorted { $0.startDate < $1.startDate }
    }

    static func past(from trips: [Trip], now: Date = Date()) -> [Trip] {
        let today = Calendar.current.startOfDay(for: now)
        return trips
            .filter { $0.endDate < today }
            .sorted { $0.startDate > $1.startDate }
    }
}
```

Apply the same shape to `ActivityDateLabels` — `enum` namespace, `static func`, `now: Date = Date()` and `calendar: Calendar = .current` defaults so tests can inject fixed values. Candidate signatures:
- `static func dayLabel(for day: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String`
- `static func timeLabel(for date: Date, locale: Locale = .current) -> String`
- `static func nextTopOfHour(after date: Date, calendar: Calendar = .current) -> Date`
- `static func defaultStartAt(for trip: Trip, now: Date = Date(), calendar: Calendar = .current) -> Date`  (implements D44)
- `static func activitiesMessage(for trip: Trip, now: Date = Date(), calendar: Calendar = .current) -> String`  (implements D46)

Cached `DateFormatter` statics live as `private static let` on the enum (see RESEARCH §Pattern 3).

---

### `ActivityTests.swift`

**Analog:** `TravellifyTests/PackingTests.swift`

**Test struct + container helper** (PackingTests.swift lines 1–28):
```swift
import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct PackingTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            configurations: config
        )
    }

    private func makeTrip(in context: ModelContext) -> Trip {
        let trip = Trip()
        trip.name = "Rome 2026"
        trip.startDate = Date()
        trip.endDate = Date().addingTimeInterval(86_400 * 5)
        context.insert(trip)
        return trip
    }
```

**Defaults test pattern** (PackingTests.swift lines 31–43):
```swift
@Test func packingCategoryDefaults() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let cat = PackingCategory()
    context.insert(cat)
    try context.save()
    #expect(cat.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
    #expect(cat.name == "")
    #expect(cat.sortOrder == 0)
    #expect(cat.trip == nil)
    #expect((cat.items ?? []).isEmpty)
}
```

**Cascade delete test pattern** (PackingTests.swift lines 122–166):
```swift
@Test func deleteTripCascadesToCategoriesAndItemsTwoLevel() throws {
    // ... seed trip + children
    context.delete(trip)
    try context.save()
    #expect(try context.fetch(FetchDescriptor<PackingCategory>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<PackingItem>()).isEmpty)
}
```

Apply the same structure for `activityDefaults`, `insertActivityRoundTrip`, `deleteTripCascadesToActivities`, `mutationPersistsAfterSave`.

---

### `ActivityGroupingTests.swift` / `DayLabelTests.swift` / `NextUpcomingTests.swift`

**Analog:** `TravellifyTests/PartitionTests.swift`

**Pure-function test pattern with fixed `now`** (PartitionTests.swift lines 28–37, 73–76):
```swift
@Test func upcomingIncludesTripEndingToday() throws {
    let today = Calendar.current.startOfDay(for: Date())
    let trip = makeTrip(name: "Ends Today", start: today.addingTimeInterval(-86400 * 3), end: today)
    try container.mainContext.save()

    let upcoming = TripPartition.upcoming(from: [trip], now: Date())
    #expect(upcoming.contains { $0.name == "Ends Today" })
}

@Test func emptyInputProducesEmptyOutput() {
    #expect(TripPartition.upcoming(from: []).isEmpty)
    #expect(TripPartition.past(from: []).isEmpty)
}
```

Pass a fixed `now` + `Calendar(identifier: .gregorian)` + `Locale(identifier: "en_US_POSIX")` to all `ActivityDateLabels.*` calls in tests to make assertions locale/timezone deterministic.

---

### `Activity.swift` (MODIFIED)

**Current file — full contents:**
```swift
import SwiftData
import Foundation

extension TravellifySchemaV1 {
    @Model
    final class Activity {
        var id: UUID = UUID()
        var trip: Trip?

        init() {}
    }
}
```

**Reference pattern — additive field expansion** (the precedent set by `Document.swift` lines 11–29):
```swift
@Model
final class Document {
    var id: UUID = UUID()
    var trip: Trip?

    // Phase 2 additions (D10) — every stored property has a default to enable
    // SwiftData lightweight migration on the existing SchemaV1 store.
    var displayName: String = ""
    var fileRelativePath: String = ""
    var kindRaw: String = DocumentKind.pdf.rawValue
    var importedAt: Date = Date()

    init() {}
}
```

Per D40, target shape:
```swift
var id: UUID = UUID()
var trip: Trip?
var title: String = ""
var startAt: Date = Date()
var location: String?
var notes: String?
var createdAt: Date = Date()
```
Rules from CLAUDE.md: UUID default, optional inverse (`trip: Trip?`), no `@Attribute(.unique)`, no `@Attribute(.externalStorage)`. Optional scalars (`location`, `notes`) declared as `String?` with no default (matches `Trip.destinations: [Destination]? = []` pattern of optional-with-default and `Document.trip: Trip?` optional-no-default).

---

### `AppDestination.swift` (MODIFIED)

**Current file — full contents:**
```swift
import Foundation
import SwiftData

enum AppDestination: Hashable {
    case tripDetail(PersistentIdentifier)
    case documentList(PersistentIdentifier)
    case packingList(PersistentIdentifier)
}
```

Add one line: `case activityList(PersistentIdentifier)`.

---

### `ContentView.swift` (MODIFIED)

**Current navigationDestination switch** (ContentView.swift lines 10–19):
```swift
.navigationDestination(for: AppDestination.self) { dest in
    switch dest {
    case .tripDetail(let id):
        TripDetailView(tripID: id)
    case .documentList(let id):
        DocumentListView(tripID: id)
    case .packingList(let id):
        PackingListView(tripID: id)
    }
}
```

Add `case .activityList(let id): ActivityListView(tripID: id)`. No other changes; `ActivityListView` resolves its own trip via `modelContext.model(for:)` per the PackingListView precedent.

---

### `TripDetailView.swift` (MODIFIED)

**Current Activities placeholder** (TripDetailView.swift lines 38–43):
```swift
SectionCard(
    title: "Activities",
    systemImage: "calendar",
    message: "Your itinerary will appear here.",
    minHeight: 220
)
```

**Replacement pattern — mirror `packingCard(for:)`** (TripDetailView.swift lines 81–106):
```swift
private func packingMessage(for trip: Trip) -> String {
    let categories = trip.packingCategories ?? []
    let totalItems = categories.flatMap { $0.items ?? [] }.count
    let checkedItems = categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
    if categories.isEmpty {
        return "No packing list yet"
    } else if checkedItems == totalItems && totalItems > 0 {
        return "All \(totalItems) item\(totalItems == 1 ? "" : "s") packed"
    } else if checkedItems == 0 {
        return "\(totalItems) item\(totalItems == 1 ? "" : "s"), none packed"
    } else {
        return "\(checkedItems) / \(totalItems) packed"
    }
}

@ViewBuilder
private func packingCard(for trip: Trip) -> some View {
    NavigationLink(value: AppDestination.packingList(trip.persistentModelID)) {
        SectionCard(
            title: "Packing",
            systemImage: "checklist",
            message: packingMessage(for: trip)
        )
    }
    .buttonStyle(.plain)
}
```

Apply D46 logic via a pure `ActivityDateLabels.activitiesMessage(for:now:calendar:)` helper so the view stays thin. Call site:
```swift
@ViewBuilder
private func activitiesCard(for trip: Trip) -> some View {
    NavigationLink(value: AppDestination.activityList(trip.persistentModelID)) {
        SectionCard(
            title: "Activities",
            systemImage: "calendar",
            message: ActivityDateLabels.activitiesMessage(for: trip),
            minHeight: 220
        )
    }
    .buttonStyle(.plain)
}
```
Replace the bare `SectionCard(...)` at lines 38–43 with `activitiesCard(for: trip)`.

**Also note** `documentsCard(for:)` (TripDetailView.swift lines 62–79) uses `secondaryMessage:` — Activities card does not need that field per D46 (single line).

---

### `SchemaV1.swift` (MODIFIED — no structural change)

**Current state — Activity already registered** (SchemaV1.swift lines 6–15):
```swift
static var models: [any PersistentModel.Type] {
    [
        TravellifySchemaV1.Trip.self,
        TravellifySchemaV1.Destination.self,
        TravellifySchemaV1.Document.self,
        TravellifySchemaV1.PackingItem.self,
        TravellifySchemaV1.PackingCategory.self,
        TravellifySchemaV1.Activity.self,
    ]
}
```
No edit needed here. Field additions to `Activity` are additive within V1 (precedent: Phase 2 Document field expansion did not bump to V2). `SchemaTests.schemaV1HasSixModels` (SchemaTests.swift line 18) already expects 6 models — no test change needed.

---

## Shared Patterns

### SwiftData save-or-alert

**Source:** `Travellify/Features/Packing/PackingListView.swift` lines 119–122
**Apply to:** `ActivityListView`, `ActivityEditSheet`

```swift
private func save(_ failureMessage: String) {
    do { try modelContext.save() }
    catch { errorMessage = failureMessage }
}
```
Pair with the error alert view modifier (PackingListView.swift lines 203–214) for user-facing surface.

### Trip resolution from `tripID`

**Source:** `Travellify/Features/Trips/TripDetailView.swift` lines 12–14
**Apply to:** `ActivityListView`, anywhere a `PersistentIdentifier` needs a live `Trip`

```swift
private var trip: Trip? {
    modelContext.model(for: tripID) as? Trip
}
```
Also see `DocumentListView.swift` lines 46–48 (identical shape) and `PackingListView.swift` line 285 (inline variant during mutation).

### In-memory `ModelContainer` for tests + previews

**Source:** `TravellifyTests/PackingTests.swift` lines 11–18, `PackingListView.swift` lines 389–393
**Apply to:** All new test files + all Activities previews

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(
    for: Trip.self, Destination.self, Document.self,
         PackingItem.self, PackingCategory.self, Activity.self,
    configurations: config
)
```
Note: the type list includes all six SchemaV1 models. Keep this list in sync — do not trim to only the types the test touches (PackingTests does not touch Activity yet still lists it).

### Pure-function + now injection for test determinism

**Source:** `Travellify/Features/Trips/TripPartition.swift` + `TravellifyTests/PartitionTests.swift`
**Apply to:** `ActivityDateLabels.swift` and all its tests.
- Default `now: Date = Date()` at call-site, override with fixed value in tests.
- Use `Calendar(identifier: .gregorian)` + `Locale(identifier: "en_US_POSIX")` in test invocations for cross-timezone determinism.

### SwiftData cascade via `@Relationship(deleteRule:inverse:)`

**Source:** `Travellify/Models/Trip.swift` lines 15–25
**Apply to:** No new code — Activity cascade is already declared on Trip (line 24). Just verify in `ActivityTests.deleteTripCascadesToActivities`.

---

## No Analog Found

None — every new file has a close analog in the codebase.

## Metadata

**Analog search scope:** `Travellify/`, `TravellifyTests/`
**Files scanned (read in full or relevant ranges):** PackingListView.swift, PackingRow.swift, EmptyPackingListView.swift, CategoryHeader.swift, TripEditSheet.swift, TripDetailView.swift, TripPartition.swift, DocumentListView.swift, DocumentRow.swift, EmptyDocumentsView.swift, Activity.swift, Trip.swift, Document.swift, PackingItem.swift, SchemaV1.swift, AppDestination.swift, ContentView.swift, PackingTests.swift, PartitionTests.swift, SchemaTests.swift, PackingProgressTests.swift
**Pattern extraction date:** 2026-04-21
