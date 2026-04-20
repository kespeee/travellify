# Phase 3: Packing List — Research

**Researched:** 2026-04-21
**Domain:** SwiftUI + SwiftData — categorized packing list, swipe gestures, inline editing, drag-to-move, progress computation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D19** — PackingCategory is its own `@Model` with optional inverse to `Trip` and cascade to `PackingItem`.
- **D20** — PackingItem replaces the placeholder schema: adds `name`, `isChecked`, `sortOrder`, `category: PackingCategory?`; removes the old `trip: Trip?` direct link. `Trip` adds `packingCategories: [PackingCategory]? = []` (cascade).
- **D21** — Ordering is creation order via `sortOrder: Int`; no alphabetical sort; no intra-category drag-reorder.
- **D22** — Cascade on Trip delete via `@Relationship(deleteRule: .cascade)`.
- **D23** — Single `List` with one `Section` per category.
- **D24** — Trip-level progress is an inline header row, scrolls with content.
- **D25** — Per-section header shows `X/Y` counter on the trailing side.
- **D26** — Leading swipe (right) toggles isChecked; green tint; `checkmark` SF Symbol; `allowsFullSwipe: true`.
- **D27** — Trailing swipe (left, `role: .destructive`) deletes item; no confirmation.
- **D28** — Checked state: strikethrough + `.secondary` foreground; item stays in place.
- **D29** — `.sensoryFeedback(.success, trigger: item.isChecked)` on each row — fires on any toggle direction.
- **D30** — Add item: inline `TextField` at bottom of each section; autofocus on tap; stay-focused for multi-add.
- **D31** — Edit item name: single tap on existing row enters inline rename; submit saves; tap-outside reverts.
- **D32** — Move item: cross-category drag-and-drop only; intra-category reorder out of scope.
- **D33** — Delete item surface: trailing swipe only (no context menu on items).
- **D34** — Add category: "Add category" row at list bottom → `.alert` with `TextField`.
- **D35** — Rename/Delete category: long-press section header → `.contextMenu` → `.alert` (rename) or `.confirmationDialog` (delete).
- **D36** — Delete-category cascade: `.confirmationDialog` with name + item count; `context.delete(category)` triggers cascade.
- **D37** — Progress values computed on the fly from `@Query` results; no stored aggregates.
- **D38** — Empty state: text-only centered view; "Add category" row remains at bottom.
- **D39** — `AppDestination.packingList(Trip.persistentModelID)` extends `AppDestination` enum; wires TripDetail Packing card.

### Claude's Discretion

- Exact spacing, font sizes, and SF Symbol choices — follow iOS defaults and UI-SPEC.
- Internal file structure under `Travellify/Features/Packing/` — mirror Phase 2 `Features/Documents/` organization.
- `@FocusState` placement (per-row ID enum or `PersistentIdentifier?` for add vs. rename).
- Return-key behavior on add-item `TextField` — insert-and-continue per D30.

### Deferred Ideas (OUT OF SCOPE)

- Intra-category drag-to-reorder (D21/D32 out of scope for v1).
- "Uncategorized" catch-all category.
- Trip templates / copy-from-past-trip packing list.
- Stored aggregate counts (rejected in D37).
- Per-item notes / quantity / weight.
- Pin / flag actions on swipe surfaces.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PACK-01 | User can build a packing list for a trip from scratch, organized by user-created categories | D19–D23, D34, D38: PackingCategory model + Section-per-category List + Add category row |
| PACK-02 | User can add a packing item under a category with a name | D20, D30: PackingItem model + inline add-item TextField at section bottom |
| PACK-03 | User can edit a packing item's name or category | D31 (rename inline), D32 (cross-category drag-and-drop) |
| PACK-04 | User can delete a packing item | D27, D33: trailing swipe on item row, no confirmation |
| PACK-05 | User can add, rename, and delete categories | D34 (add), D35, D36 (rename + delete via context menu) |
| PACK-06 | User can check off a packing item by swiping the row (swipe again to uncheck) | D26: leading swipe toggle; D28: checked style; D29: haptic |
| PACK-07 | Packing list displays a progress indicator ("12 / 23 packed") at the top | D24, D25, D37: inline progress header + per-section counters computed from @Query |

</phase_requirements>

---

## Summary

Phase 3 introduces a categorized packing list per trip. The data model adds two new `@Model` types — `PackingCategory` and an expanded `PackingItem` — both inside the existing `TravellifySchemaV1`. Because no production data exists yet (Phase 1+2 shipped to the developer only), all schema changes land in `SchemaV1` without requiring a `SchemaV2` migration stage; the `models` array in `SchemaV1` gains `PackingCategory.self`, and `PackingItem.self` is already present (currently a placeholder). All decisions D19–D39 are locked; the research below documents how to implement them faithfully using verified SwiftUI/SwiftData APIs.

The dominant technical challenges are: (1) the two-level `@Query` pattern (categories fetched by trip, items fetched through the category relationship), (2) `@FocusState` with `PersistentIdentifier?` driving two independent focus domains (add-item per section vs. inline rename per row), (3) cross-category drag-and-drop via `.draggable` + `.dropDestination` (iOS 16+ Transferable API, available within the iOS 17 floor), and (4) threading the `contextMenu` correctly on section headers while keeping item rows free of context menus per D33.

**Primary recommendation:** Mirror the DocumentListView architecture exactly — `@Query` filtered by `tripID`, `@Environment(\.modelContext)` for mutations, no ViewModel, Group/if for empty state — and layer in the new interaction surfaces (swipe actions, FocusState inline editing, draggable/dropDestination) as view modifiers on the List and its rows.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| PackingCategory + PackingItem persistence | SwiftData (@Model) | — | Local-only v1; no network layer |
| Fetching categories for a trip | SwiftData (@Query with predicate) | — | `@Query` drives live-updating List |
| Progress computation (trip-level + per-category) | SwiftUI View (computed property) | — | D37: on-the-fly from @Query results |
| List rendering with sections | SwiftUI (List + Section) | — | D23: single List, one Section per category |
| Inline add/rename item | SwiftUI (@FocusState + TextField) | — | D30/D31: focus-driven inline editing |
| Swipe-to-check + swipe-to-delete | SwiftUI (.swipeActions) | — | D26/D27: leading/trailing swipe |
| Haptic feedback | SwiftUI (.sensoryFeedback) | — | D29: `.success` on isChecked change |
| Cross-category drag-to-move | SwiftUI (.draggable + .dropDestination) | SwiftData (category reassignment) | D32: Transferable-based drag, SwiftData persists result |
| Category CRUD (add/rename/delete) | SwiftUI (.alert + .confirmationDialog + .contextMenu) | SwiftData | D34/D35/D36 |
| Navigation routing | SwiftUI (AppDestination enum + NavigationLink) | — | D39: extends existing enum |
| Schema registration | SwiftData (SchemaV1 models array + TravellifyApp) | — | PackingCategory.self added to container |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ | `@Model`, `@Query`, `@Relationship`, `ModelContext` | First-party, locked by CLAUDE.md; CloudKit path for v2 |
| SwiftUI | iOS 17+ | `List`, `Section`, `.swipeActions`, `.contextMenu`, `.alert`, `.confirmationDialog`, `ProgressView`, `TextField`, `@FocusState`, `.sensoryFeedback`, `.draggable`, `.dropDestination` | First-party, locked by CLAUDE.md |
| Swift Testing | Xcode 16 | `@Test`, `#expect`, `@MainActor` structs | Locked by CLAUDE.md; already in use for all unit tests |
| SF Symbols 5 | iOS 17+ | `checkmark`, `trash`, `plus.circle`, `checklist`, `pencil` | First-party; zero dependency |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | iOS 17+ | `UUID`, `PersistentIdentifier` comparisons | Always (already imported in models) |
| OSLog (`Logger`) | iOS 14+ | Error logging in catch blocks | Swipe-delete and save-failure catch blocks (consistent with Phase 2) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.draggable` + `.dropDestination` | `.onDrag` + `.onDrop` with `NSItemProvider` | `.onDrag`/`.onDrop` are pre-iOS-16 and use `NSItemProvider` (Obj-C); `.draggable`/`.dropDestination` use `Transferable` (Swift-native, available iOS 16+, which is below the iOS 17 floor) — prefer the newer API |
| Inline `@FocusState` with `PersistentIdentifier?` | `@FocusState` with `Bool` per row | `Bool` forces a separate `@State` per row; `PersistentIdentifier?` as the tag value drives both add and rename domains with a single property |

**Installation:** No new packages. All APIs are first-party Apple frameworks already in the project.

---

## Architecture Patterns

### System Architecture Diagram

```
TripDetailView
  └── packingCard(for:) [computed from trip.packingCategories?]
        └── NavigationLink(value: .packingList(tripID))
              └── PackingListView(tripID:)
                    │
                    ├── @Query(filter: category.trip?.persistentModelID == tripID,
                    │         sort: sortOrder) → [PackingCategory]
                    │
                    ├── [categories empty] → EmptyPackingListView
                    │                         + "Add category" row
                    │
                    └── [categories non-empty]
                          ├── PackingProgressRow          ← computed checkedCount/totalCount
                          │   (VStack: label + ProgressView)
                          │
                          └── ForEach(categories) { category }
                                Section {
                                  ForEach(sortedItems(category)) { item }
                                    PackingRow(item:)
                                      ├── Text / TextField (rename mode)
                                      ├── .swipeActions(.leading)  → toggle isChecked
                                      ├── .swipeActions(.trailing) → delete item
                                      ├── .sensoryFeedback(.success, trigger: item.isChecked)
                                      └── .draggable(item.persistentModelID)

                                  AddItemRow(category:)       ← inline TextField / placeholder
                                } header: {
                                  CategoryHeader(category:)
                                    ├── name (leading) + X/Y (trailing)
                                    ├── .contextMenu → Rename (.alert) / Delete (.confirmationDialog)
                                    └── .dropDestination(for: PersistentIdentifier) { reassign item }
                                }

                          + AddCategoryRow                  ← tap → .alert with TextField
```

### Recommended Project Structure

```
Travellify/Features/Packing/
├── PackingListView.swift         # Screen; owns @Query, all @State, all .alert/.confirmationDialog modifiers
├── PackingRow.swift              # Item row; Text vs TextField (rename); both swipeActions; sensoryFeedback; draggable
├── CategoryHeader.swift          # Section header HStack; contextMenu; dropDestination
├── PackingProgressRow.swift      # Trip-level progress VStack (label + ProgressView)
└── EmptyPackingListView.swift    # Zero-categories empty state

TravellifyTests/
├── PackingTests.swift            # Model invariants + cascade tests (Trip→Category→Item)
└── PackingProgressTests.swift    # Progress computation edge cases
```

### Pattern 1: @Query Filtered by Trip (mirrors DocumentListView)

**What:** Fetch `PackingCategory` rows belonging to a specific trip using a `#Predicate` in `@Query` init.

**When to use:** `PackingListView` fetches categories; items are accessed through the relationship on each category (not via a second `@Query`).

**Example:**
```swift
// Source: DocumentListView.swift line 37-43 (Phase 2 established pattern)
// + CONTEXT.md D20 (items reach trip through category, not a direct trip link)

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

Items within each category are accessed as `category.items ?? []`, sorted by `sortOrder` at render time:
```swift
private func sortedItems(_ category: PackingCategory) -> [PackingItem] {
    (category.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
}
```

**Important:** PackingItem does NOT have a direct `trip` relationship (D20). Do not add a second `@Query` for items — fetch them through the category relationship. [VERIFIED: CONTEXT.md D20]

### Pattern 2: Dual @FocusState Domains

**What:** Two mutually exclusive focus domains in `PackingListView` — one for add-item (per category) and one for inline rename (per item).

**When to use:** D30 (add) and D31 (rename) both drive inline `TextField` in the same `List`. Using `PersistentIdentifier?` as the tag type lets a single `@FocusState` property track which specific category or item is focused.

**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/focusstate/projectedvalue]
// Applied per CONTEXT.md D30, D31

// In PackingListView:
@FocusState private var addItemFocus: PersistentIdentifier?
@FocusState private var renameItemFocus: PersistentIdentifier?
@State private var newItemNames: [PersistentIdentifier: String] = [:]
@State private var renameDrafts: [PersistentIdentifier: String] = [:]

// In AddItemRow (at section bottom):
TextField("Item name", text: binding(for: category))
    .focused($addItemFocus, equals: category.persistentModelID)
    .submitLabel(.done)
    .onSubmit {
        let trimmed = (newItemNames[category.persistentModelID] ?? "").trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            insertItem(name: trimmed, in: category)
            newItemNames[category.persistentModelID] = ""
            addItemFocus = category.persistentModelID  // re-focus for multi-add (D30)
        } else {
            addItemFocus = nil  // dismiss on empty (D30)
        }
    }

// In PackingRow (tap on existing item):
if renameItemFocus == item.persistentModelID {
    TextField("Item name", text: renameDraftBinding(for: item))
        .focused($renameItemFocus, equals: item.persistentModelID)
        .submitLabel(.done)
        .onSubmit { commitRename(item) }
} else {
    Text(item.name)
        .onTapGesture {
            renameDrafts[item.persistentModelID] = item.name
            renameItemFocus = item.persistentModelID
        }
}
```

SwiftUI `@FocusState` switching is automatic — gaining focus in one domain clears the other. [VERIFIED: developer.apple.com/documentation/swiftui/focusstate]

### Pattern 3: Leading + Trailing swipeActions

**What:** Two independent swipe surfaces on each item row.

**When to use:** D26 (leading, check-off) and D27 (trailing, delete).

**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/view/swipeactions]
// Per CONTEXT.md D26, D27

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

The `.sensoryFeedback` modifier fires on any change to `item.isChecked` — both check and uncheck directions. [VERIFIED: developer.apple.com/documentation/swiftui/sensory-feedback]

### Pattern 4: Cross-Category Drag-and-Drop (Transferable)

**What:** `.draggable` marks an item row as a drag source; `.dropDestination` on the `Section` header or the section area accepts the drop and reassigns `item.category`.

**When to use:** D32 — long-press and drag item to another category.

**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/view/draggable]
//         [CITED: developer.apple.com/documentation/swiftui/view/dropdestination]

// Make PackingItem's PersistentIdentifier transferable via a String wrapper:
// (PersistentIdentifier itself is not Transferable; encode as a string or use NSItemProvider)
// Simplest approach: use the item's UUID (stored as id: UUID) as the Transferable payload

// In PackingRow body:
Text(item.name)
    // ... other modifiers ...
    .draggable(item.id.uuidString)  // UUID string is Transferable

// In CategoryHeader (section header):
HStack { ... }
    .dropDestination(for: String.self) { droppedIDs, _ in
        guard let uuidString = droppedIDs.first,
              let uuid = UUID(uuidString: uuidString),
              let item = fetchItem(byID: uuid) else { return false }
        item.category = category      // reassign
        item.sortOrder = nextSortOrder(in: category)
        try? modelContext.save()
        return true
    } isTargeted: { isTargeted in
        // optional: highlight header when drag is over it
    }
```

**Critical constraint:** `.draggable` + `.dropDestination` require `Transferable` conformance on the payload type. `String` satisfies `Transferable` out of the box. `PersistentIdentifier` and `UUID` do not conform to `Transferable` directly — use `item.id.uuidString` as the payload and resolve back to the `PackingItem` model in the drop handler via `FetchDescriptor`. [VERIFIED: developer.apple.com/documentation/swiftui/view/draggable, developer.apple.com/documentation/swiftui/view/dropdestination]

**Fetch by UUID in drop handler:**
```swift
private func fetchItem(byID id: UUID) -> PackingItem? {
    let desc = FetchDescriptor<PackingItem>(
        predicate: #Predicate { $0.id == id }
    )
    return try? modelContext.fetch(desc).first
}
```

### Pattern 5: Section Header with contextMenu

**What:** Long-press on the section header presents a context menu with Rename and Delete (D35).

**When to use:** Category CRUD — the header is the only surface for category rename and delete.

**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/view/contextmenu]
// Per CONTEXT.md D35

Section {
    // ... item rows ...
} header: {
    CategoryHeader(
        category: category,
        onRename: { pendingRenameCategory = category; renameCategoryDraft = category.name },
        onDelete: { pendingDeleteCategory = category }
    )
}

// In CategoryHeader:
HStack {
    Text(category.name).font(.headline)
    Spacer()
    Text("\(checkedCount)/\(totalCount)").font(.subheadline).foregroundStyle(.secondary)
}
.contentShape(Rectangle())  // ensures full-width long-press target
.contextMenu {
    Button {
        onRename()
    } label: { Label("Rename", systemImage: "pencil") }

    Button(role: .destructive) {
        onDelete()
    } label: { Label("Delete", systemImage: "trash") }
}
.accessibilityHint("Long press for rename and delete options")
```

`.contentShape(Rectangle())` is required to make the full header width long-pressable; without it, only the `Text` areas register the gesture. [ASSUMED — common SwiftUI gesture area fix; not explicitly documented in Apple docs for contextMenu but consistently required in practice]

### Pattern 6: Progress Computation (No Stored Aggregates)

**What:** Compute trip-level and per-category checked/total counts directly from the `@Query`-fetched categories array.

**When to use:** D37 — all progress is derived, never stored.

**Example:**
```swift
// Per CONTEXT.md D37

// Trip-level (in PackingListView):
private var tripCheckedCount: Int {
    categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
}
private var tripTotalCount: Int {
    categories.flatMap { $0.items ?? [] }.count
}

// Per-category (passed into CategoryHeader or computed inline in Section header):
private func checkedCount(in category: PackingCategory) -> Int {
    (category.items ?? []).filter(\.isChecked).count
}
private func totalCount(in category: PackingCategory) -> Int {
    (category.items ?? []).count
}

// Progress bar (UI-SPEC):
ProgressView(
    value: Double(tripCheckedCount),
    total: Double(max(tripTotalCount, 1))  // guard against division by zero when totalCount == 0
)
.progressViewStyle(.linear)
.tint(.accentColor)
```

### Pattern 7: Schema Changes Inside SchemaV1 (No Migration Stage)

**What:** Add `PackingCategory` model and expand `PackingItem` within the existing `TravellifySchemaV1` without adding a `SchemaV2` stage.

**When to use:** No production data has shipped yet (Phase 1+2 developer-only). Adding models to the `models` array and replacing the placeholder `PackingItem` properties is a lightweight change that does not require a `MigrationStage`. [VERIFIED: Phase 2 RESEARCH.md, CONTEXT.md code_context — same rationale applied to Document field additions in Phase 2]

**What changes in SchemaV1.swift:**
```swift
// Source: Travellify/Models/SchemaV1.swift (current)
// Add PackingCategory.self to the models array:
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

// Add typealias at bottom:
typealias PackingCategory = TravellifySchemaV1.PackingCategory  // NEW
```

**What changes in TravellifyApp.swift:**
The `ModelContainer` call must include `PackingCategory.self` in the explicit type list. The existing explicit-model-list pattern from Phase 1 (Decision recorded in STATE.md: "Explicit model list in ModelContainer — safer than graph discovery") must be extended.

**SchemaTests impact:**
`schemaV1HasFiveModels` test currently expects `count == 5`. Adding `PackingCategory` makes it 6. That test must be updated to `#expect(TravellifySchemaV1.models.count == 6)`.

`deleteTripCascadesToPlaceholderModels` in `TripTests.swift` still uses the old `PackingItem` with `pack.trip = trip`. After the schema replacement, `PackingItem` no longer has a direct `trip` property — this test must be rewritten to use the new two-level relationship (create a `PackingCategory` belonging to the trip, add a `PackingItem` to the category, then verify cascade).

### Anti-Patterns to Avoid

- **Direct `trip: Trip?` on `PackingItem`:** D20 explicitly removes this. Items reach the trip through their category. Adding it back breaks the two-level cascade design and adds a redundant relationship.
- **Stored `checkedCount` / `totalCount` on Trip or PackingCategory:** D37. Even if it seems convenient, it creates a sync bug risk where the aggregate diverges from reality after a save failure.
- **`@Attribute(.unique)` on any property:** CLAUDE.md hard rule — CloudKit does not support uniqueness constraints. Never add it.
- **`@Query` for PackingItem filtered by tripID directly:** Items do not have a `trip` relationship (D20). Filter by category, then access items through the relationship.
- **Separate `NavigationStack` push for a category detail view:** D23 rejects this. All items in one List.
- **Tap-to-check on item row:** D26 specifies swipe-only check-off. Single tap is reserved for inline rename (D31). Do not add a tap-to-check affordance.
- **Context menu on item rows:** D33. Item actions are swipe-only. A context menu on items would conflict with D35's long-press-for-category-header pattern.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Check/uncheck toggle with haptics | Custom gesture recognizer + UIFeedbackGenerator | `.swipeActions` (D26) + `.sensoryFeedback(.success)` (D29) | SwiftUI handles swipe state, animation, and cancellation; UIFeedbackGenerator requires UIKit import and manual trigger timing |
| Inline editing (tap to rename) | Custom `UITextField` overlay | `@FocusState` + `TextField` (D31) | SwiftUI `@FocusState` manages keyboard appearance, focus transfer, and dismiss on tap-outside automatically |
| Drag-and-drop between sections | Custom `UIDragInteraction` / `UIDropInteraction` | `.draggable` + `.dropDestination` (D32) | `Transferable` protocol integration avoids `NSItemProvider` boilerplate; works within the SwiftUI list naturally |
| Progress bar | `CAShapeLayer` arc or custom drawing | `ProgressView(value:total:)` (D24) | System `ProgressView` respects Dynamic Type, dark mode, and reduced motion automatically |
| Confirmation dialogs | Custom modal sheet | `.confirmationDialog` (D36) | System `.confirmationDialog` matches iOS destructive-action idiom; positions itself correctly on iPhone |

---

## Common Pitfalls

### Pitfall 1: @FocusState Identity Collision Between Add and Rename Domains

**What goes wrong:** Both the add-item row and the rename-item row use `PersistentIdentifier?` as the focus tag. If both `@FocusState` properties use the same type, SwiftUI cannot distinguish them without separate property wrappers.

**Why it happens:** `@FocusState` tags must be unique per property wrapper instance; two separate `@FocusState` properties with the same type are independent, which is correct behavior. The error occurs when developers try to share a single `@FocusState` for both purposes.

**How to avoid:** Declare two separate `@FocusState` properties (`addItemFocus` and `renameItemFocus`), exactly as specified in CONTEXT.md Focus State Contracts. When one gains focus, SwiftUI automatically clears the other because the keyboard can only be focused on one field at a time. [VERIFIED: CONTEXT.md, developer.apple.com/documentation/swiftui/focusstate]

### Pitfall 2: Draggable Payload Must Conform to Transferable

**What goes wrong:** Attempting to use `PersistentIdentifier` or a custom `@Model` instance as the `.draggable` payload causes a compile error: "Type does not conform to Transferable."

**Why it happens:** `@Model` types and `PersistentIdentifier` do not conform to `Transferable`. SwiftData models must not cross actor boundaries as-is.

**How to avoid:** Use `item.id.uuidString` (a `String`, which conforms to `Transferable`) as the drag payload. In the `dropDestination` handler, resolve the UUID back to the `PackingItem` via a `FetchDescriptor<PackingItem>` predicate on `id`. [VERIFIED: developer.apple.com/documentation/swiftui/view/draggable]

### Pitfall 3: Section Header long-press Hit Area

**What goes wrong:** The `.contextMenu` on a custom `HStack` section header only responds to long-press on the Text nodes, not the full-width row. Users miss the gesture target.

**Why it happens:** SwiftUI hit-testing defaults to the minimal bounding box of rendered content. An `HStack` with a `Spacer()` has a very wide logical frame but the hit area only covers the text characters without `.contentShape`.

**How to avoid:** Apply `.contentShape(Rectangle())` to the `HStack` in `CategoryHeader` before attaching `.contextMenu`. This makes the full width and height of the header row respond to long-press. [ASSUMED — consistent SwiftUI pattern; not uniquely documented for contextMenu by Apple, but applies to all gesture-modifier hit testing]

### Pitfall 4: SchemaV1 Models Array and ModelContainer Must Both Be Updated

**What goes wrong:** Adding `PackingCategory.self` to `TravellifySchemaV1.models` but forgetting to add it to the `ModelContainer` init in `TravellifyApp.swift` (and all test harnesses + preview containers) causes SwiftData to silently fail to register the type.

**Why it happens:** SwiftData requires explicit model registration in both the `VersionedSchema` and the `ModelContainer`. The Phase 1 decision (STATE.md: "Explicit model list in ModelContainer — safer than graph discovery") makes this manual.

**How to avoid:** Update all four callsites in sequence:
1. `TravellifySchemaV1.models` array in `SchemaV1.swift`
2. `ModelContainer(for: ...)` in `TravellifyApp.swift`
3. `previewContainer` in `Shared/PreviewContainer.swift`
4. Every `init() throws` in test structs (`TripTests.swift`, `SchemaTests.swift`, `DocumentTests.swift`, and any new Phase 3 test files)
[VERIFIED: SchemaV1.swift, PreviewContainer.swift, TripTests.swift, STATE.md]

### Pitfall 5: Old PackingItem Placeholder Breaks Existing Tests

**What goes wrong:** Replacing the placeholder `PackingItem` (which had `var trip: Trip?`) with the D20 schema (which has `var category: PackingCategory?`) breaks `TripTests.swift:deleteTripCascadesToPlaceholderModels` because it creates `pack.trip = trip` directly.

**Why it happens:** The existing test references the placeholder's direct `trip` property, which will no longer exist after the schema replacement.

**How to avoid:** Update `deleteTripCascadesToPlaceholderModels` in `TripTests.swift` to test the two-level cascade: insert a `PackingCategory` with `category.trip = trip`, insert a `PackingItem` with `item.category = category`, delete the trip, verify both category and item are gone. [VERIFIED: TripTests.swift lines 78-101, CONTEXT.md D20]

### Pitfall 6: Multi-Add Focus Loop Breaks on Empty Submit

**What goes wrong:** After an empty submit on the add-item `TextField`, re-setting `addItemFocus = category.persistentModelID` in the empty branch keeps the keyboard open instead of dismissing it.

**Why it happens:** Re-assigning the same `PersistentIdentifier` value to `@FocusState` when it is already the current focus value does not trigger a dismissal.

**How to avoid:** On empty submit, set `addItemFocus = nil` (not the same ID) to explicitly dismiss focus. Only re-focus after a non-empty insert (D30). [VERIFIED: CONTEXT.md D30, developer.apple.com/documentation/swiftui/focusstate — setting to nil removes focus from all bound fields]

### Pitfall 7: sortOrder Gap After Item Move

**What goes wrong:** When an item is dragged to a different category, its `sortOrder` is set to `max(existingItems.sortOrder) + 1`. If many items are moved out of a category, the original category's `sortOrder` sequence has gaps (e.g., 0, 2, 5). This is benign for the append-only model but could cause ordering issues if the planner ever adds intra-category reorder.

**Why it happens:** D21 specifies creation-order via append. No compaction is needed for v1.

**How to avoid:** Accept gaps — this is intentional per D21 and D32. Document the gap in code comments. Do not compact `sortOrder` values on every edit (unnecessarily expensive). [VERIFIED: CONTEXT.md D21, D32]

---

## Code Examples

### Full PackingCategory @Model

```swift
// Source: CONTEXT.md D19 (verbatim locked decision)
// Location: Travellify/Models/PackingCategory.swift

import SwiftData
import Foundation

extension TravellifySchemaV1 {
    @Model
    final class PackingCategory {
        var id: UUID = UUID()
        var name: String = ""
        var sortOrder: Int = 0
        var trip: Trip?                                  // CloudKit-safe optional inverse

        @Relationship(deleteRule: .cascade, inverse: \PackingItem.category)
        var items: [PackingItem]? = []

        init() {}
    }
}
```

### Full PackingItem @Model (replacement for placeholder)

```swift
// Source: CONTEXT.md D20 (verbatim locked decision)
// Location: Travellify/Models/PackingItem.swift (REPLACES placeholder)

import SwiftData
import Foundation

extension TravellifySchemaV1 {
    @Model
    final class PackingItem {
        var id: UUID = UUID()
        var name: String = ""
        var isChecked: Bool = false
        var sortOrder: Int = 0
        var category: PackingCategory?                   // CloudKit-safe optional inverse

        init() {}
    }
}
```

### Trip @Model addition (packingCategories relationship)

```swift
// Source: CONTEXT.md D20 — add to Trip.swift
// Follows existing pattern from Trip.swift lines 15-18

@Relationship(deleteRule: .cascade, inverse: \PackingCategory.trip)
var packingCategories: [PackingCategory]? = []
// NOTE: remove the old `var packingItems: [PackingItem]? = []` that references PackingItem.trip directly
```

### AppDestination extension

```swift
// Source: CONTEXT.md D39; mirrors Phase 2 Pattern S5 (AppDestination.documentList)
// Location: Travellify/App/AppDestination.swift

enum AppDestination: Hashable {
    case tripDetail(PersistentIdentifier)
    case documentList(PersistentIdentifier)
    case packingList(PersistentIdentifier)        // NEW
}
```

### ContentView router addition

```swift
// Source: ContentView.swift lines 10-17 (existing switch pattern)
case .packingList(let id):
    PackingListView(tripID: id)
```

### TripDetail packingCard helper (mirrors documentsCard)

```swift
// Source: TripDetailView.swift lines 66-83 (documentsCard pattern)
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

### Error alert pattern (shared surface, mirrors DocumentListView)

```swift
// Source: DocumentListView.swift lines 223-236 (shared error alert pattern)
// In PackingListView — single @State var errorMessage: String?

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

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.onDrag` / `.onDrop` with `NSItemProvider` | `.draggable` / `.dropDestination` with `Transferable` | iOS 16 / WWDC 2022 | Swift-native, no Obj-C bridging; available within iOS 17 floor |
| `ObservableObject` + `@Published` | `@Observable` macro / `@Query` direct in views | iOS 17 / WWDC 2023 | No ViewModel needed; `@Query` replaces `NSFetchedResultsController`; already established in Phase 1 |
| `XCTest` unit tests | `Swift Testing` (`@Test`, `#expect`) | Xcode 16 | Parallel execution, async-native; locked in CLAUDE.md; already in use |

**Deprecated/outdated:**
- `@Attribute(.unique)`: CloudKit incompatible; forbidden by CLAUDE.md. Use UUID default values instead.
- `PackingItem.trip: Trip?` (old placeholder): Replaced entirely by D20's two-level relationship. Remove from model file.
- `Trip.packingItems: [PackingItem]? = []` (old Phase 1 direct relationship): Replace with `Trip.packingCategories: [PackingCategory]? = []` per D20.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `.contentShape(Rectangle())` is required on the `CategoryHeader` HStack to make the full-width area respond to long-press for `.contextMenu` | Pattern 5, Pitfall 3 | Without it, users can only trigger the context menu on the text characters — poor UX but not a crash; easy to add if discovered during testing |
| A2 | `UUID` strings (`item.id.uuidString`) are the cleanest `Transferable` payload for cross-category drag — no custom `Transferable` conformance needed | Pattern 4 | If SwiftData's `FetchDescriptor` predicate on `UUID` has performance issues at scale, a more direct resolution method may be needed; at <200 items per trip, this is negligible |

**All other claims in this research are VERIFIED against existing codebase files or CITED from official Apple documentation.**

---

## Open Questions

1. **`Trip.packingItems` relationship in Trip.swift — removal timing**
   - What we know: `Trip.swift` line 22-23 has `@Relationship(deleteRule: .cascade, inverse: \PackingItem.trip) var packingItems: [PackingItem]? = []`. D20 replaces this with `packingCategories`.
   - What's unclear: Whether removing `packingItems` (and the corresponding `trip: Trip?` from `PackingItem`) while no production data exists truly requires no migration stage beyond the SchemaV1 models-array update.
   - Recommendation: Confirm this in Wave 0 schema test — if `ModelContainer` initializes cleanly with the replaced schema, no migration stage is needed. This matches the Phase 2 precedent (Document field additions, no migration). [VERIFIED pattern: STATE.md "D10 lightweight migration confirmed"]

2. **`schemaV1HasFiveModels` test — update to 6**
   - What we know: `SchemaTests.swift` line 18 expects `count == 5`. Adding `PackingCategory` makes it 6.
   - What's unclear: Nothing — this is a required test update.
   - Recommendation: Plan must include updating this assertion in Wave 0.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 3 is a pure SwiftUI/SwiftData feature with no external CLI tools, services, databases, or runtimes beyond what Phases 1 and 2 already established (Xcode 26.2, iPhone 16e simulator). All APIs are first-party Apple frameworks.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (Xcode 16) |
| Config file | None — Swift Testing is built into Xcode 16; no separate config needed |
| Quick run command | `xcodebuild test -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing TravellifyTests/PackingTests` |
| Full suite command | `xcodebuild test -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PACK-01 | PackingCategory persists with name, sortOrder, trip relationship | unit | `xcodebuild test ... -only-testing TravellifyTests/PackingTests/packingCategoryPersists` | ❌ Wave 0 |
| PACK-01 | Trip cascade deletes PackingCategory (and items) | unit | `xcodebuild test ... -only-testing TravellifyTests/PackingTests/deleteTripCascadesToCategories` | ❌ Wave 0 |
| PACK-02 | PackingItem persists under a category | unit | `xcodebuild test ... -only-testing TravellifyTests/PackingTests/packingItemPersistsUnderCategory` | ❌ Wave 0 |
| PACK-04 | PackingCategory cascade deletes its items | unit | `xcodebuild test ... -only-testing TravellifyTests/PackingTests/deleteCategoryCascadesToItems` | ❌ Wave 0 |
| PACK-06 | isChecked defaults to false; toggle persists | unit | `xcodebuild test ... -only-testing TravellifyTests/PackingTests/isCheckedDefaultsFalseAndToggles` | ❌ Wave 0 |
| PACK-07 | Trip-level progress: 0/0, some, all checked | unit | `xcodebuild test ... -only-testing TravellifyTests/PackingProgressTests/tripLevelProgress` | ❌ Wave 0 |
| PACK-07 | Per-category progress: empty, partial, full | unit | `xcodebuild test ... -only-testing TravellifyTests/PackingProgressTests/categoryLevelProgress` | ❌ Wave 0 |
| PACK-07 | Progress denominator guard (0 items → no divide-by-zero) | unit | `xcodebuild test ... -only-testing TravellifyTests/PackingProgressTests/progressGuardZeroTotal` | ❌ Wave 0 |
| Schema | SchemaV1 has 6 models (Trip, Destination, Document, PackingItem, PackingCategory, Activity) | unit | `xcodebuild test ... -only-testing TravellifyTests/SchemaTests/schemaV1HasSixModels` | ❌ Wave 0 (update existing) |
| Schema | CloudKit safety: no @Attribute(.unique), all inverses optional | unit (grep gate) | `xcodebuild test ... -only-testing TravellifyTests/SchemaTests` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Run `PackingTests` + `PackingProgressTests` + `SchemaTests`
- **Per wave merge:** Full test suite
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `TravellifyTests/PackingTests.swift` — covers PACK-01, PACK-02, PACK-04, PACK-06 model invariants and cascade behavior
- [ ] `TravellifyTests/PackingProgressTests.swift` — covers PACK-07 edge cases (0/0, partial, all-checked, divide-by-zero guard)
- [ ] Update `TravellifyTests/SchemaTests.swift` line 18: `count == 5` → `count == 6`
- [ ] Update `TravellifyTests/TripTests.swift:deleteTripCascadesToPlaceholderModels` to use two-level relationship (PackingCategory → PackingItem) after placeholder replacement

---

## Security Domain

> `security_enforcement` not set in config — treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Phase 3 adds no auth surface (DOC-08 / Face ID deferred to Phase 6) |
| V3 Session Management | No | Local-only SwiftData, no sessions |
| V4 Access Control | No | Single-user local app; no permission model in v1 |
| V5 Input Validation | Yes | Packing category and item names: trimmed whitespace, non-empty gate before insert/save |
| V6 Cryptography | No | No cryptographic operations in Phase 3 |

### Input Validation Contract (V5)

All text inputs must be trimmed before persisting. Empty trimmed input is rejected silently (no insert) or reverts to original (rename). This matches the UI-SPEC Validation Rules table and is enforced in-view:

```swift
let trimmed = text.trimmingCharacters(in: .whitespaces)
guard !trimmed.isEmpty else { return }
// proceed with insert/save
```

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Overly long category/item names causing layout overflow | Tampering | `.lineLimit(1)` truncation on all name `Text` views; no enforced character limit (soft cap per UI-SPEC) |
| SwiftData save failure leaving UI out of sync | Tampering | Wrap all `modelContext.save()` in `do/catch`; surface error alert for user-visible operations (UI-SPEC Error States); `assertionFailure` for programming errors only |

---

## Sources

### Primary (HIGH confidence)

- `Travellify/Models/PackingItem.swift` — placeholder schema examined directly
- `Travellify/Models/SchemaV1.swift` — existing schema structure verified
- `Travellify/Models/Trip.swift` — relationship patterns confirmed
- `Travellify/App/AppDestination.swift` — enum structure verified
- `Travellify/Features/Trips/TripDetailView.swift` — documentsCard pattern verified
- `Travellify/Features/Documents/DocumentListView.swift` — @Query + FocusState + error alert patterns
- `Travellify/Features/Documents/EmptyDocumentsView.swift` — empty state pattern
- `Travellify/Shared/PreviewContainer.swift` — preview seed pattern
- `TravellifyTests/SchemaTests.swift` — schema model count assertion
- `TravellifyTests/TripTests.swift` — test harness patterns
- `.planning/phases/02-documents/02-PATTERNS.md` — Phase 2 established patterns
- `.planning/phases/03-packing-list/03-CONTEXT.md` — locked decisions D19–D39
- `.planning/phases/03-packing-list/03-UI-SPEC.md` — UI contract
- [developer.apple.com/documentation/swiftui/view/swipeactions] — swipeActions API [CITED]
- [developer.apple.com/documentation/swiftui/focusstate] — FocusState API [CITED]
- [developer.apple.com/documentation/swiftui/view/draggable] — draggable API [CITED]
- [developer.apple.com/documentation/swiftui/view/dropdestination] — dropDestination API [CITED]
- [developer.apple.com/documentation/swiftui/sensory-feedback] — sensoryFeedback API [CITED]

### Secondary (MEDIUM confidence)

- [CLAUDE.md](Travellify/CLAUDE.md) — stack constraints, CloudKit-safety rules, testing framework choice
- `.planning/STATE.md` — accumulated technical context (xcode version, simulator, SchemaV1 migration decisions)

### Tertiary (LOW confidence)

- None — all claims verified against codebase or cited from official docs.

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all APIs are first-party Apple frameworks; versions verified against iOS 17 floor
- Architecture: HIGH — directly derived from CONTEXT.md locked decisions and verified Phase 2 patterns in the actual codebase
- Pitfalls: HIGH (verified) / ASSUMED for `.contentShape(Rectangle())` and UUID-as-Transferable (A1, A2) — low-risk assumptions

**Research date:** 2026-04-21
**Valid until:** 2026-07-21 (stable Apple framework APIs; SwiftData @ iOS 17 is mature)
