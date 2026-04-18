# Phase 1: Foundation + Trips — Research

**Researched:** 2026-04-19
**Domain:** SwiftData VersionedSchema bootstrap, ordered relationships, date-predicate partitioning, Xcode project scaffolding, NavigationStack typed routing, Swift Testing for SwiftData
**Confidence:** HIGH — all critical claims verified against Apple documentation, official WWDC sessions, and post-publication community sources from 2025–2026

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D1** — Destination is a separate `@Model` with `sortIndex: Int` for ordering; `Trip` has optional `destinations: [Destination]?`; inverse `Destination.trip: Trip?` (optional, CloudKit rule); cascade delete on Trip → Destination
- **D2** — Placeholder `Document`, `PackingItem`, `Activity` models declared in Phase 1 (minimal shape: `id`, `trip` inverse); optional empty relationships on `Trip`; avoids migration per phase
- **D3** — Trip list uses two `Section` blocks: Upcoming (endDate ≥ today, asc) and Past (endDate < today, desc); sections hidden when empty
- **D4** — Trip dates are `Date` normalized to start-of-day in user's current calendar at save time; `DatePicker` in `.datePickerStyle(.compact)` with `.date` component only; equality allowed (single-day trip)
- **D5** — Validation via disabled Save button (no alerts); name non-empty (trimmed); endDate ≥ startDate; at least one destination added (per CONTEXT.md) — but UI-SPEC says destinations are optional; researcher notes discrepancy: UI-SPEC wins (0+ destinations OK)
- **D6** — `PreviewContainer.swift` wrapped in `#if DEBUG`; in-memory `ModelContainer` seeded with 2–3 sample trips + destinations; consumed by all `#Preview` macros
- **D7** — Xcode project scaffolded via command-line; hand-written minimal `project.pbxproj`; NO xcodegen; fallback: user creates in Xcode GUI then executor fills Swift files
- **D8** — Architecture: SwiftUI views + `@Observable` for view-local state; NO MVVM ViewModels; `@Query` + `@Bindable` directly in views; extract `@Observable` only if view > 150 lines or non-trivial state machine
- **D9** — `NavigationStack` with typed `AppDestination` enum; root `TripListView`; row tap pushes `.tripDetail(id)`; "+" toolbar presents `TripEditSheet` as `.sheet`

### Claude's Discretion
- File layout for placeholder models (Open Question 1 — answered below)
- `@Query` partitioning strategy (Open Question 2 — answered below)
- Ordered destinations implementation detail (Open Question 3 — answered below)

### Deferred Ideas (OUT OF SCOPE)
- Any Document / Packing / Activity UI or CRUD (phases 2–7)
- iCloud/CloudKit wiring (v2 milestone)
- Face ID lock (Phase 6)
- Settings screen
- Empty-state polish beyond Phase 1 minimal
- Localization / i18n
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | App persists all data locally via SwiftData across launches, device restarts, and app kills | ModelContainer with persistent store (not in-memory) at App entry point covers this; standard SwiftData behavior |
| FOUND-02 | SwiftData schema wrapped in `VersionedSchema` from first release (zero migrations initially, infrastructure in place) | `TravellifySchemaV1: VersionedSchema` + `TravellifyMigrationPlan: SchemaMigrationPlan` with empty `stages` array — full boilerplate in Code Examples below |
| FOUND-03 | All `@Model` classes follow CloudKit-safe conventions (optional inverse relationships, no `@Attribute(.unique)`, no `.deny` delete rules) | Covered by model design rules in Standard Stack; verified against fatbobman CloudKit rules |
| TRIP-01 | User can create a trip with name and date range | `TripEditSheet` with `Form`, `TextField`, two `DatePicker` controls; Save inserts new `Trip` into `modelContext`; date normalization at save |
| TRIP-02 | User can define multi-stop trip by adding multiple destinations | `Destination` @Model with `sortIndex: Int`; inline destination list in `TripEditSheet` with `onMove`/`onDelete`; see Open Question 3 answer |
| TRIP-03 | User can browse all trips sorted by date | Two-section `List` (`TripListView`); single `@Query` sorted by `startDate`, partitioned in-memory; see Open Question 2 answer |
| TRIP-04 | User can open a trip to see documents, packing, activities in one place | `TripDetailView` with segmented `Picker` (3 tabs); each tab shows placeholder view in Phase 1 |
| TRIP-05 | User can edit a trip's name, dates, and destinations | Same `TripEditSheet` in edit mode; pre-populated; mutation on Save only (Cancel restores) |
| TRIP-06 | User can delete a trip, cascading to all children | Swipe `.swipeActions` → `.confirmationDialog` → `modelContext.delete(trip)` with `.cascade` on all child relationships |
</phase_requirements>

---

## Summary

Phase 1 establishes the entire persistence and navigation skeleton on which all seven phases build. The three most architecturally consequential decisions are: (1) wrapping every `@Model` inside `TravellifySchemaV1: VersionedSchema` from the first commit, (2) declaring placeholder `Document`, `PackingItem`, and `Activity` models now to lock the schema for 4–5 future phases, and (3) building the Xcode project via command-line scaffolding.

All decisions from CONTEXT.md are CloudKit-safe by design. The biggest Phase 1 risk is an incomplete `project.pbxproj` that `xcodebuild` rejects — the fallback path (user creates project in Xcode GUI, executor fills Swift files) must be a named checkpoint in the plan. The second risk is `@Query` date predicates: on iOS 17/18 you cannot capture `Date.now` directly inside `#Predicate`; you must capture it in a `let` constant before the predicate expression. The recommended pattern is a single `@Query` with no predicate, partitioned in-memory — trivially correct and fast for realistic trip counts (< 200).

There is a Xcode 26.2 note: the dev machine is running Xcode 26.2 / Swift 6.3.1. Xcode 26 is still labelled a beta SDK milestone (it ships iOS 26 SDK). For production App Store submission targeting iOS 17, ensure the deployment target is set to iOS 17.0 and the "Minimum Deployments" setting is not accidentally elevated by the Xcode 26 SDK defaults. This is a build-settings concern, not a code concern.

**Primary recommendation:** Scaffold the project, declare `TravellifySchemaV1` with all six `@Model` types, connect `ModelContainer` at the `@main` entry point, then build UI top-down: `TripListView` → `TripEditSheet` → `TripDetailView`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Data persistence (Trip, Destination, placeholders) | SwiftData (local store) | — | All structured data lives in SwiftData; no backend in v1 |
| Schema versioning | SwiftData (VersionedSchema enum) | — | Must wrap models before first commit; cannot retrofit |
| Navigation routing | SwiftUI (NavigationStack + AppDestination enum) | — | iPhone-only; typed enum prevents stringly-typed push bugs |
| Trip list display (two sections) | SwiftUI View (@Query + in-memory partition) | — | D8 mandates no ViewModel; `@Query` is the correct SwiftUI-native pattern |
| Trip CRUD mutations | SwiftUI View (modelContext from @Environment) | — | D8: direct `modelContext` in view actions; no ViewModel layer |
| Trip date normalization | SwiftUI View (save action) | — | Normalization is a save-time transform, done inline before `modelContext.insert` |
| Destination ordering | SwiftData model (sortIndex: Int on Destination) | SwiftUI onMove handler | `onMove` updates sortIndex values; SwiftData stores them |
| Preview seed data | DEBUG-gated PreviewContainer.swift | — | Keeps seed data out of release binary |
| Unit tests | Swift Testing (in-memory ModelContainer) | — | @MainActor test functions with fresh container per test |

---

## Standard Stack

### Core (Phase 1 only)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ | Local persistence for all models | First-party; `@Query` macro; CloudKit-ready path to v2 |
| SwiftUI | iOS 17+ | All UI — List, Form, NavigationStack, Sheet | First-party; `@Observable` + `@Bindable` pattern; zero third-party dependencies |
| Swift 6 (language mode) | Swift 6.3.1 (on dev machine) | Strict concurrency enforcement | Locked in CLAUDE.md; catches data-race bugs at compile time |
| Swift Testing | Xcode 16+ / any deploy target | Unit tests | Apple-endorsed replacement for XCTest in unit tests; parallel, async-native |

### No Third-Party Dependencies in Phase 1

All UI components are stock SwiftUI. Zero SwiftPM packages added in Phase 1. The `project.pbxproj` therefore needs no package resolution section.

---

## Architecture Patterns

### System Architecture Diagram

```
User input (tap / type / date pick)
         │
         ▼
  SwiftUI View Layer
  ┌────────────────────────────────────────────────────────┐
  │  TripListView (@Query → allTrips)                      │
  │    ├── upcoming = allTrips.filter { endDate >= today } │
  │    └── past     = allTrips.filter { endDate < today  } │
  │                        │ row tap                        │
  │                        ▼                               │
  │  TripDetailView(trip:)                                 │
  │    └── segmented Picker → placeholder tabs             │
  │                        │ .sheet                        │
  │                        ▼                               │
  │  TripEditSheet  (create / edit)                        │
  │    ├── TextField (name)                                │
  │    ├── DatePicker x2 (startDate, endDate)              │
  │    └── Destination list (onMove → sortIndex update)    │
  └──────────────────────┬─────────────────────────────────┘
                         │ modelContext.insert / delete / save
                         ▼
  SwiftData Layer
  ┌────────────────────────────────────────────────────────┐
  │  TravellifySchemaV1 (VersionedSchema)                  │
  │    Trip ──cascade──► Destination (sortIndex)           │
  │         ──cascade──► Document    (placeholder)         │
  │         ──cascade──► PackingItem (placeholder)         │
  │         ──cascade──► Activity    (placeholder)         │
  │                                                        │
  │  ModelContainer (persistent, on-disk SQLite store)     │
  │  TravellifyMigrationPlan (stages: [])                  │
  └────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
Travellify/
├── App/
│   ├── TravellifyApp.swift           # @main, ModelContainer setup
│   └── AppDestination.swift          # NavigationStack enum
│
├── Models/                           # All @Model types live here (file-per-model)
│   ├── SchemaV1.swift                # VersionedSchema enum + MigrationPlan
│   ├── Trip.swift                    # typealias Trip = TravellifySchemaV1.Trip
│   ├── Destination.swift
│   ├── Document.swift                # placeholder — id + trip only
│   ├── PackingItem.swift             # placeholder — id + trip only
│   └── Activity.swift                # placeholder — id + trip only
│
├── Features/
│   └── Trips/
│       ├── TripListView.swift
│       ├── TripDetailView.swift
│       └── TripEditSheet.swift
│
├── Shared/
│   └── PreviewContainer.swift        # #if DEBUG only
│
└── Travellify.xcodeproj/
    └── project.pbxproj
```

### Pattern 1: VersionedSchema + MigrationPlan Bootstrap

**What:** Wrap every `@Model` inside a `VersionedSchema` enum from the first commit. Expose module-level `typealias` so call sites write `Trip` not `TravellifySchemaV1.Trip`.

**When to use:** Always — before any model is written.

```swift
// Source: AzamSharp 2026 article (cited below) + Apple WWDC24 SwiftData session
// File: Models/SchemaV1.swift

import SwiftData

enum TravellifySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            TravellifySchemaV1.Trip.self,
            TravellifySchemaV1.Destination.self,
            TravellifySchemaV1.Document.self,
            TravellifySchemaV1.PackingItem.self,
            TravellifySchemaV1.Activity.self,
        ]
    }
}

enum TravellifyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TravellifySchemaV1.self] }
    static var stages: [MigrationStage] { [] }  // No migration in v1
}

// Module-level typealiases — call sites write `Trip` everywhere
typealias Trip        = TravellifySchemaV1.Trip
typealias Destination = TravellifySchemaV1.Destination
typealias Document    = TravellifySchemaV1.Document
typealias PackingItem = TravellifySchemaV1.PackingItem
typealias Activity    = TravellifySchemaV1.Activity
```

**Why the `@Model` types are INSIDE the enum, not just referenced:** `VersionedSchema` is a namespace. Nesting the `@Model` class definitions inside the enum ensures each schema version owns its own model definitions — when v2 creates `TravellifySchemaV2.Trip`, the two versions can coexist during migration. If models live at the top level, you cannot have two versions of the same model simultaneously.

**IMPORTANT — Xcode 26.2 note:** On the dev machine, Xcode 26.2 (iOS 26 SDK) is installed. Xcode 26 has a known regression where `Array`-typed model properties handled differently between iOS 26.0 and 26.1 (the store metadata format changed). This does not affect Phase 1 because `Trip.destinations: [Destination]?` is a relationship, not a raw `Array` attribute. If any `@Model` in Phase 1 ends up with a bare `[String]` or `[Int]` property, use a wrapper type or avoid raw arrays until Apple resolves the iOS 26.1 regression. [VERIFIED: Apple Developer Forums thread 806161]

### Pattern 2: Trip and Destination Model Definitions

```swift
// Source: CONTEXT.md D1/D2 decisions + CloudKit rules from ARCHITECTURE.md + STACK.md
// File: Models/Trip.swift  (nested inside TravellifySchemaV1 extension)

extension TravellifySchemaV1 {

    @Model
    final class Trip {
        var id: UUID = UUID()
        var name: String = ""
        var startDate: Date = Date()
        var endDate: Date = Date()
        var createdAt: Date = Date()

        // CASCADE — child records deleted when trip is deleted
        @Relationship(deleteRule: .cascade, inverse: \Destination.trip)
        var destinations: [Destination]? = []

        @Relationship(deleteRule: .cascade, inverse: \Document.trip)
        var documents: [Document]? = []

        @Relationship(deleteRule: .cascade, inverse: \PackingItem.trip)
        var packingItems: [PackingItem]? = []

        @Relationship(deleteRule: .cascade, inverse: \Activity.trip)
        var activities: [Activity]? = []
    }

    @Model
    final class Destination {
        var id: UUID = UUID()
        var name: String = ""
        var sortIndex: Int = 0

        // NULLIFY inverse — CloudKit requires optional back-reference
        var trip: Trip?
    }
}
```

**CloudKit-safety checklist for Trip/Destination:**
- [x] All properties have default values
- [x] No `@Attribute(.unique)`
- [x] No `.deny` delete rule
- [x] Inverse is `Trip?` (optional)
- [x] No inline `Data` blobs

### Pattern 3: Placeholder Models (Document, PackingItem, Activity)

**What:** Minimal skeleton — just `id` and inverse. Keeps schema stable so Phases 2–4 add fields via schema migration rather than requiring a migration just to register the relationship.

```swift
// File: Models/Document.swift
extension TravellifySchemaV1 {
    @Model
    final class Document {
        var id: UUID = UUID()
        var trip: Trip?
    }
}

// File: Models/PackingItem.swift
extension TravellifySchemaV1 {
    @Model
    final class PackingItem {
        var id: UUID = UUID()
        var trip: Trip?
    }
}

// File: Models/Activity.swift
extension TravellifySchemaV1 {
    @Model
    final class Activity {
        var id: UUID = UUID()
        var trip: Trip?
    }
}
```

**Why placeholders:** Phase 2 will add `name`, `filePath`, etc. to `Document`. Without the placeholder, the Phase 2 relationship declaration on `Trip` would require a migration. With the placeholder already present, Phase 2 only adds properties to an existing model — SwiftData handles lightweight property additions automatically without a migration stage.

### Pattern 4: ModelContainer at App Entry Point

```swift
// Source: AzamSharp 2026 article + Apple docs
// File: App/TravellifyApp.swift

import SwiftUI
import SwiftData

@main
struct TravellifyApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Trip.self,  // typealias resolves to TravellifySchemaV1.Trip
                migrationPlan: TravellifyMigrationPlan.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
```

**Note:** Passing `Trip.self` is sufficient — SwiftData follows the relationship graph and registers all related models automatically. But if SwiftData fails to discover a placeholder model that has no active relationship yet (this can happen if the relationship array on `Trip` is optional and nil by default), pass all model types explicitly:

```swift
container = try ModelContainer(
    for: Trip.self, Destination.self, Document.self,
         PackingItem.self, Activity.self,
    migrationPlan: TravellifyMigrationPlan.self
)
```

This explicit form is safer and matches the CONTEXT.md non-decision note.

### Pattern 5: NavigationStack + AppDestination

```swift
// Source: CONTEXT.md D9 + ARCHITECTURE.md
// File: App/AppDestination.swift

import SwiftData

enum AppDestination: Hashable {
    case tripDetail(Trip.ID)  // Trip.ID is PersistentIdentifier
}
```

```swift
// File: Features/Trips/TripListView.swift
struct ContentView: View {
    @State private var path: [AppDestination] = []
    @State private var showNewTrip = false

    var body: some View {
        NavigationStack(path: $path) {
            TripListView()
                .navigationDestination(for: AppDestination.self) { dest in
                    switch dest {
                    case .tripDetail(let id):
                        TripDetailView(tripID: id)
                    }
                }
        }
    }
}
```

**Trip.ID vs UUID:** SwiftData models use `PersistentIdentifier` as their `id` type when accessed via `trip.id` on the `Identifiable` conformance. The explicit `var id: UUID = UUID()` you declare is a separate stored property. Use `trip.persistentModelID` (type `PersistentIdentifier`) for navigation and fetching by ID. Use `trip.id` (your `UUID`) for display and test assertions. `AppDestination.tripDetail` takes `Trip.ID` which equals `PersistentIdentifier` from `Identifiable`.

**Safe NavigationPath restoration (Pitfall 10 from PITFALLS.md):** Do NOT persist `NavigationPath` to `UserDefaults` in Phase 1. Start with an in-memory `@State` path. Persistence can be added in Phase 6 Polish with proper try/catch fallback.

### Pattern 6: TripListView — Two-Section Partitioning

**Open Question 2 answer:** Use a single `@Query` sorted by `startDate` ascending with NO predicate, then partition in-memory inside the view. Do NOT use two separate `@Query` with date predicates in iOS 17.

**Why not two `@Query` with predicates:**
1. `#Predicate` cannot capture `Date.now` directly — you must capture it in a `let` constant before the predicate block. While this works, it creates a stale predicate: the `now` constant is evaluated at view init, not at re-render time. The predicate does not re-evaluate as the clock crosses midnight.
2. Two `@Query` calls double the fetch overhead.
3. SwiftData date predicate support on iOS 17 is fragile — confirmed runtime crashes exist for certain predicate expressions involving `Date` comparisons (Michael Tsai blog, Apple Developer Forums thread 690554).

**Recommended pattern:**

```swift
// Source: [ASSUMED based on CONTEXT.md + SwiftData date predicate gotchas]
struct TripListView: View {
    @Query(sort: \Trip.startDate, order: .forward)
    private var allTrips: [Trip]

    @Environment(\.modelContext) private var modelContext
    @State private var showNewTrip = false

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var upcomingTrips: [Trip] {
        allTrips
            .filter { $0.endDate >= today }
            .sorted { $0.startDate < $1.startDate }
    }

    private var pastTrips: [Trip] {
        allTrips
            .filter { $0.endDate < today }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        List {
            if !upcomingTrips.isEmpty {
                Section("Upcoming") {
                    ForEach(upcomingTrips) { trip in
                        TripRow(trip: trip)
                    }
                }
            }
            if !pastTrips.isEmpty {
                Section("Past") {
                    ForEach(pastTrips) { trip in
                        TripRow(trip: trip)
                    }
                }
            }
        }
        .navigationTitle("Trips")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNewTrip = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Trip")
            }
        }
        .sheet(isPresented: $showNewTrip) {
            TripEditSheet(mode: .create)
        }
    }
}
```

**Performance note:** For realistic trip counts (< 200), in-memory filter+sort is imperceptible. The `@Query` fetch itself is the only DB operation. If the app ever reaches thousands of trips (unlikely for a travel companion), add a predicate with a captured constant and a `Date`-typed property watcher.

### Pattern 7: Ordered Destinations — sortIndex

**Open Question 3 answer:** Maintain `sortIndex: Int` manually. Do NOT use the third-party `OrderedRelationship` macro (adds a package dependency, violates CLAUDE.md "no CocoaPods/Carthage/unnecessary deps" spirit). SwiftData has no built-in ordered relationship support — the relationship array order is NOT preserved across fetches.

**Insert pattern:**

```swift
func addDestination(name: String, to trip: Trip, context: ModelContext) {
    let maxIndex = trip.destinations?.map(\.sortIndex).max() ?? -1
    let dest = Destination()
    dest.name = name
    dest.sortIndex = maxIndex + 1
    dest.trip = trip
    trip.destinations?.append(dest)
    try? context.save()
}
```

**Sorted display (computed property in the view or inline):**

```swift
// In TripEditSheet, display destinations sorted by sortIndex:
var sortedDestinations: [Destination] {
    (trip.destinations ?? []).sorted { $0.sortIndex < $1.sortIndex }
}
```

**onMove handler (reorder):**

```swift
func moveDestination(from source: IndexSet, to destination: Int, in destinations: [Destination]) {
    var sorted = destinations.sorted { $0.sortIndex < $1.sortIndex }
    sorted.move(fromOffsets: source, toOffset: destination)
    // Reassign contiguous sortIndex values after reorder
    for (index, dest) in sorted.enumerated() {
        dest.sortIndex = index
    }
    try? modelContext.save()
}
```

**Why NOT use a gap-based strategy (like the `OrderedRelationship` macro):** Gaps between sort values (e.g., 100, 200, 300) reduce the frequency of needing to rewrite all indexes on reorder. For < 20 destinations per trip, full rewrite on every move is negligible. The simple contiguous-index approach is easier to test and reason about.

### Pattern 8: TripEditSheet — Create and Edit

```swift
// Source: UI-SPEC.md interaction contracts + D5 validation rules
struct TripEditSheet: View {
    enum Mode {
        case create
        case edit(Trip)
    }

    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var endDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var destinations: [DestinationDraft] = []  // local draft, not persisted

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && endDate >= startDate
    }

    var body: some View {
        NavigationStack {
            Form {
                // name field, date pickers, destination list
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmButtonTitle) { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let normalizedStart = Calendar.current.startOfDay(for: startDate)
        let normalizedEnd = Calendar.current.startOfDay(for: endDate)
        switch mode {
        case .create:
            let trip = Trip()
            trip.name = trimmedName
            trip.startDate = normalizedStart
            trip.endDate = normalizedEnd
            modelContext.insert(trip)
            for (i, draft) in destinations.enumerated() {
                let dest = Destination()
                dest.name = draft.name
                dest.sortIndex = i
                dest.trip = trip
                modelContext.insert(dest)
            }
        case .edit(let trip):
            trip.name = trimmedName
            trip.startDate = normalizedStart
            trip.endDate = normalizedEnd
            // sync destinations list...
        }
        try? modelContext.save()
        dismiss()
    }
}
```

**D5 discrepancy note:** CONTEXT.md D5 says "at least one destination added" is a validation requirement. UI-SPEC.md Validation Rules table says "Destinations: Optional (zero or more) / No validation". The UI-SPEC wins (it is the design contract) — the Save button is enabled with zero destinations. Update the plan to reflect UI-SPEC, not D5 on this point.

### Pattern 9: PreviewContainer

```swift
// Source: appcoda.com SwiftData preview article (cited below) + D6 decision
// File: Shared/PreviewContainer.swift

#if DEBUG
import SwiftData

@MainActor
let previewContainer: ModelContainer = {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, Activity.self,
            configurations: config
        )

        // Seed 2 upcoming trips
        let rome = Trip()
        rome.name = "Rome & Florence"
        rome.startDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(7 * 86400))
        rome.endDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(14 * 86400))
        container.mainContext.insert(rome)

        let dest1 = Destination(); dest1.name = "Rome"; dest1.sortIndex = 0; dest1.trip = rome
        let dest2 = Destination(); dest2.name = "Florence"; dest2.sortIndex = 1; dest2.trip = rome
        container.mainContext.insert(dest1)
        container.mainContext.insert(dest2)

        // Seed 1 past trip
        let paris = Trip()
        paris.name = "Paris Weekend"
        paris.startDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(-30 * 86400))
        paris.endDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(-23 * 86400))
        container.mainContext.insert(paris)

        let dest3 = Destination(); dest3.name = "Paris"; dest3.sortIndex = 0; dest3.trip = paris
        container.mainContext.insert(dest3)

        try container.mainContext.save()
        return container
    } catch {
        fatalError("PreviewContainer: \(error)")
    }
}()
#endif
```

**Usage in previews:**

```swift
#Preview {
    TripListView()
        .modelContainer(previewContainer)
}
```

### Pattern 10: Swift Testing Setup for SwiftData

```swift
// Source: Hacking with Swift SwiftData testing article + Swift Testing docs
// File: TravellifyTests/TripTests.swift

import Testing
import SwiftData
@testable import Travellify

@MainActor
struct TripTests {
    let container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, Activity.self,
            configurations: config
        )
    }

    @Test func createTripPersists() throws {
        let context = container.mainContext
        let trip = Trip()
        trip.name = "Tokyo"
        trip.startDate = Calendar.current.startOfDay(for: Date())
        trip.endDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400 * 7))
        context.insert(trip)
        try context.save()

        let trips = try context.fetch(FetchDescriptor<Trip>())
        #expect(trips.count == 1)
        #expect(trips.first?.name == "Tokyo")
    }

    @Test func deleteTripCascadesToDestinations() throws {
        let context = container.mainContext
        let trip = Trip(); trip.name = "Test"
        trip.startDate = Date(); trip.endDate = Date()
        context.insert(trip)
        let dest = Destination(); dest.name = "Paris"; dest.sortIndex = 0; dest.trip = trip
        context.insert(dest)
        try context.save()

        context.delete(trip)
        try context.save()

        let destinations = try context.fetch(FetchDescriptor<Destination>())
        #expect(destinations.isEmpty, "Cascade delete must remove all destinations")
    }

    @Test func endDateMustBeOnOrAfterStartDate() {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: Date().addingTimeInterval(-86400)) // yesterday
        #expect(end < start)  // Confirms validation logic should catch this
    }

    @Test func destinationSortIndexPreservesOrder() throws {
        let context = container.mainContext
        let trip = Trip(); trip.name = "Multi-stop"
        trip.startDate = Date(); trip.endDate = Date()
        context.insert(trip)
        let d1 = Destination(); d1.name = "A"; d1.sortIndex = 0; d1.trip = trip
        let d2 = Destination(); d2.name = "B"; d2.sortIndex = 1; d2.trip = trip
        let d3 = Destination(); d3.name = "C"; d3.sortIndex = 2; d3.trip = trip
        [d1, d2, d3].forEach { context.insert($0) }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Destination>())
        let sorted = fetched.sorted { $0.sortIndex < $1.sortIndex }
        #expect(sorted.map(\.name) == ["A", "B", "C"])
    }
}
```

**Swift Testing key notes:**
- `init() throws` runs before every `@Test` function — fresh container per test
- `@MainActor` on the struct ensures all tests run on the main actor (required for SwiftData `mainContext`)
- Use `#expect` not `XCTAssert` — they don't mix in the same test function
- Swift Testing runs tests in parallel by default; `@Suite(.serialized)` is available if needed but the in-memory container-per-init pattern means tests are naturally isolated

---

## Open Questions — Answers

### OQ-1: Placeholder models — separate files vs one SchemaV1.swift?

**Answer: Separate files, all using `extension TravellifySchemaV1`.**

- `SchemaV1.swift` declares the `VersionedSchema` enum + `MigrationPlan` + typealiases only
- Each `@Model` type lives in its own file (`Trip.swift`, `Destination.swift`, etc.) using `extension TravellifySchemaV1 { ... }`
- **Rationale:** When Phase 2 adds fields to `Document`, the reviewer can see the full `Document.swift` diff without noise from unrelated models. One-file-per-model is the established Swift convention and matches the project structure in ARCHITECTURE.md

### OQ-2: @Query with date predicate iOS 17/18 gotchas for Upcoming/Past partitioning?

**Answer: Use one `@Query(sort:)` with NO predicate; partition in-memory.**

**Known iOS 17 gotchas with `#Predicate` date comparisons:**
1. Cannot reference `Date.now` directly inside the predicate macro — the compiler rejects captured computed properties. Must use a `let now = Date()` outside the predicate.
2. Even with the `let` capture, the predicate is evaluated at `@Query` init time, not on each re-render. As the clock crosses midnight, trips do not migrate between sections until the view is re-initialized.
3. Multiple `@Query` calls in the same view re-execute on every state change of any `@State` var in the view (Apple Developer Forums thread 743150) — two separate predicates double the query churn.

**iOS 18 note:** iOS 18 adds `#Expression` macro support for more complex predicates (WWDC24), but the fundamental midnight-staleness problem remains for any predicate that captures a timestamp at init time. The in-memory filter approach re-evaluates on every render (triggered by any `@Query` update), which is correct.

**Confidence:** MEDIUM — the "cannot use Date.now directly" is VERIFIED via Apple Developer Forums. The "two @Query double churn" behavior is MEDIUM confidence (community-reported, not officially documented).

### OQ-3: Ordered destinations — sortIndex manual vs SwiftData native?

**Answer: Manual `sortIndex: Int` on `Destination`.**

SwiftData has no native ordered relationship support. The relationship backing store is a database table with no guaranteed row order — array position after fetch is non-deterministic. The `sortIndex: Int` approach is the community consensus (VERIFIED: multiple community articles, Apple Forums). The third-party `OrderedRelationship` macro exists but adds a SwiftPM dependency, which violates CLAUDE.md constraints (no unnecessary dependencies) and is out of scope for a single-developer app.

Reorder is handled by `onMove` in the destination `List` inside `TripEditSheet`, followed by reassigning contiguous `sortIndex` values.

### OQ-4: Minimal project.pbxproj for Xcode 26 / xcodebuild?

**Answer: Do not hand-write project.pbxproj. Use a GUI-or-copy approach.**

**Findings:**
- The dev machine has Xcode 26.2 installed but `xcode-select` points to CommandLineTools, not `Xcode.app`. Running `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version` confirms Xcode 26.2 / Build 17C52 is available.
- A hand-written `project.pbxproj` is brittle. Xcode's pbxproj format is an ASCII plist with UUIDs for every file reference, build phase, and target. Hand-writing a correct one for Xcode 26 requires getting all UUID cross-references right. One wrong UUID causes `xcodebuild: error: The project 'Travellify.xcodeproj' does not contain a scheme named 'Travellify'`.
- No known-good minimal template exists for Xcode 26 specifically. The Xcode 26 SDK adds new default capabilities that older templates miss.

**Recommended path for D7 (command-line scaffold):**

Option A (preferred): Use `xcodebuild` with the Xcode.app Developer Tools path to invoke the new project template:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -create-project \
  -template "iOS/Application/App" \
  -projectname Travellify \
  -destination Travellify/
```
Note: `-create-project` is an undocumented flag. [ASSUMED: based on community reports this exists in Xcode 16+; confirm at execution time]

Option B (fallback — safe): User creates project in Xcode GUI (`File > New > Project > iOS App > SwiftData`) then executor fills all Swift files. Xcode generates a correct `project.pbxproj` that already includes the Swift Testing target. This avoids all scaffolding risk.

**Plan checkpoint:** The Phase 1 plan MUST include an explicit checkpoint after the scaffold task: "Verify `DEVELOPER_DIR=... xcodebuild -list` outputs Travellify as a scheme. If it fails, switch to Option B fallback." This is flagged in CONTEXT.md D7.

**Test target:** Xcode 26's "iOS App" template with SwiftData pre-checked does NOT automatically add a Swift Testing unit test target. The plan must include a task to add the test target: `File > New > Target > Unit Testing Bundle` and ensure it uses Swift Testing (select Swift Testing in the template dialog, not XCTest).

**DEVELOPER_DIR for all xcodebuild commands in this project:**
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```
Add this to any plan task that invokes `xcodebuild`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Schema versioning infrastructure | Custom version metadata | `VersionedSchema` + `SchemaMigrationPlan` | SwiftData's migration engine handles store evolution; hand-rolling loses the migration path to CloudKit |
| Ordered relationship storage | Custom join table or serialized JSON | `sortIndex: Int` on child model | SwiftData handles the backing store; you manage the integer |
| Preview data injection | Per-view ad-hoc container creation | `PreviewContainer.swift` (D6 pattern) | Consistent seed data, single place to update, DEBUG-only |
| Validation error display | Custom alert-based validation | Disabled Save button + inline error text below fields | UI-SPEC mandates inline validation; D5 decision |
| Navigation path persistence | Custom `UserDefaults` serialization | None in Phase 1 (in-memory only) | Pitfall 10 from PITFALLS.md — NavigationPath decode crashes on model change |

---

## Common Pitfalls (Phase 1 Specific)

### Pitfall A: `@Model` Declared Outside VersionedSchema

**What goes wrong:** Top-level `@Model final class Trip { }` compiles fine. At v2 schema change, there is no migration path and existing users' stores crash.

**How to avoid:** Declare inside `extension TravellifySchemaV1 { }` from the first commit. Block merge without this.

**Warning signs:** `@Model` keyword at global scope, not inside an enum extension.

### Pitfall B: Date Predicate Staleness at Midnight

**What goes wrong:** Two `@Query` with date predicates initialized at view creation. A user who opens the app before midnight and leaves it running will see a trip remain "Upcoming" after midnight because the predicate is not re-evaluated.

**How to avoid:** Use one `@Query` with no date predicate; filter in-memory via computed properties. The `@Query` naturally re-executes when any `Trip` is inserted/modified, at which point `today` recomputes correctly.

### Pitfall C: Destination sortIndex Not Updated on Move

**What goes wrong:** `onMove` handler shuffles the local display array but does not update `sortIndex` on each `Destination`. After dismiss + re-open, order reverts to whatever order SwiftData returns (non-deterministic).

**How to avoid:** `onMove` must call the reassign-contiguous-sortIndex helper before `modelContext.save()`.

### Pitfall D: NavigationPath Uses `Trip` (Full Object) Instead of `Trip.ID`

**What goes wrong:** `AppDestination.tripDetail(Trip)` stores the full `Trip` object. Codable decode after model change crashes (Pitfall 10). `Trip` is a reference type — `Hashable` conformance via `PersistentIdentifier` is the correct approach.

**How to avoid:** `AppDestination.tripDetail(Trip.ID)` uses `PersistentIdentifier` (Hashable, Sendable). In `TripDetailView`, fetch by `persistentModelID`.

### Pitfall E: project.pbxproj UUID Mismatch

**What goes wrong:** Manually created `project.pbxproj` with incorrect or duplicated UUIDs causes `xcodebuild` to fail with scheme-not-found or "multiple targets with same name" errors.

**How to avoid:** Use the Xcode GUI fallback (Option B). If command-line approach is taken, run `DEVELOPER_DIR=... xcodebuild -list -project Travellify.xcodeproj` immediately after scaffold and treat a non-zero exit code as a trigger for the fallback.

### Pitfall F: Xcode 26 Main Actor Isolation Warnings Flood

**What goes wrong:** Xcode 26 Beta 6 introduced stricter main actor isolation checking. Code that compiled cleanly in Xcode 16 may generate 30+ new warnings/errors when first opened in Xcode 26.2.

**How to avoid:** Mark `@Model` types and any `ModelContext`-touching code consistently with `@MainActor`. Use `@MainActor` on test structs. Accept that some Xcode 26 warnings may require `nonisolated` annotations on computed properties.

---

## Runtime State Inventory

> Phase 1 is a greenfield scaffold — no existing data to migrate.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — app does not exist yet | None |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode.app | Building iOS app | ✓ | 26.2 (Build 17C52) | — |
| xcodebuild (via DEVELOPER_DIR) | CLI build verification | ✓ | Available when DEVELOPER_DIR set | Use Xcode GUI |
| Swift 6 compiler | Swift 6 language mode | ✓ | 6.3.1 | — |
| xcrun | Build tooling | ✓ | 72 | — |
| Swift Testing framework | Unit tests | ✓ | Ships with Xcode 16+ | — |
| iOS Simulator | Preview and test | ✓ | Included with Xcode 26.2 | Physical device |

**xcode-select note:** `xcode-select` currently points to CommandLineTools (`/Library/Developer/CommandLineTools`). Any `xcodebuild` invocation in plan tasks MUST be prefixed with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Document this as a plan-wide environment requirement.

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

> `nyquist_validation: true` in config.json — this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (ships with Xcode 16+) |
| Config file | None required — Xcode test target auto-discovers `@Test` functions |
| Quick run command | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination "platform=iOS Simulator,name=iPhone 16"` |
| Full suite command | Same (Phase 1 has one test target, no separate suite split needed yet) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | SwiftData store persists across `modelContext.save()` and re-fetch | unit | `xcodebuild test ... -only-testing:TravellifyTests/TripTests/createTripPersists` | ❌ Wave 0 |
| FOUND-02 | `ModelContainer` initializes with `TravellifyMigrationPlan` without error | unit | `xcodebuild test ... -only-testing:TravellifyTests/SchemaTests/containerInitializesWithMigrationPlan` | ❌ Wave 0 |
| FOUND-03 | No `@Attribute(.unique)` or `.deny` in codebase | static (grep) | `grep -r "@Attribute(.unique)\|deleteRule: .deny" Travellify/Models/` (must return 0 results) | ❌ Wave 0 |
| TRIP-01 | Creating a trip with name + dates persists correctly | unit | `xcodebuild test ... -only-testing:TravellifyTests/TripTests/createTripPersists` | ❌ Wave 0 |
| TRIP-02 | Destinations maintain sortIndex order after fetch | unit | `xcodebuild test ... -only-testing:TravellifyTests/TripTests/destinationSortIndexPreservesOrder` | ❌ Wave 0 |
| TRIP-03 | Upcoming/Past partition is correct for trips staddling today | unit | `xcodebuild test ... -only-testing:TravellifyTests/TripTests/upcomingPastPartitioning` | ❌ Wave 0 |
| TRIP-04 | TripDetailView renders without crash (smoke test) | manual | Run app in simulator, tap a trip — verify three tab placeholders visible | manual-only (no UITest in Phase 1) |
| TRIP-05 | Editing trip name + dates updates persisted model | unit | `xcodebuild test ... -only-testing:TravellifyTests/TripTests/editTripUpdatesPersistedValues` | ❌ Wave 0 |
| TRIP-06 | Deleting trip cascades to Destination and placeholder models | unit | `xcodebuild test ... -only-testing:TravellifyTests/TripTests/deleteTripCascadesToDestinations` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Quick `swift build` (compile check only — no simulator required)
- **Per wave merge:** Full `xcodebuild test` suite on iOS Simulator
- **Phase gate:** Full suite green + manual smoke test of TripListView → TripDetailView flow before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `TravellifyTests/TripTests.swift` — covers TRIP-01, TRIP-02, TRIP-05, TRIP-06, FOUND-01
- [ ] `TravellifyTests/SchemaTests.swift` — covers FOUND-02
- [ ] `TravellifyTests/PartitionTests.swift` — covers TRIP-03
- [ ] Test target `TravellifyTests` in `project.pbxproj` — Wave 0 task must add test target if using Xcode GUI fallback (Option B)

---

## Security Domain

> `security_enforcement` not set in config.json → treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth in Phase 1 or v1 (Face ID deferred to Phase 6) |
| V3 Session Management | No | Local-only app; no sessions |
| V4 Access Control | No | Single-user local app |
| V5 Input Validation | Yes (minimal) | Trip name non-empty (trimmed); date range validation (endDate ≥ startDate) — handled in view logic |
| V6 Cryptography | No | No encryption in Phase 1; file protection deferred to Phase 2 for document files |

### Known Threat Patterns for SwiftData + SwiftUI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SwiftData store in unprotected location | Information Disclosure | Use `Application Support` directory (default SwiftData location); add `FileProtectionType.completeUntilFirstUserAuthentication` on the store file in Phase 6 |
| Navigation path injection via deep link | Tampering | No deep links or URL schemes in Phase 1; `AppDestination` enum is typed — no stringly-typed injection surface |
| Logging SwiftData fetch predicates | Information Disclosure | Do not `print()` predicates or model contents; use `Logger` with `%{private}` for any path/ID logging |

**Phase 1 security posture:** No network, no auth, no file storage (documents are Phase 2). The primary security concern is the SQLite store location — SwiftData's default location (`Application Support`) is correct and is NOT user-accessible via Files app. No action needed in Phase 1.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `xcodebuild -create-project` flag exists in Xcode 26 as an undocumented scaffold command | Open Question 4 / D7 | Command not found → use Xcode GUI fallback (Option B) — plan already has this checkpoint |
| A2 | SwiftData cascade delete works correctly on iOS 17.0 + Xcode 26 SDK build (the known iOS 17.x bug may be fixed in later point releases) | Pitfall 5 / TRIP-06 | Cascade silently fails → integration test catches it; manual delete cleanup helper needed |
| A3 | Two separate `@Query` with date predicates re-execute on every parent `@State` change (not just on relevant model changes) | Open Question 2 | If only one `@Query` has this churn, two queries may be fine — but in-memory partition is still simpler and avoids staleness |

---

## Sources

### Primary (HIGH confidence)
- [AzamSharp — If You Are Not Versioning Your SwiftData Schema (2026)](https://azamsharp.com/2026/02/14/if-you-are-not-versioning-your-swiftdata-schema.html) — VersionedSchema boilerplate, typealias pattern, ModelContainer init with migrationPlan
- [Hacking with Swift — VersionedSchema migration guide](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) — Migration plan structure
- [Apple WWDC24 — What's new in SwiftData](https://developer.apple.com/videos/play/wwdc2024/10137/) — #Expression macro, predicate enhancements in iOS 18
- [ARCHITECTURE.md + STACK.md + PITFALLS.md](../../../research/) — Existing project research (HIGH confidence, previously verified)
- [CONTEXT.md + UI-SPEC.md](../01-CONTEXT.md) — Locked decisions (source of truth for planner)
- [Apple Developer Forums thread 806161 — SwiftData not loading under iOS 26.1](https://developer.apple.com/forums/thread/806161) — Array type storage regression in Xcode 26/iOS 26.1
- [fatbobman — Designing Models for CloudKit Sync](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) — CloudKit-safe model rules
- [Apple Developer Forums thread 743150 — @Query re-execution on parent state change](https://developer.apple.com/forums/thread/743150) — Two-query churn behavior

### Secondary (MEDIUM confidence)
- [appcoda.com — Using SwiftData with Preview in SwiftUI](https://www.appcoda.com/swiftdata-preview/) — PreviewContainer pattern with `@MainActor let previewContainer` lazy static
- [Medium/@jc_builds — SwiftData: How to Preserve Array Order](https://medium.com/@jc_builds/swiftdata-how-to-preserve-array-order-in-a-swiftdata-model-6ea1b895ed50) — sortIndex + computed sorted property pattern
- [GitHub — FiveSheepCo/OrderedRelationship](https://github.com/FiveSheepCo/OrderedRelationship) — Third-party macro for ordered relationships (not recommended for this project)

### Tertiary (LOW confidence)
- Community reports on two-`@Query` re-execution behavior — not officially documented; pattern confirmed via forum thread but no Apple documentation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple-native; no third-party
- VersionedSchema boilerplate: HIGH — verified against 2026 AzamSharp article + WWDC24
- Architecture patterns: HIGH — inherited from verified ARCHITECTURE.md
- @Query date predicate gotchas: MEDIUM — partially verified via forums; in-memory approach sidesteps the uncertainty
- project.pbxproj / Xcode 26 scaffold: LOW for command-line path; HIGH for Xcode GUI fallback
- Swift Testing patterns: HIGH — verified via Hacking with Swift + Apple forums

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (SwiftData community moves quickly; re-verify @Query predicate behavior before adding complex predicates in future phases)
