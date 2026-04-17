# Pitfalls Research

**Domain:** iOS SwiftUI + SwiftData travel companion app (local-only v1, CloudKit v2)
**Researched:** 2026-04-18
**Confidence:** HIGH (critical pitfalls confirmed via Apple Developer Forums, official docs, and community post-mortems)

---

## Critical Pitfalls

### Pitfall 1: Shipping Without a VersionedSchema From Day One

**What goes wrong:**
The first public release ships with unversioned SwiftData models. Any subsequent model change (adding a field, renaming a property, changing a relationship) causes crashes on launch for existing users because SwiftData has no migration path to follow. Recovery requires a versioned schema bump, but users who never got the intermediate "put models in a VersionedSchema" build will crash permanently until they delete and reinstall the app.

**Why it happens:**
During development the store is recreated freely. Developers don't feel the pain until their first update attempt in production — at which point it's too late.

**How to avoid:**
Wrap every `@Model` in a `VersionedSchema` on the very first commit, before writing any app logic. Define `SchemaV1` immediately. Cost is ~30 lines of boilerplate that prevents rewrites later. Enforce this as a PR gate: no new `@Model` without a versioned schema enclosing it.

```swift
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Trip.self, Document.self, Activity.self, PackingItem.self] }

    @Model final class Trip { ... }
}
typealias Trip = AppSchemaV1.Trip
```

**Warning signs:**
- `@Model` classes declared at the top level (not inside a `VersionedSchema` enum)
- `ModelContainer(for: Trip.self, ...)` without a `migrationPlan` parameter

**Phase to address:** Phase 1 (foundation / data model) — before any model is shipped

---

### Pitfall 2: Storing Full-Resolution Images as `Data` Inside SwiftData Models

**What goes wrong:**
Documents (passport scans, PDF pages, ticket photos) and activity photos are stored as `Data` blobs directly on `@Model` objects. On first fetch, SwiftData loads the entire column into memory. With even 5 photos at 3–5 MB each, the main thread stalls and memory spikes. On a list view showing thumbnails, every row triggers a full image load. The app gets killed by the watchdog.

**Why it happens:**
`@Model` makes it tempting to add `var imageData: Data?` — it compiles and works in the simulator. Production devices with real camera photos expose the performance problem.

**How to avoid:**
Store images on the filesystem (in the app's `Application Support` or `Documents` directory) and keep only the relative file path as a `String` on the model. Generate a thumbnail on import and cache it separately. Never store raw `Data` on a `@Model` for anything larger than a small icon.

```swift
// On import
let filename = UUID().uuidString + ".jpg"
let url = FileManager.default.documentsDirectory.appending(path: filename)
try compressedData.write(to: url)
document.imageFilename = filename  // only path stored in SwiftData
```

Thumbnails: Generate a 200 px thumbnail on import, store it as a separate small file (e.g. `thumb_<uuid>.jpg`). Load thumbnails in list rows; load full image only in detail view.

**Warning signs:**
- `var imageData: Data?` or `var pdfData: Data?` on any `@Model`
- `@Attribute(.externalStorage)` is better than inline `Data`, but still not ideal for CloudKit readiness (CloudKit has a 1 MB asset limit per record field)
- Instruments showing memory growth proportional to visible list rows

**Phase to address:** Phase 2 (documents feature) — define the file-storage pattern before implementing document import

---

### Pitfall 3: Blocking the Main Actor With SwiftData Saves During Image Import

**What goes wrong:**
VisionKit or PhotosUI hands back a `UIImage`. The developer compresses it and writes it to disk, then calls `modelContext.save()` — all on the main actor. With a large PDF (multi-page scan) or a burst of photos, the main thread freezes for 1–3 seconds, the UI hangs, and the scroll indicator freezes.

**Why it happens:**
SwiftData's `@Query` and default `ModelContext` are main-actor-bound. It feels natural to do everything there.

**How to avoid:**
Use a `@ModelActor` for all import work. Hand off the file-write and context insert to a background actor, then post the inserted persistent identifier back to the main actor for UI refresh.

```swift
@ModelActor
actor ImportActor {
    func importDocument(data: Data, tripID: PersistentIdentifier) throws {
        let filename = UUID().uuidString + ".jpg"
        // file write
        let doc = Document(filename: filename)
        let trip = modelContext.model(for: tripID) as? Trip
        trip?.documents.append(doc)
        try modelContext.save()
    }
}
```

**Warning signs:**
- Import code in a `Button` action or `onChange` directly modifying `modelContext`
- Instruments Time Profiler showing `modelContext.save()` on the main thread during photo import

**Phase to address:** Phase 2 (documents feature) — establish the ModelActor import pattern before wiring up VisionKit

---

### Pitfall 4: iOS 18 ModelContext Cross-Context Sync Regression

**What goes wrong:**
A confirmed regression in iOS 18 (RC and early releases): when a `@ModelActor`'s context updates a model, the main-actor context does not automatically reflect the change. Two contexts on the same `ModelContainer` diverge silently. The user saves a document but the list view does not update until app restart.

**Why it happens:**
Apple broke automatic context merging between contexts on the same container. The `@Query` property wrapper stopped observing cross-context notifications reliably in iOS 18.0.

**How to avoid:**
- Target iOS 17 minimum to sidestep the regression, or
- Use `NotificationCenter` to explicitly broadcast `.NSManagedObjectContextDidSave` and call `modelContext.mergeChanges(fromContextDidSave:)` manually after each background save
- Test background-then-main-thread update flows on a physical iOS 18 device as part of every import feature

**Warning signs:**
- List not updating after background import on iOS 18 but working on iOS 17
- `.onChange(of: modelContext)` triggers but `@Query` results are stale

**Phase to address:** Phase 2 (documents feature) — integration test must run on both iOS 17 and iOS 18 device

---

### Pitfall 5: Missing Cascade Delete on Trip Relationships

**What goes wrong:**
A trip is deleted but its child documents, activities, and packing items remain as orphan rows in the SQLite store. Disk usage grows silently. The orphaned file paths on disk are never cleaned up. If the same filename is reused (UUID collision is astronomically unlikely but file cleanup is not), stale data surfaces.

**Why it happens:**
SwiftData's default delete rule is `.nullify`, not `.cascade`. Developers assume deleting a parent removes children. It does not unless explicitly set.

**How to avoid:**
Declare `deleteRule: .cascade` on every parent-to-children relationship:

```swift
@Relationship(deleteRule: .cascade, inverse: \Document.trip)
var documents: [Document] = []
```

Additionally, override delete for `Trip` to walk the `documents` array and delete associated files from disk before calling `modelContext.delete(trip)`. SwiftData cascade only cleans the database; the filesystem is your responsibility.

**Warning signs:**
- Deleting a trip and checking the SQLite store (via GRDB or `sqlite3` CLI) still shows child rows
- App's `Application Support` directory growing after trips are deleted

**Phase to address:** Phase 1 (data model) and Phase 3 (trip management) — cascade rule at model definition, file cleanup at delete UI

---

### Pitfall 6: CloudKit-Breaking Model Decisions Made in v1

**What goes wrong:**
v1 ships with model constraints that are incompatible with CloudKit. When v2 attempts to enable `ModelContainer(..., cloudKitDatabase: .automatic)`, the migration fails because:
- Non-optional properties exist (CloudKit requires all user-created properties to be optional)
- Uniqueness constraints (`@Attribute(.unique)`) are used — CloudKit forbids these
- Delete rule `.deny` is set on any relationship

These require a destructive migration or a complete re-architecture to fix.

**Why it happens:**
Non-optional properties and unique constraints feel like good defensive programming. They are, for local-only apps. But CloudKit operates on a different data model contract.

**How to avoid:**
Even in v1 (local-only), design as if CloudKit is already enabled:
- All relationship properties: `Optional` or provide a default value
- No `@Attribute(.unique)` — use application-level deduplication instead
- No `.deny` delete rules
- Every `@Model` must be reachable from a root entity CloudKit can sync

This is zero-cost discipline: optional properties with defaults are fine for local use.

```swift
// Safe for CloudKit v2 from day one
var destination: String = ""       // default, not forced non-optional
var startDate: Date = .now         // default
var notes: String?                 // explicit optional is fine
```

**Warning signs:**
- `@Attribute(.unique)` in any model
- Non-optional custom properties without defaults (e.g., `var name: String` with no `= ""`)
- `.deny` in any `@Relationship` delete rule

**Phase to address:** Phase 1 (data model) — embedded in model design guidelines before any model is written

---

### Pitfall 7: Scheduling More Than 64 Local Notifications

**What goes wrong:**
A traveler with a busy multi-day itinerary schedules reminders for 70+ activities. iOS silently keeps only the soonest 64 pending notifications and discards the rest. Activities further in the future get no reminder. The user has no idea — the UI shows the reminder as "scheduled."

**Why it happens:**
iOS enforces a hard cap of 64 pending local notifications per app. There is no API to detect which notifications were silently dropped.

**How to avoid:**
- Implement a notification scheduling manager that queries `UNUserNotificationCenter.current().pendingNotificationRequests()` before scheduling
- Schedule only the next N soonest activity reminders; reschedule when the app enters foreground or receives `UIApplication.willEnterForegroundNotification`
- Keep trip activity dates in a sorted list and re-evaluate which 64 slots to occupy on each app open
- Display a warning in the UI if a trip has more reminders than can be scheduled: "Reminders scheduled for the next 64 activities"

**Warning signs:**
- More than 64 `UNNotificationRequest` calls without pruning
- Activities with reminders after the 64th item never firing in testing

**Phase to address:** Phase 4 (activities + notifications) — build the scheduling manager from the start, not as a retrofit

---

### Pitfall 8: VisionKit Scan Result Not Captured on First Dismissal

**What goes wrong:**
`DataScannerViewController` is dismissed before the delegate callback fires, or the delegate is set up on the coordinator but the closure is captured weakly and released. The scan result is lost. The user rescans and wonders why the first attempt failed silently.

**Why it happens:**
`DataScannerViewController` is UIKit. When wrapped in `UIViewControllerRepresentable`, the coordinator lifecycle is subtle: if the parent view updates and SwiftUI recreates the representable, the old coordinator (which holds the delegate reference) is released mid-scan.

**How to avoid:**
- Hold the scan result in an `@Observable` class (not `@State`) owned outside the representable, so it survives view re-renders
- Use `makeCoordinator()` correctly: the coordinator must be the delegate, and the delegate reference must be kept alive as long as the scan sheet is presented
- Add a `NSCameraUsageDescription` key in `Info.plist` before any testing — missing key causes a silent crash, not a permission dialog
- Check `DataScannerViewController.isSupported && DataScannerViewController.isAvailable` before showing the scan button; show a "camera unavailable" fallback

**Warning signs:**
- Delegate callbacks firing zero times during testing
- App crashing on first scan attempt without a clear error log

**Phase to address:** Phase 2 (documents feature) — write a dedicated `ScannerCoordinator` class before integrating into the UI

---

### Pitfall 9: PhotosUI Image Memory Spike on Multi-Photo Selection

**What goes wrong:**
The user adds photos to an activity. `PhotosPicker` with `maxSelectionCount: 5` is used. The developer calls `item.loadTransferable(type: Data.self)` and stores each `Data` blob. On a modern iPhone with 48 MP photos, each raw `Data` is 15–25 MB. Selecting 5 photos temporarily inflates the app's memory by 100–125 MB, often triggering a memory warning or a jetsam kill.

**Why it happens:**
`loadTransferable(type: Data.self)` returns the full-resolution original. There is no built-in downsampling step.

**How to avoid:**
- After `loadTransferable`, immediately downsample using `ImageRenderer` or `UIGraphicsImageRenderer` to a maximum dimension (e.g., 1920 px longest side) before any further processing or storage
- Process one photo at a time (serial, not concurrent) to cap peak memory
- For activity thumbnails, generate a 300 px version on import and store it separately

```swift
func downsample(data: Data, maxDimension: CGFloat) -> Data? {
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                     kCGImageSourceThumbnailMaxPixelSize: maxDimension]
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85)
}
```

**Warning signs:**
- Instruments showing memory spike above 150 MB during photo selection
- Xcode memory report showing `com.apple.photos.ImageIO` in the top allocations

**Phase to address:** Phase 3 (activities feature) — image import pipeline must downsample before any storage

---

### Pitfall 10: NavigationStack Path Deserialization Crash on Model Change

**What goes wrong:**
Navigation state is persisted via `NavigationPath` + `Codable`. After a schema or model change (e.g., a `Trip` gains a new non-optional property), decoding the persisted path crashes with `Failed to decode item in navigation path at index 0`. On cold launch, the app crashes in a loop for users who had an active navigation state saved.

**Why it happens:**
`NavigationPath`'s codable representation encodes the full type and value. If the decoded type's structure has changed, decoding fails fatally.

**How to avoid:**
- Wrap `NavigationPath` decode in a `do/catch` and fall back to an empty path on failure — never `try!` or `try?` without a fallback
- Store navigation paths using lightweight route identifiers (e.g., a `tripID: UUID`) rather than full model snapshots
- Include a version field in the persisted path structure; clear persisted state when the version changes

```swift
// Safe restoration
func restorePath() -> NavigationPath {
    guard let data = UserDefaults.standard.data(forKey: "navPath"),
          let path = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data)
    else { return NavigationPath() }  // fallback on any failure
    return NavigationPath(path)
}
```

**Warning signs:**
- `fatalError` in `NavigationPath` decode stack trace in crash reports
- Navigation state silently reset on app update

**Phase to address:** Phase 1 (navigation architecture) — establish the safe path pattern before building any navigation

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Top-level `@Model` without `VersionedSchema` | Less boilerplate | First model change crashes all existing users | Never |
| `var imageData: Data?` on `@Model` | No file management code | Main-thread stalls, memory kills, CloudKit 1 MB field limit | Never for images > 100 KB |
| Non-optional properties with no defaults | Compile-time safety | Breaks CloudKit migration in v2 | Never if v2 is planned |
| Schedule all activity notifications eagerly | Simple logic | Silent drops past 64, user misses reminders | Only if trip has < 10 activities max |
| Main-actor document import | No concurrency code | UI freezes on real device with large files | Only for MVP demo builds, must be fixed before TestFlight |
| `@Attribute(.unique)` on trip name | DB-level dedup | Incompatible with CloudKit | Never if CloudKit planned for v2 |
| Store thumbnail and full image in same `@Model` | Single fetch | Memory doubles, no lazy loading | Never for user-generated images |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| VisionKit `DataScannerViewController` | Wrapping directly in `sheet` without checking `isSupported` + `isAvailable` | Gate the camera button on both checks; show file-picker fallback on unsupported devices |
| VisionKit coordinator | Coordinator released mid-scan because parent SwiftUI view updated | Hold scan state in an `@Observable` class outside the representable |
| PhotosUI `PhotosPicker` | Storing `Data` from `loadTransferable` directly | Downsample immediately after transfer; store only file path |
| PhotosUI limited access | `PHPickerResult.itemProvider` works but `PHAsset` lookup fails in limited mode | Use `itemProvider` path only; do not rely on `PHAsset` identifiers |
| `UserNotifications` | Not re-scheduling after app update wipes pending notifications | Re-schedule all active reminders on `applicationDidBecomeActive` |
| `UserNotifications` | Foreground notification invisible by default | Implement `UNUserNotificationCenterDelegate.willPresent` to show banner in-app |
| SwiftData + CloudKit | Enabling `cloudKitDatabase: .automatic` on existing local-only container with non-optional properties | Design all properties CloudKit-safe from v1; enabling sync in v2 becomes a configuration change, not a migration |
| PDF import via `FileImporter` | Loading entire PDF `Data` into memory for display | Use `PDFKit`'s `PDFDocument(url:)` with lazy page rendering; never load all pages as `UIImage` simultaneously |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `@Query` on `Activity` with no predicate in a trip detail view | All activities across all trips loaded, then filtered in SwiftUI | Always scope `@Query` with a predicate filtering by `trip.persistentModelID` | > 200 total activities across trips |
| Thumbnail rendered from full image on every list row appearance | Scroll jank, CPU spike when fast-scrolling packing lists or document lists | Generate and cache thumbnail on import; store as a separate small file | > 20 items in any list |
| `List` with `ForEach` over `@Query` results using unstable IDs | Random row animations, scroll position jumps | Ensure `@Model` is `Identifiable` via its `persistentModelID`; never use index-based IDs | Any deletion in the middle of a list |
| `ModelContext.save()` called inside `List.onDelete` for each item in a loop | Multiple save round-trips stall the UI during bulk delete | Collect all deletions, execute once, then `save()` | Deleting > 5 items at once |
| `Image(uiImage:)` holding strong reference to full-resolution `UIImage` in a `ScrollView` | Memory grows with scroll distance; never evicted | Use `LazyVGrid`/`LazyVStack`; wrap in `AsyncImage`-style view with on-demand loading | Any grid with > 10 full-res images visible |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing passport scan files in `/tmp` or `Caches` | OS may purge files; passport data exposed to other apps on jailbroken devices | Store in `Application Support` (not backed up by default; not user-visible in Files app) |
| Logging document file paths or SwiftData predicates in `print()` statements | File paths containing user-identifiable info leak to Console.app | Use `os.Logger` with `%{private}` privacy annotation for all path logging |
| No file-level encryption for document storage | If device is not passcode-protected, scan files readable | Store files with `FileProtectionType.completeUntilFirstUserAuthentication` at minimum |
| SwiftData store in default location without encryption attribute | SQLite store readable without FileProtection | Set `isStoredInMemoryOnly: false` with encryption; use `ModelConfiguration` with appropriate URL in the protected `Application Support` directory |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing raw filename (UUID.jpg) for scanned documents | User cannot identify their passport vs. hotel booking | Prompt for a name immediately after import; default to the scan date + type |
| Packing list check-off resets position to top after toggle | Disorienting; user loses place when checking items on the night before travel | Use `scrollPosition` binding or preserve `List` offset; never reload the full list on toggle |
| No feedback during document import (VisionKit scan → processing) | User taps scan button multiple times thinking it failed | Show a progress indicator during `loadTransferable` and file write; disable the button during processing |
| Notification permission requested on first app launch | iOS denies future prompts if user declines on cold start (no context) | Request notification permission only when user first enables a reminder on a specific activity |
| Activity reminder fires for past activities | User gets notification for "Dinner in Rome" from a trip 6 months ago | Filter out past-dated activities when rescheduling on app launch; cancel stale notification IDs |
| Delete confirmation only on swipe, not on bulk select | User accidentally deletes a trip with no undo | Add a confirmation alert for trip-level deletes; packing items can delete on swipe without confirm |

---

## "Looks Done But Isn't" Checklist

- [ ] **Document import:** Verify file is actually written to disk before the `@Model` is saved — a save without the file creates a model with a broken path
- [ ] **VisionKit scan:** Verify scan works on a physical device (simulator has no camera); test the `isAvailable: false` fallback on a device with camera restrictions
- [ ] **Cascade delete:** After deleting a trip, verify (via Finder or sqlite3) that all child rows are gone from the SQLite store and all image files are removed from disk
- [ ] **Notification scheduling:** Verify notifications actually fire on a physical device in airplane mode (local notifications do not require connectivity but must be tested on device)
- [ ] **VersionedSchema:** Verify that adding a new property to any `@Model` without a migration plan does not crash on an existing install (test by installing v1, adding data, then installing v2 schema)
- [ ] **CloudKit readiness audit:** Run `grep -r "@Attribute(.unique)" .` and `grep -r "deleteRule: .deny" .` — both should return zero results before any v2 planning begins
- [ ] **64 notification cap:** Verify that a trip with 70+ activities only schedules 64 notifications and shows appropriate UI feedback for the overflow
- [ ] **Photo memory:** Profile with Instruments during import of 5 camera-roll photos; peak memory must stay below 100 MB

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Shipped without VersionedSchema, need to add a field | HIGH | Ship a release that wraps existing models in `SchemaV1` (no migration needed, just wrapping); wait for adoption; then ship `SchemaV2` with the actual change |
| Binary data in `@Model` discovered post-launch | HIGH | Add a new `imageFilename: String?` column; write a migration that extracts `Data` blobs to disk and populates the filename; zero out the `Data` column; ship migration |
| Cascade delete not set, orphan rows accumulating | MEDIUM | Write a one-time cleanup on app launch that queries for orphaned documents/activities with no parent trip; delete them and clean associated files |
| CloudKit-incompatible model (unique constraints, non-optionals) | HIGH | Requires `SchemaMigration` to strip constraints + make properties optional; significant QA risk; easier to avoid upfront |
| 64 notification limit hit, users missing reminders | MEDIUM | Add `willEnterForeground` observer that calls a `NotificationScheduler.reschedule()` method; reschedule the next 64 soonest reminders each time |
| Navigation path crash on launch | LOW | Wrap all path decoding in `try/catch`; clear persisted state on decode failure; ship a hotfix |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| No VersionedSchema from day one | Phase 1 (data model) | `grep -r "VersionedSchema"` covers all `@Model` files |
| Images stored as `Data` in `@Model` | Phase 2 (documents) | Code review: no `Data` property > 1 KB on any model |
| Main-actor blocking during import | Phase 2 (documents) | Instruments Time Profiler: no save > 16 ms on main thread |
| iOS 18 cross-context sync regression | Phase 2 (documents) | Integration test: insert from `@ModelActor`, verify `@Query` updates on iOS 18 device |
| Missing cascade delete + file cleanup | Phase 1 (model) + Phase 3 (trip CRUD) | Delete trip integration test verifies SQLite row count + file count = 0 |
| CloudKit-breaking model decisions | Phase 1 (model) | Pre-commit lint: no `@Attribute(.unique)`, no non-optional non-default properties |
| 64 notification limit | Phase 4 (activities) | Test with 70 activities all with reminders; verify count via `pendingNotificationRequests()` |
| VisionKit delegate lifecycle | Phase 2 (documents) | Physical device test: 10 consecutive scans without a lost result |
| PhotosUI memory spike | Phase 3 (activities) | Instruments: peak RSS < 100 MB during 5-photo selection |
| NavigationPath decode crash | Phase 1 (navigation) | Integration test: install v1, navigate deep, install v2, verify no crash |

---

## Sources

- [Key Considerations Before Using SwiftData — Fatbobman](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/)
- [Never use SwiftData without VersionedSchema — Mert Bulan](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema)
- [An Unauthorized Guide to SwiftData Migrations — Atomic Robot](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)
- [SwiftData Issues in macOS 14 and iOS 17 — Michael Tsai](https://mjtsai.com/blog/2024/06/04/swiftdata-issues-in-macos-14-and-ios-17/)
- [SwiftData Background Tasks — Use Your Loaf](https://useyourloaf.com/blog/swiftdata-background-tasks/)
- [iOS 18 SwiftData ModelContext reset — Apple Developer Forums](https://forums.developer.apple.com/forums/thread/757521)
- [SwiftData does not cascade delete — Apple Developer Forums](https://developer.apple.com/forums/thread/740649)
- [Designing Models for CloudKit Sync: Core Data & SwiftData Rules — Fatbobman](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
- [3 Things I Wish I Knew Before Starting With SwiftData + CloudKit — Carolane Lefebvre](https://carolanelefebvre.medium.com/en-3-things-i-wish-i-knew-before-starting-with-swiftdata-cloudkit-bb53df9bb6b1)
- [High Performance SwiftData Apps — Jacob Bartlett](https://blog.jacobstechtavern.com/p/high-performance-swiftdata-apps)
- [Storage options on iOS compared — Donny Wals](https://www.donnywals.com/storage-options-on-ios-compared/)
- [Using PHPickerViewController Images in a Memory-Efficient Way — Christian Selig](https://christianselig.com/2020/09/phpickerviewcontroller-efficiently/)
- [SwiftUI and UIImage memory leak — Apple Developer Forums](https://developer.apple.com/forums/thread/773238)
- [iOS pending notification limit (64 cap) — Apple Developer Forums](https://developer.apple.com/forums/thread/811171)
- [NavigationPath state restoration crash — Apple Developer Forums](https://developer.apple.com/forums/thread/710295)
- [How to run Swift Data operations in background — Pol Piella](https://www.polpiella.dev/core-data-swift-data-concurrency)

---
*Pitfalls research for: iOS SwiftUI + SwiftData travel companion app (Travellify)*
*Researched: 2026-04-18*
