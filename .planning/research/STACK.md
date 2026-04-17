# Stack Research

**Domain:** Native iOS travel companion app (local-only v1, CloudKit-ready v2)
**Researched:** 2026-04-18
**Confidence:** HIGH (Apple-native stack, all decisions verified against current documentation and 2025-2026 community sources)

---

## Recommended Stack

### Core Technologies

| Technology | Version / Target | Purpose | Why Recommended |
|------------|-----------------|---------|-----------------|
| Swift | 6 (language mode) | Primary language | Swift 6 strict concurrency catches data-race bugs at compile time, not runtime. Pairs cleanly with SwiftData's actor-aware APIs. Required for Xcode 16+ App Store submissions as of April 2025. |
| SwiftUI | iOS 17+ | All UI | Native, declarative, pairs directly with SwiftData's `@Query` macro. `@Observable` (Swift 5.9+) replaces the old ObservableObject/Combine pattern — no third-party reactive layer needed. |
| SwiftData | iOS 17+ | Local persistence | Apple's first-party ORM, built on Core Data, with SwiftUI-native `@Query` and `@Model` macros. Sets the cleanest path to CloudKit sync in v2 (single flag on ModelContainer). No third-party dependency. |
| Xcode | 16.x (latest stable) | Build / IDE | Required to use Swift 6 language mode and submit to App Store (iOS 18 SDK requirement as of April 2025). Swift Testing framework ships in Xcode 16. |

### Apple Frameworks (No Third-Party Needed)

| Framework | Min iOS | Purpose | Notes |
|-----------|---------|---------|-------|
| VisionKit (`VNDocumentCameraViewController`) | iOS 13 | Camera document scanning | Wrap in `UIViewControllerRepresentable`. Provides auto-deskew, multi-page scan, enhanced contrast. UIKit-based but trivially bridged to SwiftUI. |
| PhotosUI (`PhotosPicker`) | iOS 16 (native SwiftUI) | Photo picker for activity photos | Pure SwiftUI API from iOS 16. No permission prompt needed before showing picker. Use `PhotosPickerItem` + `loadTransferable(type:)` to load image data. |
| UniformTypeIdentifiers (`UTType`) | iOS 14 | File type filtering for document picker | Used with `UIDocumentPickerViewController` to restrict to `.pdf`, `.image`, `.jpeg`, `.png`. |
| UIKit (`UIDocumentPickerViewController`) | iOS 11 | Files app PDF/document import | Wrap in `UIViewControllerRepresentable`. Use `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` correctly or you get silent failures. |
| UserNotifications | iOS 10 | Per-activity local reminders | Use `UNUserNotificationCenter`. Calendar trigger (not time interval) for activity reminders since they are date/time-bound. Request permission lazily, only when user enables their first reminder — not at app launch. |
| Swift Concurrency (async/await, actors) | iOS 15+ (back-deployed) | Background data work | Use `ModelActor` for heavy SwiftData operations off the main thread. Keep `mainContext` operations lightweight. |

### Supporting Libraries

All of these are Apple-native. There are no recommended third-party libraries for v1.

| Library | Min iOS | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Testing | Xcode 16 / any iOS target | Unit and integration tests | Use for all new tests in v1. Parallel test execution by default, modern `@Test` / `#expect` syntax, async-native. Do not mix with XCTest helpers in the same test function. |
| XCTest (UI tests only) | iOS 9 | UI automation tests | Retain XCTest for UITest targets — Swift Testing has no equivalent for UI testing. Keep unit and integration tests in Swift Testing. |
| SwiftUI Previews | iOS 17 | Design-time preview | Use `#Preview` macro (Xcode 15+). Provide in-memory SwiftData container via `ModelContainer(for:..., configurations: ModelConfiguration(isStoredInMemoryOnly: true))`. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode project (`.xcodeproj`) | Project structure | Use plain Xcode project for a single-target, single-developer app. No Tuist or XcodeGen needed — those solve merge-conflict and multi-module problems that don't exist at this scale. Add SwiftPM packages directly in Xcode if any dependency is added later. |
| Swift Package Manager (SwiftPM) | Dependency management | Built into Xcode. No CocoaPods, no Carthage. If a dependency is ever added, pull it via SwiftPM. |
| SwiftLint | Code style enforcement | Optional but recommended. Add as a SwiftPM plugin or build-phase script. Use the default ruleset — don't over-configure. |
| Instruments | Performance profiling | Use the SwiftData template in Instruments to catch N+1 fetch patterns and main-thread fetch blocking. Do this before CloudKit migration, not after. |

---

## Installation

No package manager bootstrap needed — all frameworks ship with the iOS SDK. Project setup:

```bash
# Create new Xcode project
# File > New > Project > iOS App
# Interface: SwiftUI
# Language: Swift
# Storage: SwiftData  (Xcode sets up the ModelContainer boilerplate)

# Add SwiftLint (optional)
# File > Add Package Dependencies > https://github.com/realm/SwiftLint
# Add as build-phase plugin
```

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Core Data | Superseded by SwiftData for new projects targeting iOS 17+. SwiftUI integration requires manual NSFetchedResultsController wiring. No `@Query` macro. More boilerplate. | SwiftData |
| ObservableObject + @Published (Combine) | Superseded by the `@Observable` macro (Swift 5.9+). Old pattern causes over-rendering of unrelated views, requires explicit `objectWillChange` in complex cases. | `@Observable` class + `@Bindable` |
| Combine for reactive streams | The `@Observable` macro eliminates the main use case for Combine in SwiftUI apps. Async/await handles async data flows. No third-party reactive layer needed. | Swift Concurrency (async/await) |
| RealmSwift | Third-party dependency with its own threading rules that conflict with SwiftData. Adds 15–20 MB binary size. Blocks the CloudKit path entirely in v2. | SwiftData |
| Third-party image caching (Kingfisher, SDWebImage) | All photos are local, loaded from the device. There is no network image loading in v1 or v2. These libraries solve a problem this app does not have. | `AsyncImage` (if ever needed) or direct `UIImage(data:)` |
| Tuist / XcodeGen | Project generation tools solve merge conflicts in multi-developer, multi-module projects. A single-developer, single-module app gains nothing and adds tooling overhead. | Plain `.xcodeproj` |
| CocoaPods / Carthage | Effectively deprecated for new iOS projects. SwiftPM is the Apple-supported replacement and is sufficient. | SwiftPM |
| `@Attribute(.unique)` on SwiftData models | CloudKit does not support uniqueness constraints. Adding `.unique` now makes CloudKit sync impossible in v2 without a schema migration. | Use UUIDs as natural identifiers with default values (`var id: UUID = UUID()`) |
| UIKit-first architecture (UIViewController subclasses) | Adds UIKit complexity for a greenfield SwiftUI app. Use `UIViewControllerRepresentable` only as a thin bridge for VisionKit and `UIDocumentPickerViewController` — don't build screens in UIKit. | SwiftUI views throughout |
| `@Query` with heavy relationships on main thread | SwiftData's `@Query` runs on `@MainActor`. Fetching large binary payloads (PDFs, images) through the main context blocks UI. | Store binary data with `@Attribute(.externalStorage)` and load lazily; use `ModelActor` for background operations |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Persistence | SwiftData | Core Data | SwiftData is Core Data under the hood, with a modern Swift API, `@Query` macro, and zero extra boilerplate. New greenfield project on iOS 17+ has no reason to use Core Data directly. |
| Persistence | SwiftData | SQLite (GRDB, etc.) | GRDB is excellent for complex query needs, but this app's data model is simple and relational. SwiftData's CloudKit migration path is the tie-breaker. |
| Testing | Swift Testing | XCTest (unit) | Swift Testing is Apple's stated direction for unit tests. Parallel execution and async-native design are concrete improvements. XCTest unit tests are not wrong, just not the modern default. |
| Project tooling | Xcode project | Tuist | Tuist is valuable for modular apps with CI caching needs. Single-module solo-developer app doesn't benefit. |
| Photo picking | PhotosUI PhotosPicker | PHPickerViewController (UIKit) | PhotosPicker is the pure SwiftUI wrapper around the same underlying picker. No reason to use the UIKit version in a SwiftUI app. |

---

## CloudKit Migration Path (v2 Door)

This is the most important architectural constraint in v1. Every model design decision must leave this door open.

### Rules to Follow in v1 (to avoid a schema rewrite in v2)

1. **Use `VersionedSchema` from day one.** Even with a single schema version, wrap models in `AppSchemaV1`. When v2 adds CloudKit, you create `AppSchemaV2` and write a `SchemaMigrationPlan`. Retrofitting versioning after ship requires a two-step release process and risks data loss for users who skip updates.

2. **All properties must be optional or have default values.** CloudKit requires this. Design models with this in mind: `var title: String = ""` not `var title: String`.

3. **All relationships must be optional.** CloudKit requires optional inverse relationships. Write them optional from the start.

4. **Do not use `@Attribute(.unique)`.** CloudKit does not support uniqueness constraints. Use UUID as a natural key with a default value: `var id: UUID = UUID()`.

5. **Do not use `.deny` delete rules on relationships.** CloudKit does not support Deny. Use `.cascade` or `.nullify`.

6. **Store binary data with `@Attribute(.externalStorage)`.** Images and PDFs must not live in the SQLite store. Mark `var fileData: Data?` with `@Attribute(.externalStorage)`. Note: compatibility of `.externalStorage` with CloudKit sync is not definitively documented — in v2, evaluate whether to store files in CloudKit `CKAsset` fields and reference them by URL instead of embedding `Data` in SwiftData models.

7. **Enabling CloudKit in v2 is one Xcode capability toggle + one ModelContainer flag.** The `ModelContainer` accepts a `CloudKitContainerOptions` configuration. If the model is CloudKit-compatible from v1, this is the only required change.

### Model Structure Template (v1, CloudKit-ready)

```swift
// Wrap in versioned schema from day one
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [Trip.self, Document.self, PackingItem.self, Activity.self]

    @Model
    final class Trip {
        var id: UUID = UUID()          // Natural key, CloudKit-safe
        var name: String = ""
        var startDate: Date = Date()
        var endDate: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \Document.trip)
        var documents: [Document]? = []
        // ... etc
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [AppSchemaV1.self]
    static var stages: [MigrationStage] = []  // No migration needed in v1
}
```

---

## Version Compatibility

| Technology | Min Version | Notes |
|------------|-------------|-------|
| SwiftData `@Model` | iOS 17.0 | Hard requirement. SwiftData does not exist on iOS 16. |
| SwiftData `VersionedSchema` | iOS 17.0 | Available from initial SwiftData release. |
| SwiftUI `PhotosPicker` (native) | iOS 16.0 | Available below the iOS 17 floor. |
| VisionKit `VNDocumentCameraViewController` | iOS 13.0 | Available below the iOS 17 floor. |
| `@Observable` macro | iOS 17.0 | Requires iOS 17 — aligns with SwiftData minimum. |
| Swift Testing framework | Any deployment target (Xcode 16 build-time) | Works with iOS 17 target. |
| `UserNotifications` calendar triggers | iOS 10.0 | Available below the iOS 17 floor. |
| CloudKit SwiftData sync (v2) | iOS 17.0 | Same minimum as SwiftData. No version bump needed for v2 if you stay on iOS 17 floor. |

---

## Sources

- [Key Considerations Before Using SwiftData — fatbobman.com](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) — CloudKit constraints, threading model, performance limitations (HIGH confidence)
- [Designing Models for CloudKit Sync: Core Data & SwiftData Rules — fatbobman.com](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) — CloudKit model design rules (HIGH confidence)
- [SwiftData Architecture Patterns and Practices — AzamSharp](https://azamsharp.com/2025/03/28/swiftdata-architecture-patterns-and-practices.html) — Architecture guidance for 2025 (MEDIUM confidence, community source verified against Apple docs)
- [If You Are Not Versioning Your SwiftData Schema — AzamSharp](https://azamsharp.com/2026/02/14/if-you-are-not-versioning-your-swiftdata-schema.html) — VersionedSchema from day one (HIGH confidence — 2026 article)
- [How to create a complex migration using VersionedSchema — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) — Migration plan structure (HIGH confidence)
- [SwiftData: Dive into inheritance and schema migration — WWDC25](https://developer.apple.com/videos/play/wwdc2025/291/) — Apple official, schema migration (HIGH confidence)
- [What's new in SwiftData — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10137/) — Apple official (HIGH confidence)
- [PhotosPicker in SwiftUI — Swift with Majid](https://swiftwithmajid.com/2023/04/25/photospicker-in-swiftui/) — PhotosUI patterns (HIGH confidence, verified against Apple docs)
- [Bringing Photos picker to your SwiftUI app — Apple Developer Documentation](https://developer.apple.com/documentation/PhotoKit/bringing-photos-picker-to-your-swiftui-app) — Official reference (HIGH confidence)
- [Swift Testing vs XCTest — Infosys Digital Experience](https://blogs.infosys.com/digital-experience/mobility/swift-testing-vs-xctest-a-comprehensive-comparison.html) — Testing framework comparison (MEDIUM confidence)
- [VisionKit — Apple Developer Documentation](https://developer.apple.com/documentation/visionkit) — Official reference (HIGH confidence)
- [externalStorage — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/schema/attribute/option/externalstorage) — External storage attribute (HIGH confidence)
- [Concurrent Programming in SwiftData — fatbobman.com](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/) — Threading pitfalls (HIGH confidence)
- [Why you might want to generate your Xcode projects in 2025 — Tuist](https://tuist.dev/blog/2025/02/25/project-generation) — Project tooling context (MEDIUM confidence)

---

*Stack research for: Travellify — native iOS travel companion app*
*Researched: 2026-04-18*
