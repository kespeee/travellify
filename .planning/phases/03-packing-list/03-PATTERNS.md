# Phase 3: Packing List — Pattern Map

**Mapped:** 2026-04-21
**Files analyzed:** 12 (new/modified)
**Analogs found:** 11 / 12

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Travellify/Models/PackingCategory.swift` | model | CRUD | `Travellify/Models/Document.swift` | exact |
| `Travellify/Models/PackingItem.swift` _(replace placeholder)_ | model | CRUD | `Travellify/Models/Document.swift` | exact |
| `Travellify/Models/Trip.swift` _(add `packingCategories`)_ | model | CRUD | `Travellify/Models/Trip.swift` lines 15-22 | exact |
| `Travellify/Models/SchemaV1.swift` _(add PackingCategory.self + typealias)_ | config | CRUD | `Travellify/Models/SchemaV1.swift` | exact |
| `Travellify/App/TravellifyApp.swift` _(add PackingCategory.self to ModelContainer)_ | config | CRUD | `Travellify/App/TravellifyApp.swift` | exact |
| `Travellify/App/AppDestination.swift` _(add `.packingList` case)_ | config | request-response | `Travellify/App/AppDestination.swift` | exact |
| `Travellify/Features/Packing/PackingListView.swift` | component | CRUD | `Travellify/Features/Documents/DocumentListView.swift` | exact |
| `Travellify/Features/Packing/PackingRow.swift` | component | event-driven | `Travellify/Features/Documents/DocumentRow.swift` | role-match |
| `Travellify/Features/Packing/CategoryHeader.swift` | component | event-driven | `Travellify/Features/Documents/DocumentRow.swift` | role-match |
| `Travellify/Features/Packing/PackingProgressRow.swift` | component | transform | `Travellify/Features/Documents/DocumentRow.swift` | partial |
| `Travellify/Features/Packing/EmptyPackingListView.swift` | component | request-response | `Travellify/Features/Documents/EmptyDocumentsView.swift` | exact |
| `Travellify/Features/Trips/TripDetailView.swift` _(wire Packing card)_ | component | request-response | `Travellify/Features/Trips/TripDetailView.swift` lines 66-83 | exact |
| `Travellify/Shared/PreviewContainer.swift` _(add PackingCategory seeds)_ | config | CRUD | `Travellify/Shared/PreviewContainer.swift` | exact |
| `TravellifyTests/PackingTests.swift` | test | CRUD | `TravellifyTests/DocumentTests.swift` | exact |
| `TravellifyTests/PackingProgressTests.swift` | test | transform | `TravellifyTests/DocumentTests.swift` | role-match |
| `TravellifyTests/SchemaTests.swift` _(update count 5→6)_ | test | CRUD | `TravellifyTests/SchemaTests.swift` | exact |
| `TravellifyTests/TripTests.swift` _(rewrite cascade test)_ | test | CRUD | `TravellifyTests/TripTests.swift` lines 78-101 | exact |

---

## Pattern Assignments

### `Travellify/Models/PackingCategory.swift` (model, CRUD)

**Analog:** `Travellify/Models/Document.swift`

**Imports pattern** (Document.swift lines 1-3):
```swift
import SwiftData
import Foundation
```

**Core @Model pattern** (Document.swift lines 9-30):
```swift
extension TravellifySchemaV1 {
    @Model
    final class Document {
        var id: UUID = UUID()
        var trip: Trip?

        // All stored properties have defaults (CloudKit-safe per CLAUDE.md)
        var displayName: String = ""
        var fileRelativePath: String = ""
        var kindRaw: String = DocumentKind.pdf.rawValue
        var importedAt: Date = Date()

        init() {}
    }
}
```

**PackingCategory shape to produce** (from CONTEXT.md D19):
```swift
extension TravellifySchemaV1 {
    @Model
    final class PackingCategory {
        var id: UUID = UUID()
        var name: String = ""
        var sortOrder: Int = 0
        var trip: Trip?                                     // CloudKit-safe optional inverse

        @Relationship(deleteRule: .cascade, inverse: \PackingItem.category)
        var items: [PackingItem]? = []

        init() {}
    }
}
```

**Cascade relationship pattern** (Trip.swift lines 15-18):
```swift
@Relationship(deleteRule: .cascade, inverse: \Destination.trip)
var destinations: [Destination]? = []
```

---

### `Travellify/Models/PackingItem.swift` — replace placeholder (model, CRUD)

**Analog:** `Travellify/Models/Document.swift`

**Current placeholder** (PackingItem.swift lines 1-12) — replace entirely:
```swift
import SwiftData
import Foundation

extension TravellifySchemaV1 {
    @Model
    final class PackingItem {
        var id: UUID = UUID()
        var trip: Trip?           // <-- REMOVE: D20 removes direct trip link

        init() {}
    }
}
```

**Replacement shape** (from CONTEXT.md D20):
```swift
import SwiftData
import Foundation

extension TravellifySchemaV1 {
    @Model
    final class PackingItem {
        var id: UUID = UUID()
        var name: String = ""
        var isChecked: Bool = false
        var sortOrder: Int = 0
        var category: PackingCategory?                      // CloudKit-safe optional inverse

        init() {}
    }
}
```

**CloudKit safety rules to obey** (CLAUDE.md):
- Every property has a default value — no property can be non-optional without a default.
- No `@Attribute(.unique)` anywhere.
- All inverse relationships are optional.

---

### `Travellify/Models/Trip.swift` — add `packingCategories` (model, CRUD)

**Analog:** `Travellify/Models/Trip.swift` lines 15-22

**Existing cascade relationship pattern to copy** (Trip.swift lines 15-22):
```swift
// CASCADE — child records deleted when trip is deleted
@Relationship(deleteRule: .cascade, inverse: \Destination.trip)
var destinations: [Destination]? = []

@Relationship(deleteRule: .cascade, inverse: \Document.trip)
var documents: [Document]? = []
```

**Change to make:**
1. Remove `@Relationship(deleteRule: .cascade, inverse: \PackingItem.trip) var packingItems: [PackingItem]? = []` (line 22-23).
2. Add `@Relationship(deleteRule: .cascade, inverse: \PackingCategory.trip) var packingCategories: [PackingCategory]? = []` in its place.

---

### `Travellify/Models/SchemaV1.swift` — add PackingCategory (config, CRUD)

**Analog:** `Travellify/Models/SchemaV1.swift`

**Current models array** (SchemaV1.swift lines 6-14):
```swift
static var models: [any PersistentModel.Type] {
    [
        TravellifySchemaV1.Trip.self,
        TravellifySchemaV1.Destination.self,
        TravellifySchemaV1.Document.self,
        TravellifySchemaV1.PackingItem.self,
        TravellifySchemaV1.Activity.self,
    ]
}
```

**Changes to make:**
```swift
static var models: [any PersistentModel.Type] {
    [
        TravellifySchemaV1.Trip.self,
        TravellifySchemaV1.Destination.self,
        TravellifySchemaV1.Document.self,
        TravellifySchemaV1.PackingItem.self,
        TravellifySchemaV1.PackingCategory.self,  // NEW
        TravellifySchemaV1.Activity.self,
    ]
}
```

**Typealias pattern** (SchemaV1.swift lines 23-27):
```swift
typealias Trip        = TravellifySchemaV1.Trip
typealias Destination = TravellifySchemaV1.Destination
typealias Document    = TravellifySchemaV1.Document
typealias PackingItem = TravellifySchemaV1.PackingItem
typealias Activity    = TravellifySchemaV1.Activity
// Add:
typealias PackingCategory = TravellifySchemaV1.PackingCategory  // NEW
```

---

### `Travellify/App/TravellifyApp.swift` — add PackingCategory to ModelContainer (config, CRUD)

**Analog:** `Travellify/App/TravellifyApp.swift` lines 10-15

**Current ModelContainer init** (TravellifyApp.swift lines 10-14):
```swift
container = try ModelContainer(
    for: Trip.self, Destination.self, Document.self,
         PackingItem.self, Activity.self,
    migrationPlan: TravellifyMigrationPlan.self
)
```

**Updated pattern:**
```swift
container = try ModelContainer(
    for: Trip.self, Destination.self, Document.self,
         PackingItem.self, PackingCategory.self, Activity.self,  // PackingCategory added
    migrationPlan: TravellifyMigrationPlan.self
)
```

**Note:** The same `PackingCategory.self` addition must also be applied to:
- `Travellify/Shared/PreviewContainer.swift` (lines 9-12)
- Every `ModelContainer` init in test structs (`TripTests.swift` line 12-15, `SchemaTests.swift` line 9-13, `DocumentTests.swift` line 13-16, new `PackingTests.swift`, new `PackingProgressTests.swift`)

---

### `Travellify/App/AppDestination.swift` — add `.packingList` (config, request-response)

**Analog:** `Travellify/App/AppDestination.swift` lines 1-7

**Current enum** (AppDestination.swift lines 1-7):
```swift
import Foundation
import SwiftData

enum AppDestination: Hashable {
    case tripDetail(PersistentIdentifier)
    case documentList(PersistentIdentifier)
}
```

**Change to make** (mirrors Phase 2 `documentList` addition):
```swift
enum AppDestination: Hashable {
    case tripDetail(PersistentIdentifier)
    case documentList(PersistentIdentifier)
    case packingList(PersistentIdentifier)        // NEW
}
```

---

### `Travellify/Features/Packing/PackingListView.swift` (component, CRUD)

**Analog:** `Travellify/Features/Documents/DocumentListView.swift`

**Imports pattern** (DocumentListView.swift lines 1-5):
```swift
import SwiftUI
import SwiftData
import OSLog
```
_(Drop PhotosUI — not needed for packing)_

**State properties pattern** (DocumentListView.swift lines 8-28):
```swift
struct PackingListView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [PackingCategory]

    // Presentation state — replicate this pattern for packing-specific state
    @State private var isAddingCategory = false
    @State private var newCategoryName: String = ""
    @State private var pendingRenameCategory: PackingCategory?
    @State private var renameCategoryDraft: String = ""
    @State private var pendingDeleteCategory: PackingCategory?

    // Focus state — two independent domains per CONTEXT.md D30/D31
    @FocusState private var addItemFocus: PersistentIdentifier?
    @FocusState private var renameItemFocus: PersistentIdentifier?
    @State private var newItemNames: [PersistentIdentifier: String] = [:]
    @State private var renameDrafts: [PersistentIdentifier: String] = [:]

    // Error alert — single shared surface (mirrors DocumentListView line 29)
    @State private var errorMessage: String?
```

**`@Query` init pattern** (DocumentListView.swift lines 35-44):
```swift
init(tripID: PersistentIdentifier) {
    self.tripID = tripID
    _documents = Query(
        filter: #Predicate<Document> { doc in
            doc.trip?.persistentModelID == tripID
        },
        sort: \Document.importedAt,
        order: .reverse
    )
}
```
_Adapt for PackingCategory:_
```swift
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

**Empty-state branch pattern** (DocumentListView.swift lines 63-66):
```swift
var body: some View {
    Group {
        if documents.isEmpty {
            EmptyDocumentsView()
        } else {
            // ... list content
        }
    }
    .navigationTitle("Documents")
    .navigationBarTitleDisplayMode(.large)
```

**Rename alert pattern** (DocumentListView.swift lines 161-192):
```swift
.alert(
    "Rename Document",
    isPresented: Binding(
        get: { docPendingRename != nil },
        set: { if !$0 { docPendingRename = nil; renameDraft = "" } }
    ),
    presenting: docPendingRename
) { _ in
    TextField("Name", text: $renameDraft)
    Button("Save") {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let doc = docPendingRename else {
            docPendingRename = nil
            renameDraft = ""
            return
        }
        doc.displayName = trimmed
        do {
            try modelContext.save()
        } catch {
            importErrorMessage = "Couldn't rename. Please try again."
        }
        docPendingRename = nil
        renameDraft = ""
    }
    .disabled(renameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
    Button("Cancel", role: .cancel) {
        docPendingRename = nil
        renameDraft = ""
    }
}
```
_Same pattern for category rename alert and new-category alert._

**Error alert pattern** (DocumentListView.swift lines 223-235):
```swift
.alert(
    "Something went wrong",
    isPresented: Binding(
        get: { importErrorMessage != nil },
        set: { if !$0 { importErrorMessage = nil } }
    ),
    presenting: importErrorMessage
) { _ in
    Button("OK", role: .cancel) { importErrorMessage = nil }
} message: { msg in
    Text(msg)
}
```

**Delete confirm pattern** (DocumentListView.swift lines 194-222):
```swift
.alert(
    docPendingDelete.map { "Delete \"\($0.displayName)\"?" } ?? "Delete document?",
    isPresented: Binding(
        get: { docPendingDelete != nil },
        set: { if !$0 { docPendingDelete = nil } }
    ),
    presenting: docPendingDelete
) { _ in
    Button("Delete", role: .destructive) {
        guard let doc = docPendingDelete else { docPendingDelete = nil; return }
        modelContext.delete(doc)
        do {
            try modelContext.save()
        } catch {
            importErrorMessage = "Couldn't delete. Please try again."
        }
        docPendingDelete = nil
    }
    Button("Cancel", role: .cancel) { docPendingDelete = nil }
} message: { _ in
    Text("This removes the file from your device and cannot be undone.")
}
```
_For category delete, use `.confirmationDialog` (not `.alert`) per D35/D36. The pattern for presenting/dismissing state is the same._

**Preview block pattern** (DocumentListView.swift lines 239-272):
```swift
#if DEBUG
#Preview("Empty") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self, PackingItem.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let trip = Trip()
    trip.name = "Empty trip"
    container.mainContext.insert(trip)
    return NavigationStack {
        DocumentListView(tripID: trip.persistentModelID)
    }
    .modelContainer(container)
}
#endif
```
_Add `PackingCategory.self` to the ModelContainer `for:` list in the preview._

---

### `Travellify/Features/Packing/PackingRow.swift` (component, event-driven)

**Analog:** `Travellify/Features/Documents/DocumentRow.swift`

**Imports + struct shell pattern** (DocumentRow.swift lines 1-4):
```swift
import SwiftUI
import SwiftData

struct DocumentRow: View {
    let document: Document
```

**`contentShape` for full-width tap target** (DocumentRow.swift line 27):
```swift
.contentShape(Rectangle())
```
_Required on the HStack body so single-tap enters rename mode across the full row width._

**Accessibility pattern** (DocumentRow.swift lines 28-29):
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(document.displayName), \(kindAccessibilityWord), imported \(importedDateText)")
```

**Preview with inline model construction** (DocumentRow.swift lines 33-46):
```swift
#if DEBUG
#Preview {
    DocumentRow(document: {
        let d = Document()
        d.displayName = "Passport Scan"
        d.kind = .pdf
        d.importedAt = Date()
        return d
    }())
    .padding()
    .frame(width: 180)
    .modelContainer(previewContainer)
}
#endif
```

**Swipe actions shape** (from RESEARCH.md Pattern 3):
```swift
// In PackingListView body, applied to each PackingRow:
PackingRow(item: item)
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
        Button {
            item.isChecked.toggle()
            try? modelContext.save()
        } label: {
            Label(item.isChecked ? "Unpack" : "Pack", systemImage: "checkmark")
        }
        .tint(.green)
        .accessibilityLabel(item.isChecked ? "Mark as unpacked" : "Mark as packed")
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) {
            deleteItem(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .accessibilityLabel("Delete \(item.name)")
    }
    .sensoryFeedback(.success, trigger: item.isChecked)
```

---

### `Travellify/Features/Packing/CategoryHeader.swift` (component, event-driven)

**Analog:** `Travellify/Features/Documents/DocumentRow.swift` (same HStack-with-contentShape structure)

**contentShape pattern** (DocumentRow.swift line 27):
```swift
.contentShape(Rectangle())
```
_Required on the CategoryHeader HStack so the full-width row triggers `.contextMenu` on long-press._

**contextMenu pattern** (DocumentListView.swift lines 73-81 — per-document context menu, same structure):
```swift
.contextMenu {
    Button {
        docPendingRename = doc
        renameDraft = doc.displayName
    } label: { Label("Rename", systemImage: "pencil") }

    Button(role: .destructive) {
        docPendingDelete = doc
    } label: { Label("Delete", systemImage: "trash") }
}
```
_CategoryHeader uses the same `.contextMenu` shape but on the section header HStack instead of a grid cell. Rename sets `pendingRenameCategory`; Delete sets `pendingDeleteCategory`._

**Section header shape** (from RESEARCH.md Pattern 5):
```swift
HStack {
    Text(category.name).font(.headline)
    Spacer()
    Text("\(checkedCount)/\(totalCount)").font(.subheadline).foregroundStyle(.secondary)
}
.contentShape(Rectangle())
.contextMenu {
    Button { onRename() } label: { Label("Rename", systemImage: "pencil") }
    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
}
.accessibilityHint("Long press for rename and delete options")
```

---

### `Travellify/Features/Packing/PackingProgressRow.swift` (component, transform)

**Analog:** No direct match — progress view rows do not exist in Phase 1 or Phase 2. However the structural shape mirrors the empty-state VStack pattern.

**Closest structural pattern** (EmptyDocumentsView.swift lines 3-22):
```swift
struct EmptyDocumentsView: View {
    var body: some View {
        VStack(spacing: 0) {
            // icon
            // title
            // body text
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("...")
    }
}
```

**ProgressRow shape** (from RESEARCH.md Pattern 6 + UI-SPEC):
```swift
struct PackingProgressRow: View {
    let checkedCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(checkedCount) / \(totalCount) packed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(
                value: Double(checkedCount),
                total: Double(max(totalCount, 1))
            )
            .progressViewStyle(.linear)
            .tint(.accentColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(checkedCount) of \(totalCount) items packed")
        .accessibilityValue(totalCount > 0 ? "\(Int(Double(checkedCount) / Double(totalCount) * 100))%" : "0%")
    }
}
```

---

### `Travellify/Features/Packing/EmptyPackingListView.swift` (component, request-response)

**Analog:** `Travellify/Features/Documents/EmptyDocumentsView.swift` (exact match)

**Full analog** (EmptyDocumentsView.swift lines 1-30):
```swift
import SwiftUI

struct EmptyDocumentsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            Text("No Documents Yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)
            Text("Tap + to scan, pick a photo, or import a file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No documents yet. Tap plus to scan, pick a photo, or import a file.")
    }
}
```

**Adapt for packing** per UI-SPEC:
- `systemName`: `"doc.text"` → `"checklist"`
- Title: `"No Documents Yet"` → `"No Categories Yet"`
- Body: `"Tap + to scan…"` → `"Tap \"Add category\" below to start building your packing list."`
- Combined accessibility label: `"No categories yet. Tap Add category below to start building your packing list."`
- Layout structure: identical (VStack spacing 0, `.padding(.bottom, 32)` after icon, `.padding(.bottom, 8)` after title, `.padding(.horizontal, 32)`, `.frame(maxWidth: .infinity, maxHeight: .infinity)`)

---

### `Travellify/Features/Trips/TripDetailView.swift` — wire Packing card (component, request-response)

**Analog:** `Travellify/Features/Trips/TripDetailView.swift` lines 66-83 (`documentsCard`)

**documentsCard pattern to copy** (TripDetailView.swift lines 67-83):
```swift
@ViewBuilder
private func documentsCard(for trip: Trip) -> some View {
    let docs = trip.documents ?? []
    let count = docs.count
    let primary: String = count == 0 ? "No documents yet" : (count == 1 ? "1 document" : "\(count) documents")
    let latest: String? = count == 0
        ? nil
        : docs.max(by: { $0.importedAt < $1.importedAt })?.displayName
    NavigationLink(value: AppDestination.documentList(trip.persistentModelID)) {
        SectionCard(
            title: "Documents",
            systemImage: "doc.text",
            message: primary,
            secondaryMessage: latest
        )
    }
    .buttonStyle(.plain)
}
```

**PackingCard adaptation** (from RESEARCH.md Code Examples + UI-SPEC):
```swift
@ViewBuilder
private func packingCard(for trip: Trip) -> some View {
    let categories = trip.packingCategories ?? []
    let totalItems = categories.flatMap { $0.items ?? [] }.count
    let checkedItems = categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count

    let message: String
    if categories.isEmpty {
        message = "No packing list yet"
    } else if checkedItems == totalItems && totalItems > 0 {
        message = "All \(totalItems) item\(totalItems == 1 ? "" : "s") packed"
    } else if checkedItems == 0 {
        message = "\(totalItems) item\(totalItems == 1 ? "" : "s"), none packed"
    } else {
        message = "\(checkedItems) / \(totalItems) packed"
    }

    NavigationLink(value: AppDestination.packingList(trip.persistentModelID)) {
        SectionCard(
            title: "Packing",
            systemImage: "checklist",
            message: message
        )
    }
    .buttonStyle(.plain)
}
```

**Replace the placeholder** at TripDetailView.swift lines 35-39:
```swift
// BEFORE (placeholder):
SectionCard(
    title: "Packing",
    systemImage: "checklist",
    message: "Your packing list will appear here."
)
// AFTER:
packingCard(for: trip)
```

---

### `Travellify/Shared/PreviewContainer.swift` — add PackingCategory seeds (config, CRUD)

**Analog:** `Travellify/Shared/PreviewContainer.swift` lines 6-49

**Model seed pattern** (PreviewContainer.swift lines 20-25):
```swift
let dest1 = Destination(); dest1.name = "Rome"; dest1.sortIndex = 0; dest1.trip = rome
let dest2 = Destination(); dest2.name = "Florence"; dest2.sortIndex = 1; dest2.trip = rome
container.mainContext.insert(dest1)
container.mainContext.insert(dest2)
```

**PackingCategory seed to add** (append after existing seeds, before `try container.mainContext.save()`):
```swift
// Seed packing list for Rome trip (so PackingListView Xcode preview renders)
let cat1 = PackingCategory(); cat1.name = "Clothes"; cat1.sortOrder = 0; cat1.trip = rome
container.mainContext.insert(cat1)
let item1 = PackingItem(); item1.name = "T-shirts"; item1.sortOrder = 0; item1.category = cat1
let item2 = PackingItem(); item2.name = "Jeans"; item2.sortOrder = 1; item2.isChecked = true; item2.category = cat1
container.mainContext.insert(item1)
container.mainContext.insert(item2)

let cat2 = PackingCategory(); cat2.name = "Toiletries"; cat2.sortOrder = 1; cat2.trip = rome
container.mainContext.insert(cat2)
let item3 = PackingItem(); item3.name = "Toothbrush"; item3.sortOrder = 0; item3.category = cat2
container.mainContext.insert(item3)
```

**ModelContainer init update** (PreviewContainer.swift lines 8-12):
```swift
let container = try ModelContainer(
    for: Trip.self, Destination.self, Document.self,
         PackingItem.self, PackingCategory.self, Activity.self,  // PackingCategory added
    configurations: config
)
```

---

### `TravellifyTests/PackingTests.swift` (test, CRUD)

**Analog:** `TravellifyTests/DocumentTests.swift`

**Test struct shell + container init pattern** (DocumentTests.swift lines 7-17):
```swift
import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct DocumentTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, Activity.self,
            configurations: config
        )
    }

    private func makeTrip(in context: ModelContext) -> Trip {
        let trip = Trip()
        trip.name = "Test Trip"
        trip.startDate = Date()
        trip.endDate = Date()
        context.insert(trip)
        return trip
    }
```
_Use `@MainActor struct PackingTests` with `makeContainer()` helper that includes `PackingCategory.self`._

**Default fields test pattern** (DocumentTests.swift lines 38-45):
```swift
@Test func defaultFieldsAreSet() throws {
    let doc = Document()
    #expect(doc.displayName == "")
    #expect(doc.fileRelativePath == "")
    #expect(doc.kindRaw == DocumentKind.pdf.rawValue)
    let delta = abs(doc.importedAt.timeIntervalSinceNow)
    #expect(delta < 1.0, "importedAt should be within 1 second of now, got delta=\(delta)")
}
```

**Cascade test pattern** (TripTests.swift lines 52-76):
```swift
@Test func deleteTripCascadesToDestinations() throws {
    let context = container.mainContext
    let trip = Trip()
    // ...
    context.insert(trip)

    for i in 0..<3 {
        let dest = Destination()
        dest.trip = trip
        context.insert(dest)
    }
    try context.save()

    #expect(try context.fetch(FetchDescriptor<Destination>()).count == 3)

    context.delete(trip)
    try context.save()

    let destinations = try context.fetch(FetchDescriptor<Destination>())
    #expect(destinations.isEmpty, "Cascade delete must remove all destinations")
}
```

---

### `TravellifyTests/PackingProgressTests.swift` (test, transform)

**Analog:** `TravellifyTests/DocumentTests.swift` (test struct + container init structure)

**Pattern for computed-value tests:**
```swift
@Test func tripLevelProgress() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let trip = makeTrip(in: context)

    let cat = PackingCategory(); cat.name = "Test"; cat.sortOrder = 0; cat.trip = trip
    context.insert(cat)
    let item1 = PackingItem(); item1.name = "A"; item1.isChecked = false; item1.sortOrder = 0; item1.category = cat
    let item2 = PackingItem(); item2.name = "B"; item2.isChecked = true;  item2.sortOrder = 1; item2.category = cat
    context.insert(item1); context.insert(item2)
    try context.save()

    // Replicate the view's computed properties
    let categories = [cat]
    let total = categories.flatMap { $0.items ?? [] }.count
    let checked = categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
    #expect(total == 2)
    #expect(checked == 1)
}
```

---

### `TravellifyTests/SchemaTests.swift` — update count (test, CRUD)

**Analog:** `TravellifyTests/SchemaTests.swift` lines 18-20

**Current assertion to update** (SchemaTests.swift line 19):
```swift
@Test func schemaV1HasFiveModels() {
    #expect(TravellifySchemaV1.models.count == 5)
}
```

**Updated assertion:**
```swift
@Test func schemaV1HasSixModels() {
    #expect(TravellifySchemaV1.models.count == 6)
}
```

Also update `containerInitializesWithMigrationPlan` (SchemaTests.swift lines 9-15) to add `PackingCategory.self`:
```swift
container = try ModelContainer(
    for: Trip.self, Destination.self, Document.self,
         PackingItem.self, PackingCategory.self, Activity.self,
    migrationPlan: TravellifyMigrationPlan.self,
    configurations: config
)
```

---

### `TravellifyTests/TripTests.swift` — rewrite cascade test (test, CRUD)

**Analog:** `TravellifyTests/TripTests.swift` lines 78-101 (`deleteTripCascadesToPlaceholderModels`)

**Current test to rewrite** (TripTests.swift lines 78-101):
```swift
@Test func deleteTripCascadesToPlaceholderModels() throws {
    let context = container.mainContext
    let trip = Trip(); // ...
    context.insert(trip)

    let doc = Document(); doc.trip = trip; context.insert(doc)
    let pack = PackingItem(); pack.trip = trip; context.insert(pack)  // <-- BREAKS after D20
    let act = Activity(); act.trip = trip; context.insert(act)
    try context.save()
    // ...
}
```

**Rewritten test** (two-level cascade per D20, following TripTests.swift cascade pattern lines 52-76):
```swift
@Test func deleteTripCascadesToPackingModels() throws {
    let context = container.mainContext
    let trip = Trip()
    trip.name = "Cascade Test"
    trip.startDate = Date()
    trip.endDate = Date()
    context.insert(trip)

    let doc = Document(); doc.trip = trip; context.insert(doc)
    let act = Activity(); act.trip = trip; context.insert(act)

    // Two-level packing hierarchy (D20: items reach trip through category)
    let cat = PackingCategory(); cat.name = "Toiletries"; cat.sortOrder = 0; cat.trip = trip
    context.insert(cat)
    let item = PackingItem(); item.name = "Toothbrush"; item.sortOrder = 0; item.category = cat
    context.insert(item)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<Document>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<PackingCategory>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<PackingItem>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<Activity>()).count == 1)

    context.delete(trip)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<Document>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<PackingCategory>()).isEmpty, "Cascade delete must remove all categories")
    #expect(try context.fetch(FetchDescriptor<PackingItem>()).isEmpty, "Cascade delete must remove all items through category")
    #expect(try context.fetch(FetchDescriptor<Activity>()).isEmpty)
}
```

Also update `TripTests.init()` (lines 11-15) to add `PackingCategory.self`:
```swift
container = try ModelContainer(
    for: Trip.self, Destination.self, Document.self,
         PackingItem.self, PackingCategory.self, Activity.self,
    configurations: config
)
```

---

## Shared Patterns

### @Query filtered by tripID
**Source:** `Travellify/Features/Documents/DocumentListView.swift` lines 35-44
**Apply to:** `PackingListView.swift` `init(tripID:)`
```swift
init(tripID: PersistentIdentifier) {
    self.tripID = tripID
    _documents = Query(
        filter: #Predicate<Document> { doc in
            doc.trip?.persistentModelID == tripID
        },
        sort: \Document.importedAt,
        order: .reverse
    )
}
```

### @Environment(\.modelContext) mutation
**Source:** `Travellify/Features/Documents/DocumentListView.swift` line 9
**Apply to:** `PackingListView.swift`, `PackingRow.swift` (if mutations live in the row)
```swift
@Environment(\.modelContext) private var modelContext
```

### Rename alert with `.disabled` guard
**Source:** `Travellify/Features/Documents/DocumentListView.swift` lines 161-192
**Apply to:** `PackingListView.swift` — category rename alert, new category alert, inline add item
```swift
Button("Save") { ... }
    .disabled(renameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
```

### Shared error alert (single @State String?)
**Source:** `Travellify/Features/Documents/DocumentListView.swift` lines 223-235
**Apply to:** `PackingListView.swift`
```swift
@State private var errorMessage: String?
// ...
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
    Text(msg) }
```

### contextMenu with rename + destructive delete
**Source:** `Travellify/Features/Documents/DocumentListView.swift` lines 73-81
**Apply to:** `CategoryHeader.swift`
```swift
.contextMenu {
    Button { /* set pending rename */ } label: { Label("Rename", systemImage: "pencil") }
    Button(role: .destructive) { /* set pending delete */ } label: { Label("Delete", systemImage: "trash") }
}
```

### @Model shape (CloudKit-safe)
**Source:** `Travellify/Models/Document.swift` lines 9-30
**Apply to:** `PackingCategory.swift`, `PackingItem.swift`
- Every property has a default value
- No `@Attribute(.unique)`
- All inverses are `Optional`
- `init() {}` empty initializer

### Cascade relationship declaration
**Source:** `Travellify/Models/Trip.swift` lines 14-22
**Apply to:** `Trip.swift` (packingCategories), `PackingCategory.swift` (items)
```swift
@Relationship(deleteRule: .cascade, inverse: \Destination.trip)
var destinations: [Destination]? = []
```

### Test container with explicit model list
**Source:** `TravellifyTests/DocumentTests.swift` lines 11-16
**Apply to:** `PackingTests.swift`, `PackingProgressTests.swift`
```swift
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, Activity.self,
        configurations: config
    )
}
```
_Add `PackingCategory.self` to the list._

### Empty state structure
**Source:** `Travellify/Features/Documents/EmptyDocumentsView.swift` lines 3-23
**Apply to:** `EmptyPackingListView.swift`
```swift
VStack(spacing: 0) {
    Image(systemName: "...")
        .font(.system(size: 56))
        .foregroundStyle(.secondary)
        .padding(.bottom, 32)
    Text("No ... Yet")
        .font(.title2.weight(.semibold))
        .foregroundStyle(.primary)
        .padding(.bottom, 8)
    Text("Hint text...")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
}
.padding(.horizontal, 32)
.frame(maxWidth: .infinity, maxHeight: .infinity)
.accessibilityElement(children: .combine)
.accessibilityLabel("Combined VoiceOver label.")
```

### `modelContext.model(for:)` trip lookup
**Source:** `Travellify/Features/Documents/DocumentListView.swift` lines 46-48
**Apply to:** `PackingListView.swift` if a trip model reference is needed
```swift
private var trip: Trip? {
    modelContext.model(for: tripID) as? Trip
}
```

### SectionCard NavigationLink with `.buttonStyle(.plain)`
**Source:** `Travellify/Features/Trips/TripDetailView.swift` lines 74-82
**Apply to:** `TripDetailView.swift` `packingCard(for:)` helper
```swift
NavigationLink(value: AppDestination.documentList(trip.persistentModelID)) {
    SectionCard(
        title: "Documents",
        systemImage: "doc.text",
        message: primary,
        secondaryMessage: latest
    )
}
.buttonStyle(.plain)
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Travellify/Features/Packing/PackingProgressRow.swift` | component | transform | No progress-view row exists in Phase 1 or Phase 2. Closest shape is `EmptyDocumentsView` (VStack + single view). Implement from RESEARCH.md Pattern 6 and UI-SPEC Progress Header Row spec. |

---

## Metadata

**Analog search scope:** `Travellify/Features/Documents/`, `Travellify/Features/Trips/`, `Travellify/Models/`, `Travellify/App/`, `Travellify/Shared/`, `TravellifyTests/`
**Files scanned:** 16
**Key insight:** Phase 3 is a nearly-exact structural mirror of Phase 2 (Documents). Every new file in `Features/Packing/` has a direct analog in `Features/Documents/`. The primary new surfaces (swipe actions, FocusState inline editing, drag-and-drop, sensoryFeedback, per-section progress) have no codebase analog but are fully specified in RESEARCH.md Patterns 1–6.
**Pattern extraction date:** 2026-04-21
