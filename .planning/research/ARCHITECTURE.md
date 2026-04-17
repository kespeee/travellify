# Architecture Research

**Domain:** iOS Travel Companion App — SwiftUI + SwiftData, local-only v1 with CloudKit-ready design
**Researched:** 2026-04-18
**Confidence:** HIGH (official Apple docs + verified community sources)

---

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         SwiftUI Views                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │  Trips   │  │Documents │  │ Packing  │  │Activities│        │
│  │  Feature │  │ Feature  │  │ Feature  │  │ Feature  │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
├───────┴──────────────┴────────────┴──────────────┴──────────────┤
│                     @Observable ViewModels                        │
│   TripListVM   DocumentVM   PackingVM   ActivityVM               │
├─────────────────────────────────────────────────────────────────┤
│                       Services Layer                              │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────────┐  │
│  │ FileStorage  │  │ Notification  │  │  ScanImport          │  │
│  │  Service     │  │   Service     │  │  Service (VisionKit) │  │
│  └──────────────┘  └───────────────┘  └──────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                       SwiftData Layer                             │
│  ┌──────┐  ┌─────────────┐  ┌────────────┐  ┌────────────────┐  │
│  │ Trip │  │ Destination │  │  Document  │  │   Activity     │  │
│  └──────┘  └─────────────┘  └────────────┘  └────────────────┘  │
│  ┌─────────────────┐  ┌─────────────────────┐                    │
│  │ PackingCategory │  │    PackingItem       │                    │
│  └─────────────────┘  └─────────────────────┘                    │
│                     ModelContainer / ModelContext                  │
├─────────────────────────────────────────────────────────────────┤
│                       File System Layer                           │
│  ~/Documents/Travellify/documents/   (PDF, image blobs)          │
│  ~/Documents/Travellify/photos/      (activity photos)           │
└─────────────────────────────────────────────────────────────────┘
```

---

## SwiftData Model Graph

### Model Definitions with Relationships

```swift
// Root aggregate — all content scoped under a Trip
@Model
class Trip {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date

    // CASCADE: deleting a Trip wipes all its children
    @Relationship(deleteRule: .cascade, inverse: \.trip)
    var destinations: [Destination]

    @Relationship(deleteRule: .cascade, inverse: \.trip)
    var documents: [TravelDocument]

    @Relationship(deleteRule: .cascade, inverse: \.trip)
    var packingCategories: [PackingCategory]

    @Relationship(deleteRule: .cascade, inverse: \.trip)
    var activities: [Activity]
}

@Model
class Destination {
    var id: UUID
    var name: String           // "Rome", "Paris"
    var order: Int             // display order within trip
    var trip: Trip?            // NULLIFY inverse (CloudKit requires optional)
}

@Model
class TravelDocument {
    var id: UUID
    var name: String
    var fileExtension: String  // "pdf", "jpg", "png"
    var filePath: String       // relative path under Documents/Travellify/documents/
    var createdAt: Date
    var trip: Trip?            // NULLIFY inverse
}

@Model
class PackingCategory {
    var id: UUID
    var name: String           // "Toiletries", "Electronics"
    var order: Int

    @Relationship(deleteRule: .cascade, inverse: \.category)
    var items: [PackingItem]

    var trip: Trip?            // NULLIFY inverse
}

@Model
class PackingItem {
    var id: UUID
    var name: String
    var isChecked: Bool
    var order: Int
    var category: PackingCategory?   // NULLIFY inverse
}

@Model
class Activity {
    var id: UUID
    var title: String
    var date: Date
    var locationName: String?
    var notes: String?
    var notificationEnabled: Bool
    var notificationID: String?      // UNNotificationRequest identifier

    // Photo file paths stored as [String], not blobs
    var photoPaths: [String]         // relative paths under Documents/Travellify/photos/

    var trip: Trip?                  // NULLIFY inverse
}
```

### Delete Rules — Decision Table

| Relationship | Rule | Rationale |
|---|---|---|
| Trip → Destination | `.cascade` | Destinations have no meaning outside a trip |
| Trip → TravelDocument | `.cascade` | Also removes the file from disk in model lifecycle hook |
| Trip → PackingCategory | `.cascade` | Category list is trip-specific |
| PackingCategory → PackingItem | `.cascade` | Items belong to one category only |
| Trip → Activity | `.cascade` | Activities are trip-scoped |
| Destination.trip | `.nullify` | CloudKit requires optional inverse; nullify is safe |
| TravelDocument.trip | `.nullify` | Same |
| PackingCategory.trip | `.nullify` | Same |
| PackingItem.category | `.nullify` | Category may be deleted before item in some flows |
| Activity.trip | `.nullify` | Same |

**Cascade bug note (HIGH confidence):** There is a known SwiftData bug on some iOS 17.x versions where cascade delete silently fails when the inverse relationship is declared. Workaround: test cascade behavior in integration tests on device, and add a manual cleanup pass in the delete helper if cascade is not observed.

### CloudKit-readiness constraints baked in from day one

- All inverse relationship properties are `Optional` (`Trip?`, `PackingCategory?`)
- No `@Attribute(.unique)` on any model property — uniqueness enforced in app logic instead
- All non-optional properties have default values or are set at init
- `photoPaths` is `[String]` (not `[Data]`) — CloudKit handles `String` arrays but not arbitrary blobs
- No `@Attribute(.externalStorage)` — file references only, not inline blobs

---

## File Storage Architecture

### Strategy: File references, not blobs

Store only relative **file paths** in SwiftData. Binary data lives on disk in a predictable directory structure. This is the correct approach for:

- Large files (passport PDF scans, multi-photo activities) that would bloat the SQLite store
- CloudKit readiness — CloudKit CKRecord fields cannot hold arbitrary large blobs; CKAsset is a separate mechanism
- Memory safety — images loaded on demand, not all at app launch

### Directory Layout

```
~/Documents/Travellify/
    documents/
        <tripID>/
            <documentID>.pdf
            <documentID>.jpg
    photos/
        <tripID>/
            <activityID>/
                <photoID>.jpg
```

All paths stored in SwiftData are **relative** (e.g., `documents/<tripID>/<documentID>.pdf`). The app resolves them against the Documents directory at runtime. This survives app reinstalls that change the sandbox base path.

### FileStorageService

```swift
// Thin service — knows nothing about SwiftData models
struct FileStorageService {
    static let baseURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Travellify")

    func saveDocument(_ data: Data, tripID: UUID, documentID: UUID, ext: String) throws -> String
    func savePhoto(_ data: Data, tripID: UUID, activityID: UUID, photoID: UUID) throws -> String
    func fileURL(forRelativePath path: String) -> URL
    func deleteFile(atRelativePath path: String) throws
}
```

The service is called from the ViewModel — never from the SwiftData model itself. On Trip delete, the ViewModel cascade-deletes SwiftData records first, then calls `FileStorageService.deleteFile` for each document and photo path before committing the context.

### v2 CloudKit migration note

In v2, swap document/photo storage to `CKAsset` uploaded through `CKSyncEngine`. The relative path field in `TravelDocument.filePath` becomes either a CKRecord asset field reference or a CKAsset URL. The SwiftData model schema stays unchanged — only the service layer changes.

---

## Navigation Architecture

### Pattern: NavigationStack (iPhone-only, v1)

Use `NavigationStack` with a typed `NavigationPath` for all in-app navigation. `NavigationSplitView` is correct for iPad/macOS adaptive layouts — iPhone-only apps do not benefit from it and it adds unnecessary complexity.

```
App root
  └── NavigationStack (path: NavigationPath)
        ├── TripListView                     [root]
        │     └── TripDetailView             [push on trip tap]
        │           ├── DocumentListView     [tab or section]
        │           ├── PackingListView      [tab or section]
        │           └── ActivityListView     [tab or section]
        │                 └── ActivityDetailView  [push on activity tap]
        └── Sheets / fullScreenCovers for:
              - NewTripSheet
              - DocumentImportSheet
              - ActivityEditSheet
```

### Tab vs. Segmented within TripDetail

Use a `TabView` with `.tabViewStyle(.page)` or a segmented `Picker` in the toolbar to switch between Documents / Packing / Activities within a trip. This keeps all three features accessible at one navigation level and avoids deep push stacks that are hard to manage in one-handed use.

### NavigationPath design for deep-linking

Define a typed enum rather than raw strings so the router stays refactor-safe:

```swift
enum AppDestination: Hashable {
    case tripDetail(Trip.ID)
    case activityDetail(Activity.ID)
    case documentViewer(TravelDocument.ID)
}
```

This also positions the app cleanly for Universal Links or widget deep-links in v2.

---

## Feature Module Boundaries

### Module map

| Module | Owns | Reads from | Does NOT touch |
|---|---|---|---|
| Trips | Trip, Destination CRUD | nothing | Document files, notification schedule |
| Documents | TravelDocument CRUD, FileStorageService | Trip.id | Packing, Activities |
| Packing | PackingCategory, PackingItem CRUD | Trip.id | Documents, Activities |
| Activities | Activity CRUD, NotificationService, FileStorageService (photos) | Trip.id | Documents, Packing |
| Shared | FileStorageService, NotificationService | — | Domain models directly |

### Inter-module communication

All modules receive their Trip (or Trip.ID) as a parameter from the parent view. No module holds a reference to another module's ViewModel. Cross-cutting actions (trip delete, trip rename) are handled at the TripDetail level where all modules are already parented.

---

## Notification Architecture

### NotificationService

A stateless service wraps `UNUserNotificationCenter`. Activities carry a `notificationID: String?` that stores the `UNNotificationRequest.identifier`.

```swift
struct NotificationService {
    func requestAuthorization() async -> Bool
    func schedule(for activity: Activity) async throws -> String  // returns requestID
    func cancel(notificationID: String)
    func reschedule(for activity: Activity) async throws -> String
}
```

**Lifecycle rules:**

1. When an Activity is saved with `notificationEnabled = true` and a future date → call `schedule(for:)`, store the returned ID in `activity.notificationID`.
2. When an Activity is edited (date changes) and notification is enabled → call `reschedule(for:)`, update `notificationID`.
3. When `notificationEnabled` is toggled off → call `cancel(notificationID:)`, set `notificationID = nil`.
4. When an Activity is deleted → call `cancel(notificationID:)` before deleting the SwiftData record.
5. On app foreground: no mass re-scan needed. Notifications are calendar-triggered and survive app restarts without re-scheduling.

**Permission:** Request authorization lazily on first Activity creation attempt, not at app launch. Show a custom pre-permission prompt explaining the value before triggering the system dialog.

---

## Architectural Patterns

### Pattern 1: Observable ViewModel per Feature Screen

**What:** Each feature screen (TripList, PackingList, ActivityList, etc.) has its own `@Observable` class that owns business logic and calls into `@Environment(\.modelContext)`. Views are purely declarative.

**When to use:** All screens with user actions or non-trivial state.

**Trade-offs:** Slight boilerplate overhead. Worth it for testability — you can inject an in-memory ModelContext and test ViewModel logic without SwiftUI.

```swift
@Observable
final class PackingListViewModel {
    var categories: [PackingCategory] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func toggleItem(_ item: PackingItem) {
        item.isChecked.toggle()
        try? modelContext.save()
    }
}
```

### Pattern 2: Scoped @Query at View level, ViewModel for mutations

**What:** Use SwiftData's `@Query` macro directly in views for read-only live lists (zero boilerplate). Use a ViewModel only for mutations, business logic, and service calls.

**When to use:** Simple list views like DocumentListView, ActivityListView.

**Trade-offs:** Mixing @Query (view-level) and ViewModel (testable logic) is pragmatic but requires discipline to not put fetch logic in both places. Set the rule: @Query for display, ViewModel for writes.

### Pattern 3: Repository pattern for v2 Cloud separation (future-proof now)

**What:** Define a `TripRepository` protocol in front of SwiftData access. In v1 implement it with a SwiftData concrete class. In v2 this swaps in a CloudKit-backed implementation without touching ViewModels.

**When to use:** Only if the team is comfortable with the pattern overhead from day one. Otherwise introduce the protocol boundary at the v2 milestone — SwiftData's own abstractions are clean enough for v1 without it.

---

## Data Flow

### User creates an Activity with notification

```
ActivityEditView (user taps Save)
    ↓
ActivityViewModel.save(activity:)
    ↓ (if photos attached)
FileStorageService.savePhoto() → ~/Documents/Travellify/photos/...
    ↓
modelContext.insert(activity) / save()
    ↓ (if notificationEnabled)
NotificationService.schedule(for: activity) → UNNotificationCenter
    ↓ store notificationID back on activity → modelContext.save()
    ↓
NavigationStack.pop() → ActivityListView refreshes via @Query
```

### User deletes a Trip

```
TripListView (swipe delete → confirm)
    ↓
TripListViewModel.delete(trip:)
    ↓
    1. Collect all document filePaths from trip.documents
    2. Collect all photoPaths from trip.activities
    3. Collect all notificationIDs from trip.activities
    4. Cancel all notifications via NotificationService
    5. modelContext.delete(trip) → SwiftData cascade deletes children
    6. modelContext.save()
    7. FileStorageService.deleteFile() for each path collected in step 1-2
```

This order (SwiftData first, file system second) is intentional — if the app crashes between step 6 and step 7, orphaned files on disk are non-critical. The reverse would orphan SwiftData records pointing to deleted files, which would cause display crashes.

### State management

```
SwiftData (source of truth for structured data)
    │
    ├─ @Query (automatic live fetch → SwiftUI re-render)
    │
    └─ @Observable ViewModel (mutations, derived state, service calls)
         └─ modelContext (injected via @Environment or init)
```

No separate state store (Redux, TCA) needed for v1. The @Observable + @Query combination covers all reactive needs.

---

## Recommended Project Structure

```
Travellify/
├── App/
│   ├── TravellifyApp.swift         # ModelContainer setup, environment injection
│   └── AppConstants.swift
│
├── Models/                         # SwiftData @Model classes only
│   ├── Trip.swift
│   ├── Destination.swift
│   ├── TravelDocument.swift
│   ├── PackingCategory.swift
│   ├── PackingItem.swift
│   └── Activity.swift
│
├── Features/
│   ├── Trips/
│   │   ├── TripListView.swift
│   │   ├── TripListViewModel.swift
│   │   ├── TripDetailView.swift
│   │   └── NewTripSheet.swift
│   ├── Documents/
│   │   ├── DocumentListView.swift
│   │   ├── DocumentViewModel.swift
│   │   ├── DocumentImportSheet.swift
│   │   └── DocumentViewerView.swift
│   ├── Packing/
│   │   ├── PackingListView.swift
│   │   ├── PackingListViewModel.swift
│   │   ├── PackingCategorySection.swift
│   │   └── PackingItemRow.swift
│   └── Activities/
│       ├── ActivityListView.swift
│       ├── ActivityDetailView.swift
│       ├── ActivityViewModel.swift
│       └── ActivityEditSheet.swift
│
├── Services/
│   ├── FileStorageService.swift
│   ├── NotificationService.swift
│   └── ScanImportService.swift     # VisionKit wrapper
│
├── Navigation/
│   └── AppDestination.swift        # Typed navigation enum
│
└── Shared/
    ├── Components/                 # Reusable SwiftUI views
    └── Extensions/
```

### Structure rationale

- **Models/ flat:** SwiftData models are cross-cutting — they don't belong inside any one feature folder
- **Features/ by domain:** Clear ownership, easy to hand off one feature at a time
- **Services/ separate:** Services have no SwiftUI import; they're testable in isolation
- **Navigation/ isolated:** Keeps routing logic out of views and viewmodels

---

## Build Order (Dependency-Driven)

```
Phase 1: Foundation
  → SwiftData models (Trip, Destination only)
  → ModelContainer setup with version-aware schema
  → TripListView + TripDetailView (scaffold)
  → NavigationStack + AppDestination

Phase 2: Documents
  → TravelDocument model
  → FileStorageService
  → DocumentListView + DocumentImportSheet
  → VisionKit / PhotosUI / FileImporter integration

Phase 3: Packing
  → PackingCategory + PackingItem models
  → PackingListView with swipe-to-check
  → Category management

Phase 4: Activities
  → Activity model (no photos yet)
  → ActivityListView (day-grouped)
  → ActivityEditSheet

Phase 5: Notifications
  → NotificationService
  → Wire into ActivityEditSheet toggle
  → Lifecycle management (edit, delete, reschedule)

Phase 6: Activity Photos
  → FileStorageService photo paths
  → PhotosUI picker in ActivityEditSheet
  → Photo grid in ActivityDetailView

Phase 7: Polish
  → Empty states, error handling
  → Haptics, animation
  → TestFlight build
```

**Rationale for this order:**
- Trips first because every other model is scoped to a trip — no other feature can be built meaningfully without it
- Documents before Activities because document import tests the FileStorageService independently, de-risking the photos work in Phase 6
- Packing before Activities because it is simpler (no service dependencies) and validates the in-trip navigation pattern
- Notifications after core Activity CRUD because scheduling bugs during development are disruptive; add the layer only once the data model is stable
- Photos last because they layer on top of both FileStorageService (proven in Documents phase) and Activities

---

## CloudKit Migration Path — What NOT to Do in v1

These are the constraints to follow from day one. Violating them in v1 means a schema rewrite before CloudKit sync can be enabled in v2.

| Constraint | v1 Rule | Why |
|---|---|---|
| No `@Attribute(.unique)` | Enforce uniqueness in app logic | CloudKit rejects atomic uniqueness checks |
| All inverse relationships optional | `var trip: Trip?` not `var trip: Trip` | CloudKit requires all relationship fields optional |
| No stored `Data` blobs on models | Store file paths as `String` | CloudKit binary fields are CKAsset, not inline Data |
| No enum stored types without rawValue | Use String/Int rawValues | CloudKit does not understand Swift enums directly |
| Schema versioning from day one | Define `VersionedSchema` v1 | Enables lightweight migration to v2 without data loss |
| Avoid renaming properties after release | Add `originalName:` if rename is needed | CloudKit interprets renames as delete + add = data loss |

### Schema versioning scaffold (build in Phase 1)

```swift
enum TravellifySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Trip.self, Destination.self, TravelDocument.self,
         PackingCategory.self, PackingItem.self, Activity.self]
    }
}

enum TravellifyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TravellifySchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
```

When v2 adds CloudKit, add `TravellifySchemaV2` and a lightweight migration stage — no data loss, no app review risk.

---

## Testability Strategy

### Unit tests: in-memory ModelContainer

```swift
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Trip.self, Destination.self, TravelDocument.self,
             PackingCategory.self, PackingItem.self, Activity.self,
        configurations: config
    )
}
```

Test ViewModels by injecting the in-memory container's `mainContext`. No file system, no notification center — stub services via protocols.

### Service protocols for test injection

```swift
protocol FileStorage {
    func saveDocument(_ data: Data, tripID: UUID, documentID: UUID, ext: String) throws -> String
    func deleteFile(atRelativePath path: String) throws
}

protocol NotificationScheduler {
    func schedule(for activity: Activity) async throws -> String
    func cancel(notificationID: String)
}
```

`FileStorageService` and `NotificationService` conform to these protocols. Tests inject `MockFileStorage` and `MockNotificationScheduler`. No disk writes, no UNUserNotificationCenter calls in unit tests.

### Test coverage priorities

1. ViewModel mutation methods (add, delete, toggle) — highest ROI, purely logic
2. FileStorageService path construction — relative path bugs are silent regressions
3. NotificationService lifecycle (schedule on create, cancel on delete, reschedule on edit)
4. SwiftData cascade delete behavior — integration test on device to catch the iOS bug

---

## Anti-Patterns

### Anti-Pattern 1: Storing binary data blobs in SwiftData models

**What people do:** `var fileData: Data` on TravelDocument.

**Why it's wrong:** Passport PDF scans are 1–5 MB each. Loading all documents into memory when the trip opens causes observable lag and eventual memory warnings. Blocks CloudKit sync (CKRecord field size limit). Fragments the SQLite store.

**Do this instead:** Store a relative file path. Load the file URL lazily when displaying or sharing the document.

### Anti-Pattern 2: Non-optional inverse relationships

**What people do:** `var trip: Trip` (non-optional inverse).

**Why it's wrong:** Works fine for v1, but CloudKit requires all relationship back-references to be optional. Changing to optional post-release requires a schema migration and all in-flight CloudKit records may be treated as having changed.

**Do this instead:** Make inverses optional from day one. Wrap any nil-guard logic in the ViewModel, not the model.

### Anti-Pattern 3: Scheduling notifications at app launch

**What people do:** On app launch, fetch all activities and re-schedule all enabled notifications.

**Why it's wrong:** Notification schedules survive app restarts (they live in UNUserNotificationCenter). Re-scheduling on every launch wastes battery, may duplicate notifications, and hits the 64-pending-notification OS limit faster.

**Do this instead:** Schedule once on Activity create/edit. Cancel explicitly on Activity delete. Only re-check on UNUserNotificationCenter delegate callbacks.

### Anti-Pattern 4: Bypassing schema versioning

**What people do:** Add a new property to a model without updating the schema version.

**Why it's wrong:** SwiftData handles lightweight schema changes (adding optional properties) automatically during development. But once the app ships, un-versioned changes may cause migration failures on users' devices, especially after CloudKit sync is enabled.

**Do this instead:** Wrap all model types in a `VersionedSchema` from Phase 1. Add a new schema version for each public release that changes the model graph.

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|---|---|---|
| Features → SwiftData | @Query macro (reads), ModelContext (writes) | No direct model-to-model cross-feature calls |
| Features → FileStorageService | Method calls from ViewModel | Service is stateless; no singleton needed |
| Features → NotificationService | Method calls from ActivityViewModel only | Only Activities feature touches UNUserNotificationCenter |
| TripListVM → child features | Pass Trip.ID via NavigationPath | Features fetch their own data from SwiftData using the ID |

### External Integrations (v1)

| Integration | Framework | Notes |
|---|---|---|
| Document scan | VisionKit (VNDocumentCameraViewController) | Wrap in UIViewControllerRepresentable |
| Photo import | PhotosUI (PhotosPicker) | Native SwiftUI in iOS 16+ |
| File import | SwiftUI fileImporter modifier | PDF + image UTTypes |
| Notifications | UserNotifications (UNUserNotificationCenter) | Calendar trigger (UNCalendarNotificationTrigger) |

---

## Scaling Considerations

This is a local-only single-user app in v1. "Scale" here means data volume on device.

| Scale | Architecture Adjustment |
|---|---|
| < 20 trips | @Query with no predicate — fine |
| 20–100 trips | Add sort descriptors + predicate for active vs. archived trips |
| 100+ trips | Add an `isArchived` flag and filter @Query; consider pagination |
| Large files | FileStorageService already handles this correctly — files on disk, not in SwiftData |

First real bottleneck in v2 (CloudKit) is sync conflict resolution, not data volume.

---

## Sources

- [SwiftData Relationship deleteRule documentation](https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum) — HIGH confidence
- [SwiftData cascade delete bug discussion — Apple Developer Forums](https://developer.apple.com/forums/thread/740649) — HIGH confidence
- [Designing Models for CloudKit Sync: Core Data & SwiftData Rules — fatbobman](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) — HIGH confidence
- [How to sync SwiftData with iCloud — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud) — HIGH confidence
- [How to write unit tests for SwiftData code — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code) — HIGH confidence
- [Using SwiftData to store large files — Medium/@jpmtech](https://medium.com/@jpmtech/using-swiftdata-to-store-large-files-from-an-api-call-11ad83404f76) — MEDIUM confidence
- [NavigationStack vs NavigationSplitView — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types) — HIGH confidence
- [SchemaMigrationPlan — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/schemamigrationplan) — HIGH confidence
- [SwiftData MVVM patterns — matteomanferdini.com](https://matteomanferdini.com/swiftdata-mvvm/) — MEDIUM confidence

---

*Architecture research for: Travellify — iOS SwiftUI + SwiftData travel companion app*
*Researched: 2026-04-18*
