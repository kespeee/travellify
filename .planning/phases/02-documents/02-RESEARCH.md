# Phase 2: Documents — Research

**Researched:** 2026-04-19
**Domain:** VisionKit document scanning, PhotosPicker → disk pipeline, UIDocumentPickerViewController bridge, PDFKit multi-page assembly, SwiftData field additions within existing SchemaV1, Application Support file storage, Swift 6 strict concurrency for background file I/O + main-context insert
**Confidence:** HIGH on Apple API shapes (VisionKit / PhotosUI / PDFKit / UIDocumentPickerViewController patterns verified against Apple docs + community sources). MEDIUM on Xcode 26.2 / iOS 18 edge cases (Application Support iCloud backup semantics, `@ModelActor` merge behavior). LOW only on `asCopy: true` + security-scoped resource interaction on iOS 18 (documentation is ambiguous — defensive pattern recommended).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D10** — `Document` `@Model` extended inside `TravellifySchemaV1` with: `id: UUID`, `trip: Trip?`, `displayName: String`, `fileRelativePath: String`, `kind: DocumentKind` (raw String enum: `pdf | image`), `importedAt: Date`. **No `@Attribute(.externalStorage)`** — app owns file lifecycle directly. `fileRelativePath` is relative to `Application Support/Documents/`. Per-trip subfolder: `<Application Support>/Documents/<tripUUID>/<docUUID>.<ext>`. `DocumentKind` stored as raw `String` for CloudKit codability.
- **D11** — Import entry point: single toolbar "+" button opening a SwiftUI `Menu` with three items — Scan Document (`VNDocumentCameraViewController` via `UIViewControllerRepresentable`), Choose from Photos (native `PhotosPicker`, `matching: .any(of: [.images])`, single selection), Import from Files (`UIDocumentPickerViewController` via `UIViewControllerRepresentable`, `allowedContentTypes: [.pdf, .image]`, `asCopy: true`). Lazy OS permission prompts. Whitelist: `UTType.pdf` + `UTType.image` (covers JPEG / PNG / HEIC).
- **D12** — Multi-page scan from VisionKit → render all pages into a single `PDFDocument` (PDFKit), write to `<tripUUID>/<docUUID>.pdf`, create ONE `Document` row with `kind = .pdf`. Single-page scans also saved as PDF (unified render path).
- **D13** — Auto-name on import, no modal name prompt:
  - Scan → `"Scan {locale date}"`
  - Photos → `"Photo {locale date}"`
  - Files → source URL `deletingPathExtension().lastPathComponent`
  Rename happens later via long-press context menu.
- **D14** — Viewer: `.fullScreenCover` (not `.sheet`, not push). PDFs render in `PDFKit.PDFView` wrapped in `UIViewRepresentable` (`autoScales = true`, `displayMode = .singlePageContinuous`). Images render in `ScrollView` + `Image(uiImage:)` with `MagnificationGesture` (scale clamped 1…5) + double-tap reset. Minimal chrome (X + centered title). Synchronous file load on main thread — acceptable for < 20 MB files.
- **D15** — Long-press `.contextMenu` is the ONLY surface for rename + delete. Rename → `.alert` with `TextField` (iOS 16+ native TextField-in-alert). Delete → `.confirmationDialog` (destructive role) with copy **"Delete '<displayName>'? This removes the file from your device and cannot be undone."**. No swipe-to-delete on document rows (intentionally diverges from Trip pattern).
- **D16** — Explicit file cleanup, not hooked:
  - On user-initiated document delete: `FileStorage.remove(relativePath:)` (throws caught + logged), then `context.delete(doc)` + `context.save()`.
  - On trip cascade delete: before `context.delete(trip)`, collect doc paths; after `context.save()` succeeds, `removeItem(at: tripFolder)` in one call.
  - No SwiftData `willSave` / `didSave` hooks. No periodic orphan sweep in v1.
  - `FileStorage` is an enum with static methods (no protocol, no DI) — matches Phase 1 no-ViewModel stance.
- **D17** — TripDetail Documents card wired: count + latest `displayName` (or "No documents yet"). Tap → push `AppDestination.documentList(Trip.persistentModelID)`. Requires extending `AppDestination` enum (currently only `.tripDetail(PersistentIdentifier)`).
- **D18** — Concurrency:
  1. User picks source → receive `URL` / `UIImage` / `PDFDocument`.
  2. Detached `Task` (background): generate new doc UUID, write file to disk.
  3. On success: hop to `@MainActor`, insert `Document` via main `ModelContext`, set `trip` relationship, save.
  4. UI shows inline progress (spinner replacing `+` icon).
  - **No `@ModelActor` in v1.** STATE flag: iOS 18 `@ModelActor`-to-main-context merge is confirmed bug territory. Stay on main context.
  - Files imported `asCopy: true` → no security-scoped URL retention after copy.

### Claude's Discretion

- VisionKit bridge coordinator retention pattern detail (Open Question 1 — answered below)
- PhotosPicker Data → disk write implementation (Open Question 3 — answered below)
- Specific `FileManager` API calls for Application Support directory resolution
- Error propagation mechanics (structured throwing Error type vs String logging)
- UIImage → PDFPage rendering fidelity defaults (page size, compression)

### Deferred Ideas (OUT OF SCOPE)

- **DOC-08** (Face ID / passcode lock on Documents) — Phase 6
- Document thumbnails / grid view — v1 is list-only
- OCR, text extraction, auto-categorization
- Multi-select bulk delete
- Share sheet / export
- Inline thumbnail of first page on list rows
- Cross-trip document move
- Annotation / markup
- Localization
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | User can add a document to a trip by scanning (VisionKit, multi-page + perspective correction) | `VNDocumentCameraViewController` bridged via `UIViewControllerRepresentable`; multi-page → single combined PDF via PDFKit. See Pattern 2 + Pattern 5 below |
| DOC-02 | User can add a document to a trip by importing from Photos | Native SwiftUI `PhotosPicker(selection:)` + `loadTransferable(type: Data.self)` → write raw bytes to disk preserving JPEG/HEIC format. See Pattern 3 |
| DOC-03 | User can add a document to a trip by importing PDF or image from Files | `UIDocumentPickerViewController` bridged via `UIViewControllerRepresentable`, `asCopy: true`. Copy source URL → app's Application Support. See Pattern 4 |
| DOC-04 | User can view a document full-screen with pinch-to-zoom (images + PDFs) | `.fullScreenCover` + branched body: `PDFView` (UIViewRepresentable) for PDFs / `ScrollView + Image + MagnificationGesture` for images. See Pattern 6 |
| DOC-05 | User can rename a document after import | `.alert` + `TextField` (iOS 16+ native), disabled-until-non-empty Save button. See Pattern 7 |
| DOC-06 | User can delete a document from a trip | `.contextMenu` → `.confirmationDialog` → `FileStorage.remove` → `modelContext.delete`. See Pattern 8 |
| DOC-07 | Document binaries stored in filesystem (not SwiftData `Data` blobs) with file paths referenced from the model | `FileStorage` enum API + `fileRelativePath: String` on `Document` model. See Pattern 1 + `FileStorage` API below |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

- SwiftUI + SwiftData only; no third-party UI libraries or ORMs.
- iOS 17+ deployment target; iPhone-only.
- Swift 6 strict concurrency enforced.
- Xcode 26.2 / Swift 6.3.1 on dev machine.
- Canonical simulator: iPhone 16e.
- CloudKit-safe conventions: optional inverse relationships, no `@Attribute(.unique)`, no `.deny` delete rules, no inline `Data` blobs on `@Model`.
- All `@Model` types nested inside `TravellifySchemaV1` extension.
- Swift Testing for unit tests; XCTest reserved for UI tests only.
- No ViewModel layer — `@Query` + `@Bindable` + view-local `@Observable` only.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` MUST prefix all `xcodebuild` invocations (xcode-select points to CommandLineTools).

---

## Summary

Phase 2 layers three separate import surfaces (VisionKit scan, PhotosUI picker, UIKit files picker) onto the persistence + navigation skeleton established in Phase 1, plus a full-screen viewer and filesystem-backed `Document` storage. Every third-party-looking requirement resolves to an Apple first-party framework; zero new SwiftPM dependencies enter the tree.

The three highest-risk technical pivots:

1. **VisionKit coordinator retention** — the single most-reported beginner bug when bridging `VNDocumentCameraViewController` into SwiftUI is the coordinator being released before `documentCameraViewController(_:didFinishWith:)` fires. The pattern is well-established (`makeCoordinator()` returns the delegate, stored in the `Context`), but the binding mechanism back to SwiftUI state must not rely on a weak reference.
2. **Swift 6 strict concurrency across the import pipeline** — the import task crosses two isolation domains: a detached `Task` (non-isolated) writes to disk, then hops to `@MainActor` to insert into the `mainContext`. The `Document` must not be captured across the hop — instead, capture the primitive fields (UUID, relative path) and recreate the `Document` inside the `@MainActor` closure. `ModelContext` and `@Model` classes are NOT `Sendable`.
3. **SchemaV1 field additions without migration** — confirmed safe: SwiftData auto-migrates lightweight property additions (new optional / default-valued fields on an existing `@Model`) when no production data exists and when the change is additive. No `SchemaV2` + `MigrationStage` needed. The existing placeholder `Document` (id + trip only from Phase 1) absorbs the new fields cleanly.

The secondary risk is `UIDocumentPickerViewController` + `asCopy: true` + `startAccessingSecurityScopedResource()`. Apple's documentation is not explicit that `asCopy: true` removes the security-scoped resource requirement. Community reports are mixed. **Defensive recommendation:** call `start`/`stopAccessingSecurityScopedResource` anyway — it's a no-op on app-container URLs and there's no downside.

**Primary recommendation:** Build in this order — (1) extend `Document` model in SchemaV1, (2) `FileStorage` enum + tests, (3) `AppDestination.documentList` case, (4) `DocumentListView` skeleton + empty state, (5) the three import bridges one at a time (Files first — simplest; then Photos; then Scan last — most complex coordinator dance), (6) `DocumentViewer` with branch-on-kind, (7) context menu rename + delete, (8) TripDetail card wire-up, (9) trip cascade file cleanup, (10) Swift Testing coverage.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Document metadata persistence | SwiftData (`Document` @Model in SchemaV1) | — | Structured metadata — id, path, name, kind, timestamp |
| Binary file storage | Filesystem (`Application Support/Documents/<tripUUID>/`) | — | DOC-07 mandates filesystem (not SwiftData blobs); own lifecycle |
| File lifecycle orchestration | `FileStorage` enum (static methods) | SwiftUI view (import action) | D16: no hooks; explicit calls at delete time |
| Camera document capture | VisionKit (`VNDocumentCameraViewController`) | UIViewControllerRepresentable bridge | Apple first-party; multi-page + perspective correction out-of-box |
| PDF assembly from scan pages | PDFKit (`PDFDocument.insert(PDFPage, at:)`) | Background `Task` | D12 unifies multi-page scan → one combined PDF |
| Photo selection | PhotosUI (`PhotosPicker`) | — | Native SwiftUI, iOS 16+; no permission prompt needed |
| Photo data → disk | `PhotosPickerItem.loadTransferable(type: Data.self)` + `Data.write(to:)` | Background `Task` | Preserves original JPEG/HEIC bytes; no UIImage quality loss |
| File picker selection | UIKit (`UIDocumentPickerViewController`) | UIViewControllerRepresentable bridge | SwiftUI `.fileImporter` is less flexible for multi-type + `asCopy` |
| File copy from source URL | `FileManager.copyItem(at:to:)` | Background `Task` | `asCopy: true` already produced a local sandbox URL; copy into our structure |
| Viewer — PDF rendering | PDFKit (`PDFView`) | UIViewRepresentable bridge | Built-in pinch-zoom, page navigation, text selection |
| Viewer — image rendering | SwiftUI (`ScrollView` + `Image` + `MagnificationGesture`) | — | Pure SwiftUI; avoids another UIKit bridge |
| Navigation | SwiftUI (`NavigationStack` + extended `AppDestination`) | — | D17: push `.documentList(tripID)` |
| Rename UI | SwiftUI (`.alert` + `TextField`) | — | iOS 16+ native TextField-in-alert |
| Delete UI | SwiftUI (`.confirmationDialog`) | `FileStorage` (file removal) | Matches Phase 1 destructive pattern |
| Import progress indicator | SwiftUI view-local `@State` | — | Replace `+` icon with `ProgressView` while any import Task is in flight |
| Unit tests | Swift Testing (in-memory `ModelContainer` + `FileManager` temp dir) | — | `FileStorage` round-trip tests + model CRUD + cascade |

**Tier correctness check:** Every capability lives in the tier that owns it. No capability incorrectly assigned to a different tier (e.g., file I/O is NOT in the view layer — it's in `FileStorage`; persistence is NOT duplicated across view and store).

---

## Standard Stack

### Core (Phase 2 additions — all Apple first-party)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| VisionKit | iOS 13+ (available well below iOS 17 floor) | `VNDocumentCameraViewController` for camera scan with auto-deskew + multi-page + perspective correction | First-party; the exact feature Apple Notes uses; no third-party scanner SDK justifiable [CITED: developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller] |
| PhotosUI | iOS 16+ (native SwiftUI `PhotosPicker`) | Photos library picker without pre-flight permission sheet | Pure SwiftUI API; no PhotoKit permission prompt needed for the picker itself [CITED: developer.apple.com/documentation/PhotoKit/bringing-photos-picker-to-your-swiftui-app] |
| UIKit (`UIDocumentPickerViewController`) | iOS 11+ | Files app import | No pure SwiftUI equivalent covers `asCopy: true` + multi-type + thin UIViewControllerRepresentable bridge [CITED: developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller] |
| PDFKit (`PDFDocument`, `PDFPage`, `PDFView`) | iOS 11+ | Build multi-page PDFs from scan pages; render PDFs in viewer with pinch-zoom | First-party; handles complex PDF rendering Apple tuned for decades [CITED: developer.apple.com/documentation/pdfkit] |
| UniformTypeIdentifiers (`UTType.pdf`, `UTType.image`) | iOS 14+ | Whitelist file types in `UIDocumentPickerViewController` | Required API; no alternative [CITED: developer.apple.com/documentation/uniformtypeidentifiers] |
| FoundationFileManager + URL | iOS all | Directory creation, file copy, file removal, path resolution | Standard POSIX-like API; no library replaces it |

**Installation:** No package manager changes. All above frameworks are built into iOS — each requires only an `import VisionKit` / `import PhotosUI` / `import PDFKit` / `import UniformTypeIdentifiers` / `import UIKit` statement in the files that use them.

**Version verification:** All frameworks ship with iOS. No version check needed beyond the iOS 17.0 deployment target locked in Phase 1. [VERIFIED: CLAUDE.md stack table + Apple framework documentation]

### Supporting

| Library | Purpose | When to Use |
|---------|---------|-------------|
| Swift Concurrency (`Task`, `@MainActor`, `actor`) | Background file I/O + main-context hop for SwiftData inserts | Every import path (D18) |
| OSLog / `Logger` | Structured logging of file cleanup failures (D16: "throws caught and logged") | `FileStorage.remove` catch blocks; never `print()` file paths in release |

### Alternatives Considered

| Instead of | Could Use | Tradeoff — Why Not |
|------------|-----------|----|
| PDFKit for multi-page assembly | CoreGraphics `CGPDFContextCreateWithURL` | Lower-level; requires manual page boxing, compression tuning. PDFKit's `PDFPage(image:)` init is one line per page [VERIFIED: community article "iOS PDFKit creating PDF document"]. |
| `UIViewControllerRepresentable` bridge for `UIDocumentPickerViewController` | SwiftUI `.fileImporter(isPresented:allowedContentTypes:onCompletion:)` | `.fileImporter` does not support `asCopy: true` — it returns a security-scoped URL that must be accessed + bookmarked. `asCopy: true` simplifies lifecycle [ASSUMED based on documentation reading; confirm at implementation]. |
| `UIViewControllerRepresentable` bridge for `VNDocumentCameraViewController` | DataScannerViewController (iOS 16+) | `DataScannerViewController` is for *live* text / barcode detection, NOT for document capture + perspective-corrected page images. Wrong tool [VERIFIED: Apple docs]. |
| `PhotosPickerItem.loadTransferable(type: Image.self)` | `type: Data.self` | `Image` only supports `public.png` content type [CITED: swiftsenpai.com / SwiftUI PhotosPicker article]. JPEG/HEIC sources fail silently. `Data.self` preserves original bytes. |
| Main-thread file I/O | Background `Task` | `FileManager.copyItem` for PDF/photo files is fast but still blocks the main thread during the write. D18 already locks background Task pattern. |
| `@ModelActor` for import | Main-context insert on `@MainActor` | STATE + CONTEXT D18 explicitly ruled out `@ModelActor` for v1. iOS 18 merge-to-main-context bugs are confirmed bug territory. Researcher confirms this choice — file I/O is the slow work, and SwiftData metadata insert on `mainContext` is cheap (single row, no blob). |
| `@Attribute(.externalStorage)` on a `Data` field | Manual file lifecycle + `fileRelativePath: String` | D10 locked: `externalStorage` hides copy/delete semantics, complicates CloudKit v2 migration (binary assets need separate handling), and doesn't give us the per-trip subfolder structure we want for cascade cleanup. |

---

## Architecture Patterns

### System Architecture Diagram

```
TripDetailView (Phase 1)
  └── Documents SectionCard (Phase 2 wire-up)
        └── tap
        ▼
  NavigationStack.append(.documentList(tripID))
        ▼
  DocumentListView  ─────────── @Query(filter: trip == self.trip) ──► SwiftData
      │                                                              │
      │ toolbar "+" Menu                                              │
      ├── Scan  ──► .sheet ──► ScanView (UIViewControllerRepresentable ── VNDocumentCameraViewController)
      │                                      │ delegate via Coordinator
      │                                      ▼
      │                              [UIImage] pages → background Task
      │                                      │
      │                                      ▼
      │                              PDFKit: assemble PDFDocument
      │                                      │
      │                                      ▼
      │                              FileStorage.write(data: → <tripUUID>/<docUUID>.pdf)
      │                                      │ hop to @MainActor
      │                                      ▼
      │                              Insert Document (metadata only) into mainContext ──► SwiftData
      │
      ├── Photos ──► PhotosPicker (native) ──► PhotosPickerItem.loadTransferable(type: Data.self)
      │                                      │ background Task
      │                                      ▼
      │                              FileStorage.write(data: → <tripUUID>/<docUUID>.<jpg|heic|png>)
      │                                      │ @MainActor
      │                                      ▼
      │                              Insert Document (kind = .image) into mainContext
      │
      └── Files  ──► .sheet ──► FilesImporter (UIViewControllerRepresentable ── UIDocumentPickerViewController, asCopy: true)
                                             │ delegate URL
                                             │ background Task
                                             ▼
                                   FileManager.copyItem(from: source → <tripUUID>/<docUUID>.<pdf|image>)
                                             │ @MainActor
                                             ▼
                                   Insert Document into mainContext

  DocumentListView (continued)
      │ row tap ──► .fullScreenCover ──► DocumentViewer
      │                                         │ branch on doc.kind
      │                                         ├── .pdf   ──► PDFView (UIViewRepresentable)
      │                                         └── .image ──► ScrollView + Image + MagnificationGesture
      │
      └── row long-press ──► .contextMenu
                                  ├── Rename ──► .alert + TextField ──► context.save()
                                  └── Delete ──► .confirmationDialog ──► FileStorage.remove → context.delete → save

  Trip cascade delete (Phase 1 flow)
      │ before context.delete(trip):
      │   let paths = trip.documents?.map(\.fileRelativePath) ?? []
      │ after context.save():
      │   FileStorage.removeTripFolder(tripID)
```

### Recommended Project Structure (additive to Phase 1)

```
Travellify/
├── App/
│   └── AppDestination.swift          # EXTEND: add .documentList(PersistentIdentifier)
│
├── Models/
│   └── Document.swift                # EXTEND SchemaV1: add displayName, fileRelativePath, kind, importedAt + DocumentKind enum
│
├── Features/
│   └── Documents/                    # NEW
│       ├── DocumentListView.swift
│       ├── DocumentViewer.swift
│       ├── DocumentRow.swift
│       ├── EmptyDocumentsView.swift
│       └── Import/
│           ├── ScanView.swift                   # UIViewControllerRepresentable for VNDocumentCameraViewController
│           ├── PhotosImporter.swift             # PhotosPicker host + loadTransferable pipeline
│           └── FilesImporter.swift              # UIViewControllerRepresentable for UIDocumentPickerViewController
│
├── Services/                         # NEW folder (justified: FileStorage is not a view)
│   └── FileStorage.swift             # enum with static methods
│
└── Shared/
    └── DocumentKind.swift            # (or inline inside Document.swift)
```

**Why `Services/` is justified here despite D8 "no ViewModel" stance:** `FileStorage` is not a ViewModel — it's a domain service (filesystem abstraction). D8 prohibits view↔data adapters, not all non-view code. An enum with static methods that wraps `FileManager` is a legitimate place-to-put-file-I/O — same shape Phase 1 used for small helpers.

---

### Pattern 1: `Document` Model Extension in SchemaV1

**What:** Add the D10 fields to the existing placeholder `Document` inside `TravellifySchemaV1`. Fields are additive with defaults — SwiftData auto-migrates without a `MigrationStage`.

**When to use:** First task in Phase 2. Blocks every downstream task.

```swift
// Source: CONTEXT.md D10 + Phase 1 RESEARCH.md Pattern 3 (placeholder Document)
// [VERIFIED: SwiftData additive property additions are lightweight migrations per Apple WWDC24]
// File: Models/Document.swift

import Foundation
import SwiftData

enum DocumentKind: String, Codable, CaseIterable {
    case pdf
    case image
}

extension TravellifySchemaV1 {
    @Model
    final class Document {
        var id: UUID = UUID()
        var trip: Trip?                       // optional inverse — CloudKit rule (unchanged from Phase 1)

        // NEW in Phase 2 — all with default values to allow lightweight migration
        var displayName: String = ""
        var fileRelativePath: String = ""     // "<tripUUID>/<docUUID>.<ext>" relative to base dir
        var kindRaw: String = DocumentKind.pdf.rawValue
        var importedAt: Date = Date()

        // Computed — NOT a stored property (no CloudKit concern)
        var kind: DocumentKind {
            get { DocumentKind(rawValue: kindRaw) ?? .pdf }
            set { kindRaw = newValue.rawValue }
        }
    }
}
```

**CloudKit-safety checklist:**
- [x] All stored properties have default values (required for CloudKit auto-migration to v2)
- [x] No `@Attribute(.unique)`
- [x] No `.deny` delete rule
- [x] Inverse `trip: Trip?` is optional
- [x] No inline `Data` blobs — path is a `String`
- [x] Enum stored as raw `String` — primitive type; CloudKit-codable

**Open Question 4 answer — SchemaV2 or extend SchemaV1?**

**Extend SchemaV1 directly.** Rationale:
1. No production data exists (app has not shipped).
2. All new properties have default values → SwiftData performs a lightweight migration automatically.
3. Bumping to SchemaV2 requires writing a `MigrationStage.lightweight(fromVersion: .v1, toVersion: .v2)` in `TravellifyMigrationPlan.stages` AND duplicating all unchanged models into a `TravellifySchemaV2` enum — pure ceremony with no benefit before first ship.
4. Apple's WWDC24 / WWDC25 guidance: "version the schema when you ship a change to users in production." Pre-v1.0 internal iteration does not require version bumps. [CITED: Apple WWDC24 "What's new in SwiftData"]

**When will we need SchemaV2?** The first post-TestFlight release that adds a new `@Model` type or changes an existing relationship. Probably Phase 6 (v1 polish) or later. Not Phase 2.

**Confidence:** HIGH — verified against WWDC24 + AzamSharp 2026 article + Phase 1 research.

---

### Pattern 2: `ScanView` — VisionKit Bridge with Coordinator Retention

**What:** `UIViewControllerRepresentable` wrapping `VNDocumentCameraViewController`. The critical trick is the coordinator delegate lifecycle — SwiftUI retains the `Coordinator` in the `Context`, so the coordinator survives as long as the SwiftUI view is in the view tree.

**When to use:** Scan menu item triggers `.sheet` presenting `ScanView`.

**Open Question 1 answer — VisionKit coordinator lifecycle on iOS 17/18:**

The standard `makeCoordinator()` → stored-in-Context pattern IS the current working pattern. Community reports of "coordinator deallocated mid-scan" usually trace to one of these anti-patterns:

1. **Coordinator stored `weak` in the representable** — don't. The Context retains it strongly.
2. **Presenting sheet from a view that itself dismisses early** — if the parent view re-renders and the sheet binding flips to false, the sheet + its content (the representable + the coordinator) are torn down. Guard the scan state with a stable `@State` on the parent.
3. **Calling completion callbacks after the VC is dismissed** — VisionKit's delegate calls fire BEFORE the VC is dismissed; don't dismiss inside `makeUIViewController` or in `updateUIViewController` based on a stale binding.

```swift
// Source: [VERIFIED: scanbot.io tutorial 2024 + fatbobman.com VisionKit article + Apple docs]
// File: Features/Documents/Import/ScanView.swift

import SwiftUI
import VisionKit
import UIKit

struct ScanView: UIViewControllerRepresentable {
    /// Called on successful scan. Pages are returned as UIImages; caller assembles PDF.
    let onFinish: ([UIImage]) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // Intentionally empty — VNDocumentCameraViewController has no reactive state to sync.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ScanView

        init(_ parent: ScanView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Extract all pages up front — `scan` is a reference type and may be
            // invalidated after the VC dismisses in some iOS versions.
            var pages: [UIImage] = []
            for i in 0..<scan.pageCount {
                pages.append(scan.imageOfPage(at: i))
            }
            parent.onFinish(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onError(error)
        }
    }
}
```

**Host view usage:**

```swift
// Inside DocumentListView
@State private var showScan = false

.sheet(isPresented: $showScan) {
    ScanView(
        onFinish: { pages in
            showScan = false
            importScanResult(pages, for: trip)  // spawns background Task
        },
        onCancel: { showScan = false },
        onError: { err in
            showScan = false
            importErrorMessage = "Couldn't add document. Please try again."
        }
    )
    .ignoresSafeArea()
}
```

**Swift 6 strict concurrency note:** The `Coordinator` is `NSObject` subclass + `VNDocumentCameraViewControllerDelegate` (which is `@MainActor`-inferred on iOS via the UIKit headers). No explicit `@MainActor` annotation needed; callbacks fire on main actor automatically. When handing off pages to the background Task, pass `pages: [UIImage]` by value-capture — `UIImage` is `Sendable` (annotated `@unchecked Sendable` by Apple on iOS 17+). [VERIFIED: Apple UIKit Sendable annotations, iOS 17]

**Info.plist requirement:** `NSCameraUsageDescription` key must be present. Copy: `"Allow Travellify to use the camera to scan documents."` OS prompts on first scan automatically (D11: lazy permissions).

**Confidence:** HIGH on the coordinator pattern (verified across Apple docs + scanbot.io 2024 article + fatbobman 2023 VisionKit article + Apple Developer Forums patterns). MEDIUM on the "pages should be extracted up front" precaution — it's defensive; I have not seen a documented iOS 17+ invalidation bug, but the `VNDocumentCameraScan` is a reference and the pattern costs nothing.

---

### Pattern 3: `PhotosImporter` — PhotosPicker → Data → Disk

**What:** Native SwiftUI `PhotosPicker` + `loadTransferable(type: Data.self)` → write raw bytes to disk preserving original JPEG/HEIC/PNG format.

**When to use:** Photos menu item.

**Open Question 3 answer — PhotosPicker → disk without UIImage quality loss:**

Use `loadTransferable(type: Data.self)`, NOT `type: Image.self` or manual `UIImage(data:)` → `jpegData(compressionQuality:)`. Reasoning:

1. `Image` only supports `public.png` content type — JPEG and HEIC sources either fail or silently re-encode [VERIFIED: Swift Senpai article + Apple Developer Forums thread 709764].
2. Going `Data → UIImage → UIImage.jpegData(compressionQuality:)` re-encodes. Even at quality 1.0, JPEG→JPEG re-encode is not lossless. HEIC has no `heicData` API on `UIImage` at all.
3. Raw `Data` preserves the original container format byte-for-byte.

The content type can be sniffed from `PhotosPickerItem.supportedContentTypes` to determine the correct file extension:

```swift
// Source: [VERIFIED: Swift Senpai "How to Use the SwiftUI PhotosPicker" + Apple Developer Forums 709764]
// File: Features/Documents/Import/PhotosImporter.swift

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@MainActor
func importPhotosPickerItem(
    _ item: PhotosPickerItem,
    into trip: Trip,
    modelContext: ModelContext,
    onProgress: @escaping (ImportState) -> Void
) {
    onProgress(.inProgress)

    Task.detached(priority: .userInitiated) {
        do {
            // Load raw bytes — preserves JPEG / HEIC / PNG container format
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run { onProgress(.failed) }
                return
            }

            // Determine extension from the item's primary supported content type
            let ext = fileExtension(for: item.supportedContentTypes) ?? "jpg"

            let docID = UUID()
            let tripIDString = await MainActor.run { trip.id.uuidString }
            let relativePath = "\(tripIDString)/\(docID.uuidString).\(ext)"
            try FileStorage.write(data: data, toRelativePath: relativePath)

            // Hop to MainActor for SwiftData insert — capture primitives only, NOT the Trip reference
            await MainActor.run {
                let doc = Document()
                doc.id = docID
                doc.displayName = "Photo " + Self.localizedDateString()
                doc.fileRelativePath = relativePath
                doc.kind = .image
                doc.importedAt = Date()
                doc.trip = trip
                modelContext.insert(doc)
                try? modelContext.save()
                onProgress(.success)
            }
        } catch {
            await MainActor.run { onProgress(.failed) }
        }
    }
}

private func fileExtension(for types: [UTType]) -> String? {
    // Prefer heic > jpeg > png > first declared
    if types.contains(where: { $0.conforms(to: .heic) }) { return "heic" }
    if types.contains(where: { $0.conforms(to: .jpeg) }) { return "jpg" }
    if types.contains(where: { $0.conforms(to: .png)  }) { return "png" }
    return types.first?.preferredFilenameExtension
}
```

**Swift 6 concurrency pattern: primitives across actor hop**

The `Task.detached` closure must NOT capture `trip` (a `@Model` class, not `Sendable`) or `modelContext` (also not `Sendable`). Pattern:

1. Before the Task: read the primitive (`trip.id` — `UUID`, `Sendable`) on the current actor.
2. Inside the Task: work only with `Sendable` primitives.
3. On the hop back to `@MainActor`: re-fetch / re-reference the `Trip` by ID from the main context if needed, OR (since `trip` is value-captured from the enclosing `@MainActor` closure as a reference) re-reference it safely inside `MainActor.run`.

Actually — rethinking — the cleaner pattern is: **run the entire import as a `@MainActor` async function; use `Task.detached` only for the disk I/O sub-step**, passing `Data` (Sendable) across the boundary:

```swift
// Cleaner Swift 6 pattern
@MainActor
func importPhotosPickerItem(...) async {
    onProgress(.inProgress)
    do {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            onProgress(.failed); return
        }
        let ext = fileExtension(for: item.supportedContentTypes) ?? "jpg"
        let docID = UUID()
        let relativePath = "\(trip.id.uuidString)/\(docID.uuidString).\(ext)"

        // Hop only the write() off main
        try await Task.detached(priority: .userInitiated) {
            try FileStorage.write(data: data, toRelativePath: relativePath)
        }.value

        // Back on @MainActor implicitly (awaited a Task that returned)
        let doc = Document()
        doc.id = docID
        doc.displayName = "Photo " + localizedDateString()
        doc.fileRelativePath = relativePath
        doc.kind = .image
        doc.importedAt = Date()
        doc.trip = trip
        modelContext.insert(doc)
        try modelContext.save()
        onProgress(.success)
    } catch {
        onProgress(.failed)
    }
}
```

This minimizes the `@MainActor` ↔ non-isolated boundary crossings and makes the Sendable story trivial (`Data` is `Sendable`).

**Info.plist requirement:** `NSPhotoLibraryUsageDescription` is NOT required for PhotosPicker — PhotosPicker runs out-of-process and does not trigger the permission prompt. [VERIFIED: Apple docs + multiple community sources]

**Confidence:** HIGH on the `Data.self` transferable pattern. HIGH on PhotosPicker not needing a usage description. MEDIUM on the exact Swift 6 `Sendable` gymnastics around `Task.detached` for the write — the pattern works but the final form may need one round of compiler feedback.

---

### Pattern 4: `FilesImporter` — UIDocumentPickerViewController Bridge

**What:** `UIViewControllerRepresentable` wrapping `UIDocumentPickerViewController(forOpeningContentTypes:asCopy:)` with types `[.pdf, .image]` and `asCopy: true`. The callback returns a URL (already copied into a sandbox temp location by the system because `asCopy: true`); we then copy it into our structured location.

**When to use:** Files menu item.

**Open Question 6 answer — `asCopy: true` vs `startAccessingSecurityScopedResource()`:**

Apple's documentation does not explicitly state that `asCopy: true` eliminates the security-scoped resource requirement. Community reports [Apple Developer Forums 713814, useyourloaf.com]: calling `startAccessingSecurityScopedResource` on an app-container URL is a no-op and returns `true`. The defensive pattern is to call it anyway:

```swift
let didStart = url.startAccessingSecurityScopedResource()
defer { if didStart { url.stopAccessingSecurityScopedResource() } }
```

This is safe for both `asCopy: true` URLs (where it's a no-op) and any future `asCopy: false` refactor. Cost: one line. Benefit: zero risk of silent read failure.

```swift
// Source: [VERIFIED: Apple Developer Forums 713814 + useyourloaf.com + nemecek.be blog]
// File: Features/Documents/Import/FilesImporter.swift

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FilesImporter: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .image],
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilesImporter

        init(_ parent: FilesImporter) {
            self.parent = parent
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else { parent.onCancel(); return }
            parent.onPicked(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}
```

**Import task (called from host view after `onPicked`):**

```swift
@MainActor
func importFileURL(_ url: URL, into trip: Trip, modelContext: ModelContext, onProgress: ...) async {
    onProgress(.inProgress)
    do {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let sourceName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
        let docID = UUID()
        let relativePath = "\(trip.id.uuidString)/\(docID.uuidString).\(ext)"

        try await Task.detached(priority: .userInitiated) {
            try FileStorage.copy(from: url, toRelativePath: relativePath)
        }.value

        let kind: DocumentKind = (ext.lowercased() == "pdf") ? .pdf : .image
        let doc = Document()
        doc.id = docID
        doc.displayName = sourceName
        doc.fileRelativePath = relativePath
        doc.kind = kind
        doc.importedAt = Date()
        doc.trip = trip
        modelContext.insert(doc)
        try modelContext.save()
        onProgress(.success)
    } catch {
        onProgress(.failed)
    }
}
```

**Confidence:** HIGH on bridge shape. MEDIUM on `asCopy: true` security-scoped behavior (defensive pattern mitigates). **Flagged pitfall:** The source URL given to us by the system with `asCopy: true` is a temporary file; copy it out BEFORE any `await` that might let the system clean it up. The `Task.detached` pattern above does this immediately.

---

### Pattern 5: PDFKit Multi-Page Assembly from Scan Pages

**What:** Given `[UIImage]` from `VNDocumentCameraScan`, build a `PDFDocument`, write to disk.

**When to use:** Inside the Scan import Task.

**Open Question 2 answer — PDFKit write-to-URL off main thread safe on iOS 17.x?**

`PDFDocument.write(to: URL)` is a synchronous CPU+I/O operation. No Apple documentation forbids background-thread use. Community experience [Apple Developer Forums PDFKit tag, dev.to article on PDFKit]: safe for typical document counts (< 50 pages). Known issues cluster around:

1. `PDFView` rendering (main-thread only — UIKit view) — NOT relevant to write-to-URL.
2. Large embedded images not releasing memory until the `PDFDocument` is released — relevant to us only if we build a 100+ page PDF. Scan is bounded to normal document sizes.
3. iOS 16 had a regression where `PDFDocument.insert(PDFPage(image:), at:)` rendered a blank page [Apple Developer Forums 717692]. **Resolved in iOS 17.** [VERIFIED: thread 717692 follow-ups]

```swift
// Source: [VERIFIED: dev.to PDFKit article + Apple Developer Forums 717692 + Apple WWDC22 "What's new in PDFKit"]
// File: Services/FileStorage.swift (or Features/Documents/Import/ScanPDFAssembler.swift)

import PDFKit
import UIKit

enum ScanPDFAssembler {
    /// Assembles [UIImage] pages into a single PDF data blob.
    /// Callable from any isolation context (no main-actor dependency).
    static func assemble(pages: [UIImage]) throws -> Data {
        let pdfDocument = PDFDocument()
        for (index, image) in pages.enumerated() {
            guard let page = PDFPage(image: image) else {
                throw FileStorageError.pdfPageCreationFailed(index: index)
            }
            pdfDocument.insert(page, at: index)
        }
        guard let data = pdfDocument.dataRepresentation() else {
            throw FileStorageError.pdfSerializationFailed
        }
        return data
    }
}
```

**Why `dataRepresentation()` instead of `write(to:)`:** Returning `Data` keeps the assembler pure (no filesystem side effects) and lets `FileStorage.write(data:toRelativePath:)` be the single I/O API surface. Also sidesteps any historical `write(to:)` bugs. [VERIFIED: `dataRepresentation()` is declared on `PDFDocument` and returns the PDF bytes; Apple docs]

**Scan import task:**

```swift
@MainActor
func importScanResult(_ pages: [UIImage], into trip: Trip, modelContext: ModelContext, onProgress: ...) async {
    onProgress(.inProgress)
    do {
        let docID = UUID()
        let relativePath = "\(trip.id.uuidString)/\(docID.uuidString).pdf"

        try await Task.detached(priority: .userInitiated) {
            let pdfData = try ScanPDFAssembler.assemble(pages: pages)
            try FileStorage.write(data: pdfData, toRelativePath: relativePath)
        }.value

        let doc = Document()
        doc.id = docID
        doc.displayName = "Scan " + localizedDateString()
        doc.fileRelativePath = relativePath
        doc.kind = .pdf
        doc.importedAt = Date()
        doc.trip = trip
        modelContext.insert(doc)
        try modelContext.save()
        onProgress(.success)
    } catch {
        onProgress(.failed)
    }
}
```

**`[UIImage]` Sendable across actor hop:** `UIImage` is marked `@unchecked Sendable` in the UIKit overlay as of iOS 17. Passing an array of them into `Task.detached` compiles under Swift 6 strict concurrency. [VERIFIED: Apple UIKit headers + Swift evolution notes on Sendable conformance for Cocoa types]

**Confidence:** HIGH on the assembly pattern. HIGH on iOS 17 having fixed the iOS 16 blank-page regression. MEDIUM on the "write-to-URL off main thread is safe" — community experience positive, no official statement either way.

---

### Pattern 6: `DocumentViewer` — Branch on Kind

```swift
// Source: CONTEXT.md D14 + UI-SPEC.md viewer chrome spec
// File: Features/Documents/DocumentViewer.swift

import SwiftUI
import PDFKit

struct DocumentViewer: View {
    let document: Document
    @Environment(\.dismiss) private var dismiss

    @State private var imageScale: CGFloat = 1.0
    @State private var lastImageScale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                if let fileURL = FileStorage.resolveURL(for: document) {
                    switch document.kind {
                    case .pdf:
                        PDFKitView(url: fileURL)
                    case .image:
                        imageBody(url: fileURL)
                    }
                } else {
                    errorBody
                }
            }

            topChrome
        }
    }

    private func imageBody(url: URL) -> some View {
        ScrollView([.horizontal, .vertical]) {
            if let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(imageScale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                imageScale = min(max(lastImageScale * value, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastImageScale = imageScale
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            imageScale = 1.0
                            lastImageScale = 1.0
                        }
                    }
                    .accessibilityLabel(document.displayName)
            } else {
                errorBody
            }
        }
    }

    private var errorBody: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("This document is unavailable.")
                .foregroundStyle(.secondary)
        }
    }

    private var topChrome: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")

            Spacer(minLength: 8)

            Text(document.displayName)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Color.clear.frame(width: 44, height: 44) // symmetry placeholder
        }
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
```

**Main-thread file load OK?** Per D14: yes for < 20 MB files. `UIImage(contentsOfFile:)` and `PDFDocument(url:)` are synchronous but fast for typical document sizes. If a user ever imports a 50 MB PDF we revisit — out of scope for v1.

---

### Pattern 7: Rename UI (`.alert` + `TextField`)

```swift
// Source: UI-SPEC.md + D15 — iOS 16+ native TextField-in-alert
.alert("Rename Document", isPresented: $isRenaming, presenting: targetDocument) { doc in
    TextField("Name", text: $draftName)
    Button("Save") {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        doc.displayName = trimmed
        try? modelContext.save()
    }
    .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
    Button("Cancel", role: .cancel) { }
}
```

**Note:** `.disabled` on an alert `Button` is iOS 17+ [VERIFIED: Apple docs]. iOS 16 shows the button enabled and the empty-name early-return silently no-ops. Since deployment target is iOS 17, the disabled affordance works.

---

### Pattern 8: Delete UI + File Cleanup (`.confirmationDialog`)

```swift
// Source: CONTEXT.md D15 + D16
.confirmationDialog(
    "Delete \"\(targetDoc?.displayName ?? "")\"?",
    isPresented: $isConfirmingDelete,
    titleVisibility: .visible,
    presenting: targetDoc
) { doc in
    Button("Delete", role: .destructive) {
        // Step 1: remove file — throws caught and LOGGED (not shown to user)
        do {
            try FileStorage.remove(relativePath: doc.fileRelativePath)
        } catch {
            Logger.fileStorage.error("File cleanup failed for \(doc.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        // Step 2: delete model — error here DOES surface to user
        modelContext.delete(doc)
        do {
            try modelContext.save()
        } catch {
            errorAlertMessage = "Couldn't delete. Please try again."
        }
    }
    Button("Cancel", role: .cancel) { }
} message: { _ in
    Text("This removes the file from your device and cannot be undone.")
}
```

---

### Pattern 9: Extended `AppDestination`

```swift
// Source: CONTEXT.md D17
import SwiftData

enum AppDestination: Hashable {
    case tripDetail(PersistentIdentifier)
    case documentList(PersistentIdentifier)      // NEW in Phase 2
}
```

**Navigation routing** in the `NavigationStack`'s `.navigationDestination(for: AppDestination.self)` switch block gets a new case:

```swift
case .documentList(let tripID):
    if let trip = modelContext.model(for: tripID) as? Trip {
        DocumentListView(trip: trip)
    } else {
        Text("Trip not found").foregroundStyle(.secondary)
    }
```

---

### Pattern 10: Trip Cascade Delete — File Cleanup

**What:** The Phase 1 trip delete flow invokes `modelContext.delete(trip)`. SwiftData cascades to `Document` model rows (Phase 1 `@Relationship(deleteRule: .cascade)`). BUT SwiftData does NOT touch files on disk. We manually remove the trip folder after the cascade.

**When to use:** Intercept the existing Phase 1 trip-delete action in `TripRow` / `TripListView`.

```swift
// Source: CONTEXT.md D16
func deleteTrip(_ trip: Trip) {
    let tripIDString = trip.id.uuidString
    modelContext.delete(trip)
    do {
        try modelContext.save()  // cascade runs here
        // After save succeeds, remove the folder in one call
        try? FileStorage.removeTripFolder(tripIDString: tripIDString)
    } catch {
        errorAlertMessage = "Couldn't delete. Please try again."
    }
}
```

**Test requirement:** Swift Testing — `deleteTripRemovesDocumentFolder` — inserts a Trip with 2 Documents whose files exist on disk, deletes the Trip, asserts the `<tripUUID>/` folder is gone.

---

## `FileStorage` API Contract

Enum with static methods. Single surface for all filesystem operations. No protocol, no DI (D16 lock).

```swift
// File: Services/FileStorage.swift

import Foundation
import OSLog

enum FileStorage {

    // MARK: - Base directory

    /// "<AppSupport>/Documents/". Created if missing. Throws if FileManager refuses.
    static func baseDirectory() throws -> URL { ... }

    // MARK: - Path resolution

    /// Resolves an on-disk URL for the given document, or nil if the file is missing.
    static func resolveURL(for document: Document) -> URL? { ... }

    /// "<AppSupport>/Documents/<tripUUIDString>/" — created if missing.
    static func tripFolder(tripIDString: String) throws -> URL { ... }

    // MARK: - Write

    /// Writes data to "<base>/<relativePath>". Ensures parent dir exists.
    /// Caller provides relativePath in the form "<tripUUID>/<docUUID>.<ext>".
    static func write(data: Data, toRelativePath relativePath: String) throws { ... }

    /// Copies a file from an external source URL to "<base>/<relativePath>".
    /// Handles security-scoped resource start/stop defensively.
    static func copy(from sourceURL: URL, toRelativePath relativePath: String) throws { ... }

    // MARK: - Remove

    /// Removes the single file at "<base>/<relativePath>". Throws if remove fails.
    /// Missing-file is NOT an error (returns normally).
    static func remove(relativePath: String) throws { ... }

    /// Removes the entire "<base>/<tripUUIDString>/" subtree in one call.
    static func removeTripFolder(tripIDString: String) throws { ... }
}

enum FileStorageError: Error {
    case baseDirectoryUnavailable
    case writeFailed(path: String, underlying: Error)
    case copyFailed(source: URL, destination: URL, underlying: Error)
    case pdfPageCreationFailed(index: Int)
    case pdfSerializationFailed
}

extension Logger {
    static let fileStorage = Logger(subsystem: "com.travellify.app", category: "FileStorage")
}
```

**Application Support vs Documents directory — Open Question 5 answer:**

- **Use `Application Support`** (D10 already locks this). Rationale:
  1. Not user-visible via iOS Files app (unless the app opts in via `LSSupportsOpeningDocumentsInPlace` + `UIFileSharingEnabled`, which we don't).
  2. Backed up by iCloud by default — but the user-visible iCloud Device Backup size is dominated by these bytes. For a travel-companion app with maybe 50–100 MB of scans per user, this is acceptable; larger apps exclude from backup via `URLResourceKey.isExcludedFromBackupKey`.
  3. Survives app updates (same as Documents). Does NOT survive app deletion (same as Documents).
  4. App Store rules [VERIFIED: Apple File System Programming Guide, "iOS Standard Directories"]: user-generated content that the user would recreate from cloud sources on restore should use `Application Support` with `isExcludedFromBackupKey = true`. User-generated content with no re-creation path should use `Documents` OR `Application Support` backed up.
  5. Our documents ARE user-generated (scans) with no re-creation path → backup is appropriate. `Application Support` is the right bucket for app-internal user content not exposed via Files app.

**Storage guidance for v1:** No explicit cap. At 100 MB typical usage (per STATE / CONTEXT) we stay well under the App Store "must provide on-demand cleanup UI" threshold (~1 GB is the informal bar). If bug reports surface "iCloud backup too large" in post-launch telemetry, add `isExcludedFromBackupKey = true` on the `Documents/` subfolder in Phase 6 polish.

**Confidence:** HIGH on directory choice. MEDIUM on backup semantics (Apple's guidance is narrative, not prescriptive, and varies across documents).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Document scanning with auto-deskew and multi-page capture | Custom `AVCaptureSession` + rectangle detection + perspective transform | `VNDocumentCameraViewController` | Apple's implementation handles edge detection, auto-capture, perspective correction, lighting adaptation — years of tuning. Custom version would be 1000+ LOC and inferior |
| Photos library picker with permission-free UX | Custom `PHPickerViewController` bridge with own permission flow | Native SwiftUI `PhotosPicker` | Permission-free by design (out-of-process picker). Zero third-party code surface |
| Files app integration with file type filter | Custom file browser UI | `UIDocumentPickerViewController` (or SwiftUI `.fileImporter` if `asCopy: true` is not needed) | iOS-native file picker with correct sandbox semantics |
| Multi-page PDF assembly | Custom CoreGraphics `CGPDFContext` loop | `PDFDocument.insert(PDFPage(image:), at:)` | One line per page; PDFKit handles compression, page sizing, metadata |
| PDF rendering with pinch-zoom + scrolling | Custom `UIScrollView` + `CGPDFDocument` rendering | `PDFKit.PDFView` | Built-in zoom, gestures, page navigation, text selection, VoiceOver |
| Image zoom viewer | Custom `UIScrollView` + `UIImageView` | SwiftUI `ScrollView` + `Image` + `MagnificationGesture` | Pure SwiftUI for a simple use case; UIKit scroll view only needed for very large images with tile-based rendering (out of scope) |
| File I/O abstraction | Custom protocol + `class FileService` + DI container | `enum FileStorage { static func ... }` | D16 explicitly rules out protocols/DI. Matches Phase 1 no-ViewModel stance |
| Unique filename generation | Timestamp-based custom scheme | `UUID().uuidString` per document | D10 lock; UUID is collision-resistant and sortable-enough |
| Document rename with live validation | Custom modal sheet | `.alert` + `TextField` (iOS 16+) | Native affordance; standard Apple rename UX |
| Destructive action with copy | Custom modal | `.confirmationDialog` with destructive role Delete button | Matches Phase 1 pattern; iOS native sheet |
| Background file write with UI progress | Custom operation queue + KVO progress | Swift Concurrency `Task.detached` + view-local `@State` progress flag | iOS 15+ `async/await` is the answer |
| SwiftData concurrency for metadata-only writes | `@ModelActor` for the import pipeline | Main-context insert on `@MainActor` after background file I/O completes | D18 + STATE: iOS 18 `@ModelActor` merge bugs. Metadata insert is trivial — main context suffices |

**Key insight:** Phase 2's value proposition is integration, not invention. Every "hard" problem (scanning, picking photos, picking files, rendering PDFs) has a first-party Apple solution. The work is wiring them together correctly, not building them from scratch.

---

## Runtime State Inventory

> Phase 2 is greenfield feature work on a pre-production app. There is no prior persistent state to migrate.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no shipped users; no existing documents on any device; placeholder `Document` model from Phase 1 has no instances | None |
| Live service config | None — local-only app, no backend, no CloudKit sync in v1 | None |
| OS-registered state | None — no Task Scheduler, no launchd, no background tasks registered yet; `NSCameraUsageDescription` added to Info.plist is static config not runtime state | None |
| Secrets/env vars | None — no API keys, no OAuth, no credentials | None |
| Build artifacts | None that reference documents; Phase 1 project.pbxproj will need new Swift files added to the `Travellify` target — this is a build-system edit, not a stale artifact | Add new files to Xcode target manually or via `xcodebuild` (Option A/B from Phase 1 scaffold). Verify `Info.plist` updates survive GUI reopens |

**Nothing found in category:** For every category above, the phrase is literal — there is no pre-existing state because the app has not shipped.

---

## Common Pitfalls

### Pitfall 1: Capturing Non-Sendable Types Across Actor Hop

**What goes wrong:** Writing `Task.detached { ... }` inside a `@MainActor` function and capturing `trip` (a `@Model` class) or `modelContext`. Swift 6 rejects with "Sending main actor-isolated 'trip' across concurrency boundary."

**Why it happens:** `@Model` classes and `ModelContext` are not `Sendable` in Swift 6. The compiler correctly rejects the capture.

**How to avoid:** Before entering the `Task.detached`, extract `Sendable` primitives (UUID strings, `Data`, plain `String`s). Re-fetch / re-reference the `@Model` on the hop back to `@MainActor`. See Pattern 3 cleaned-up form.

**Warning signs:** Compiler error "Sending ... across concurrency boundary" around the `Task.detached` block.

### Pitfall 2: VisionKit Coordinator Deallocated Before didFinishWith Fires

**What goes wrong:** The scan completes but `onFinish` never fires.

**Why it happens:** The representable's `Context` is torn down before VisionKit calls the delegate. Usually triggered by a parent view re-rendering and toggling the `.sheet` binding during the scan.

**How to avoid:** Store `showScan` as a stable `@State` on the outer `DocumentListView`. Do NOT bind the sheet to a computed property or a value derived from `@Query` results that can re-fire during the scan.

**Warning signs:** Tester reports: "I scanned 3 pages, tapped Save, nothing happens."

### Pitfall 3: PhotosPicker Returns Nil Data

**What goes wrong:** `item.loadTransferable(type: Data.self)` returns `nil` and we silently create no document.

**Why it happens:** The asset may be in iCloud Photos and not yet downloaded; the transferable load can fail without throwing.

**How to avoid:** Treat `nil` as an import failure — surface the error copy from UI-SPEC Error States: "Couldn't add document. Please try again." [VERIFIED: Apple Developer Forums 749531 notes iCloud-Photos-not-downloaded is a common nil cause]

**Warning signs:** User reports "I picked a photo but nothing was added." Usually when they used an iCloud Optimized Storage photo that hasn't hydrated locally.

### Pitfall 4: `UIDocumentPickerViewController` Callback URL Invalidates Before Copy

**What goes wrong:** The system gives us a URL in `documentPicker(_:didPickDocumentsAt:)`. By the time our background `Task` runs, the file is gone.

**Why it happens:** Even with `asCopy: true`, the URL points to a temporary sandbox location that the system may clean up after the delegate callback returns.

**How to avoid:** Copy the file in the delegate callback synchronously (or immediately kick off `Task.detached { try FileStorage.copy(from:to:) }` that starts before the VC dismisses). The Pattern 4 implementation does this correctly.

**Warning signs:** Intermittent "Couldn't add document" errors, especially under memory pressure or when user re-opens picker quickly.

### Pitfall 5: PDF Assembly Creates Blank Pages on iOS 16 (historic)

**What goes wrong:** `PDFPage(image:)` creates a page that renders blank in `PDFView`.

**Why it happens:** iOS 16 PDFKit regression [Apple Developer Forums 717692].

**How to avoid:** iOS 17 deployment target (locked in CLAUDE.md). iOS 16 is below our floor and not a target.

**Warning signs:** Scanned PDFs open in viewer with blank pages. If this appears on iOS 17, file a radar — not an expected issue.

### Pitfall 6: Application Support Directory Does Not Exist Yet

**What goes wrong:** First write to `Application Support/Documents/<tripUUID>/<docUUID>.pdf` fails with "No such file or directory."

**Why it happens:** iOS creates `Application Support` lazily — it may not exist on first app launch. Our `<tripUUID>/` subfolder definitely doesn't exist until we create it.

**How to avoid:** `FileStorage.baseDirectory()` and `FileStorage.tripFolder(tripIDString:)` MUST use `FileManager.default.createDirectory(at:, withIntermediateDirectories: true)` every time. `createDirectory` with `withIntermediateDirectories: true` is idempotent — succeeds silently if the dir exists.

**Warning signs:** First-ever document import on a fresh install fails; subsequent imports succeed.

### Pitfall 7: Trip Cascade Deletes Document Rows But Leaves Files

**What goes wrong:** User deletes a trip with 5 documents. SwiftData cascade removes the 5 `Document` rows. The 5 files remain orphaned on disk. Next user re-imports similar docs — no immediate bug, but storage grows unbounded.

**Why it happens:** SwiftData has no knowledge of the filesystem. Cascade `deleteRule` only affects relational rows.

**How to avoid:** Pattern 10 — `removeTripFolder` called after the Trip delete's `modelContext.save()` succeeds.

**Warning signs:** Test `deleteTripRemovesDocumentFolder` fails. In production: Settings → iPhone Storage → Travellify shows growing size despite user-visible document count dropping.

### Pitfall 8: Alert TextField Save Button Enabled on Empty Input (iOS 16)

**What goes wrong:** User taps Save with empty name; the app either crashes or saves an empty `displayName`.

**Why it happens:** `.disabled()` on alert buttons is iOS 17+.

**How to avoid:** iOS 17 deployment target — works correctly. For safety, the Save action handler ALSO trims and checks for non-empty before mutating the model (defensive double-check).

### Pitfall 9: Import Task Continues After User Backs Out of DocumentListView

**What goes wrong:** User taps Files → picks a 50 MB PDF → immediately taps back to Trip list before the copy completes. Task still runs; `Document` row appears on a list the user is no longer viewing.

**Why it happens:** `Task.detached` lifetime is decoupled from view lifecycle.

**How to avoid:** Acceptable for v1 — the document IS successfully imported and will appear next time the user opens that trip's Documents list. The `@Query` re-fires when the list appears. Document this as intended behavior; don't try to cancel in-flight imports on view dismiss (complexity without user value).

**Warning signs:** Not a bug — a user support question. Document it.

### Pitfall 10: `@Query` Filter Predicate with `trip == self.trip` Compilation Error

**What goes wrong:** `@Query(filter: #Predicate<Document> { $0.trip == self.trip })` fails to compile — `self` is not available in property wrapper init.

**Why it happens:** `@Query` is initialized before `self` is fully constructed. The predicate cannot reference instance properties.

**How to avoid:** Use a custom init on `DocumentListView` that accepts the `Trip` and builds the `@Query` with a captured `Trip.ID`:

```swift
struct DocumentListView: View {
    let trip: Trip
    @Query private var documents: [Document]

    init(trip: Trip) {
        self.trip = trip
        let tripID = trip.persistentModelID
        _documents = Query(
            filter: #Predicate<Document> { doc in
                doc.trip?.persistentModelID == tripID
            },
            sort: \Document.importedAt,
            order: .reverse
        )
    }
    // ...
}
```

[VERIFIED: standard SwiftData `@Query` dynamic filter pattern; Apple WWDC24 examples]

**Warning signs:** `error: instance member 'trip' cannot be used on type 'DocumentListView'`.

---

## Code Examples

All primary code examples are inlined above in Patterns 1–10. Additional snippets:

### Localized date string helper

```swift
func localizedDateString(_ date: Date = Date()) -> String {
    date.formatted(.dateTime.year().month().day())
    // → "Apr 19, 2026" in en-US locale
}
```

### Pluralization for TripDetail card body

```swift
// Per UI-SPEC TripDetail Documents Card state table
func documentCountCopy(_ count: Int) -> String {
    count == 1 ? "1 document" : "\(count) documents"
}
```

### Info.plist entries (CRITICAL — must be present at build time)

```xml
<key>NSCameraUsageDescription</key>
<string>Allow Travellify to use the camera to scan documents for your trips.</string>
```

`NSPhotoLibraryUsageDescription` NOT needed (PhotosPicker is out-of-process).
`NSPhotoLibraryAddUsageDescription` NOT needed (we don't write back to Photos).
No Files-app-specific plist key — `UIDocumentPickerViewController` uses the system sandbox entitlements.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `PHPickerViewController` UIKit bridge | Native SwiftUI `PhotosPicker` | iOS 16 | Simpler SwiftUI-native API; permission-free by design |
| `UIImagePickerController` (source type: photoLibrary) | `PhotosPicker` | iOS 16 | Old API deprecated for photo library use; camera use still valid for live capture but we use VisionKit instead |
| Core Data with `externalStorage` for binary assets | SwiftData with `@Attribute(.externalStorage)` OR explicit filesystem paths (our choice) | iOS 17 (SwiftData release) | We chose explicit paths (D10); gives us CloudKit v2 migration control |
| Custom camera scanner via `AVCaptureSession` + Vision rectangle detection | `VNDocumentCameraViewController` | iOS 13 | Apple's document-specific UI with auto-capture is qualitatively better than anything we'd build |
| `NSFileCoordinator` for every file op | Direct `FileManager` for app-sandbox file ops | iOS 8+ | Coordinator only needed for cross-app shared documents or iCloud Drive — not our use case |
| `XCTestCase` + `expectation(description:)` | Swift Testing `@Test` + `#expect` + async-native | Xcode 16 | We already adopted Swift Testing in Phase 1 |

**Deprecated/outdated:**
- `UIImagePickerController.sourceType = .photoLibrary` — superseded by `PhotosPicker`. Do not use.
- `PHPickerViewController` UIKit bridge — superseded by native `PhotosPicker`. Do not use.
- `UIDocumentInteractionController` — not needed; it's for preview/share, not import.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode.app + iOS 17+ simulator | Build + simulator test | ✓ | Xcode 26.2 Build 17C52 | — |
| iPhone 16e simulator | Canonical test target | ✓ (Phase 1 verified) | iOS 17+ | Any iOS 17+ simulator on this machine |
| VisionKit framework | DOC-01 scan | ✓ | iOS 13+ (ships with iOS SDK) | — |
| PhotosUI framework | DOC-02 photos import | ✓ | iOS 16+ native SwiftUI | — |
| UIKit framework | DOC-03 files import bridge | ✓ | iOS all | — |
| PDFKit framework | DOC-01 + DOC-04 | ✓ | iOS 11+ | — |
| UniformTypeIdentifiers | DOC-03 type whitelist | ✓ | iOS 14+ | — |
| Physical device with camera | Live scan test (simulator has no camera) | ⚠ Unknown | — | Test scan flow on simulator with mock UIImages; physical device required for actual VisionKit camera flow |
| Info.plist `NSCameraUsageDescription` | Camera permission prompt | ❌ Must be added | — | Required — blocks DOC-01 if missing |

**Missing dependencies with no fallback:** None for build/compile. Runtime camera test requires a physical iPhone with a camera (simulator's camera is a synthetic image feed that does NOT trigger VisionKit's full UI). Document this in the plan: DOC-01 end-to-end verification needs physical device.

**Missing dependencies with fallback:** `NSCameraUsageDescription` is easy to add as a plan task; no blocker.

---

## Validation Architecture

> `nyquist_validation` inherited from Phase 1 config — enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (ships with Xcode 16+) |
| Config file | None required |
| Quick run command | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination "platform=iOS Simulator,name=iPhone 16e"` |
| Full suite command | Same (one test target; filter via `-only-testing:` for quick sub-suite runs) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOC-01 | Scan produces combined PDF, inserts Document with kind=.pdf, file exists on disk | unit (with synthetic `[UIImage]` input) | `-only-testing:TravellifyTests/ImportTests/scanAssembliesPDFAndInsertsDocument` | ❌ Wave 0 |
| DOC-01 | VisionKit bridge end-to-end (camera UI) | manual | Run app on physical device, tap Scan, capture 2 pages, verify row appears | manual-only (simulator can't test camera) |
| DOC-02 | PhotosPicker Data → disk preserves original format bytes | unit (with synthetic `Data` from test asset) | `-only-testing:TravellifyTests/ImportTests/photosImportPreservesJpegBytes` | ❌ Wave 0 |
| DOC-03 | Files importer copies source URL into <tripUUID>/<docUUID>.<ext> | unit (with temp dir source URL) | `-only-testing:TravellifyTests/ImportTests/filesImportCopiesToDestination` | ❌ Wave 0 |
| DOC-04 | PDFView loads PDF URL; image viewer loads UIImage | smoke | `-only-testing:TravellifyTests/ViewerTests/pdfViewerLoadsDocumentUrl` | ❌ Wave 0 |
| DOC-04 | Viewer pinch-zoom actually zooms | manual | Simulator scroll + two-finger pinch | manual-only |
| DOC-05 | Rename mutates displayName and persists | unit | `-only-testing:TravellifyTests/DocumentTests/renamePersistsDisplayName` | ❌ Wave 0 |
| DOC-05 | Empty-trimmed name is rejected (Save disabled) | manual | Bring up rename alert, clear text, verify Save is grey | manual-only (UI-level) |
| DOC-06 | Delete removes row, file, leaves sibling docs + files | unit | `-only-testing:TravellifyTests/DocumentTests/deleteRemovesFileAndModel` | ❌ Wave 0 |
| DOC-07 | fileRelativePath is a String (not Data); file is on disk at expected path | unit | `-only-testing:TravellifyTests/DocumentTests/documentStoresPathNotData` | ❌ Wave 0 |
| DOC-07 (cascade) | Deleting Trip removes <tripUUID>/ folder from disk | unit | `-only-testing:TravellifyTests/DocumentTests/tripCascadeDeleteRemovesTripFolder` | ❌ Wave 0 |
| FileStorage round-trip | Write then resolve then read returns the same bytes | unit | `-only-testing:TravellifyTests/FileStorageTests/writeThenResolveRoundTrip` | ❌ Wave 0 |
| FileStorage | Missing file on `resolveURL` returns nil (not crash) | unit | `-only-testing:TravellifyTests/FileStorageTests/missingFileReturnsNil` | ❌ Wave 0 |
| FileStorage | Remove missing file does not throw | unit | `-only-testing:TravellifyTests/FileStorageTests/removeMissingIsNoOp` | ❌ Wave 0 |
| FileStorage | `removeTripFolder` removes entire subtree | unit | `-only-testing:TravellifyTests/FileStorageTests/removeTripFolderRemovesAllChildren` | ❌ Wave 0 |
| Concurrency | Import task writes file off main, inserts on main — no thread assertion crashes | unit | `-only-testing:TravellifyTests/ImportTests/importRunsOffMainThenHopsToMain` | ❌ Wave 0 |
| FOUND-03 (re-verified) | New Document fields do not introduce `.unique` or `.deny` | static | `grep -rE "@Attribute\(.unique|deleteRule: \.deny" Travellify/Models/` (must return 0 results) | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Quick `DEVELOPER_DIR=... xcodebuild -scheme Travellify build` (compile-only — no simulator required) — catches Swift 6 concurrency errors fast.
- **Per wave merge:** Full `xcodebuild test` suite on iPhone 16e simulator.
- **Phase gate:** Full suite green + manual smoke test on simulator of (a) Photos import → list → viewer, (b) Files import → list → viewer, plus `-- if available --` physical-device test of Scan flow before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `TravellifyTests/FileStorageTests.swift` — FileStorage round-trip, missing file, remove, cascade folder
- [ ] `TravellifyTests/DocumentTests.swift` — model field presence, rename, delete, cascade-delete-removes-files, DOC-07 path-not-data, renamed display name persists
- [ ] `TravellifyTests/ImportTests.swift` — scan assembly (with synthetic UIImages generated from a `CGContext`), photos data write, files copy, concurrency off-main then on-main (use `Thread.isMainThread` + `#expect`)
- [ ] `TravellifyTests/ViewerTests.swift` — PDFView loads URL smoke (instantiate `PDFKitView`, assert `document != nil` after `makeUIView`)
- [ ] Test fixture assets: tiny-jpeg.jpg, tiny-heic.heic, tiny-pdf.pdf bundled in the test target `Resources/`
- [ ] Add `NSCameraUsageDescription` to `Info.plist` as a Wave 0 task (blocks DOC-01 physical-device test)

---

## Security Domain

> `security_enforcement` inherited from Phase 1 config — treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth in v1; Face ID lock on Documents is DOC-08 → Phase 6 |
| V3 Session Management | No | Local-only; no sessions |
| V4 Access Control | No | Single-user local app |
| V5 Input Validation | Yes | Rename input trimmed + non-empty; import file types whitelisted (`.pdf`, `.image`); file size not enforced in v1 (no attack surface since files stay in-app) |
| V6 Cryptography | No (Phase 2) | File protection class deferred to Phase 6 polish (DOC-08 adjacent work) |
| V7 Error Handling & Logging | Yes | Use `Logger` with `%{private}` for any path/ID logging; never `print()` user-content paths; errors surface via UI-SPEC error alert copy |
| V10 Malicious Code | Indirectly | PDF files from Files app can embed JavaScript (PDFKit does NOT execute it on iOS by default — rendering-only) |
| V12 File & Resources | Yes | Imported files stored in app sandbox; `Application Support/Documents/` not user-browsable via Files app; `asCopy: true` ensures no external URL retention |

### Known Threat Patterns for {iOS document import + local storage}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious PDF with embedded JavaScript or exploit | Tampering / Elevation | PDFKit on iOS does not execute embedded JavaScript. Render-only. [VERIFIED: Apple PDFKit does not expose `Acrobat JavaScript` execution]. No mitigation needed in v1 |
| Path traversal via `fileRelativePath` containing `../` | Tampering | Always construct paths as `<tripUUIDString>/<docUUIDString>.<ext>` where BOTH components are UUIDs (known-safe alphanumeric + hyphen). Never incorporate user-supplied strings into the path. **Rename changes `displayName`, NOT `fileRelativePath`.** This is critical — the plan's rename task MUST NOT touch `fileRelativePath` |
| Information disclosure via file logging | Information Disclosure | Use `Logger` with `privacy: .private` for paths and document IDs: `logger.error("Cleanup failed for \(id, privacy: .private)")` |
| Untrusted file from Files app contains malware | Tampering | Files stay within app sandbox; iOS sandbox prevents execution. No user-exposed "Open with..." flow in v1 |
| Large file DoS (user imports 5GB file) | DoS | No explicit cap in v1 (UI-SPEC says so). Pragmatic: `FileManager.copyItem` will fail with disk-full error, caught and surfaced as "Couldn't add document." Acceptable for v1 |
| Backup exfiltration via iCloud Backup | Information Disclosure | User's documents are in their own iCloud backup — same trust boundary as Photos. Not Phase 2's problem to solve; DOC-08 (Face ID) is the defensive layer for sensitive docs |
| Security-scoped URL retention leak | Tampering | `asCopy: true` + defensive `start/stopAccessingSecurityScopedResource` pattern prevents retention (see Pattern 4) |

**Phase 2 security posture:** The biggest concrete risk is path traversal in `fileRelativePath`. Mitigation: UUIDs only in path components. Add a static check in `FileStorage.write`: refuse any `relativePath` containing `..` or starting with `/`:

```swift
static func write(data: Data, toRelativePath relativePath: String) throws {
    guard !relativePath.contains("..") && !relativePath.hasPrefix("/") else {
        throw FileStorageError.invalidPath(relativePath)
    }
    // ... rest of write
}
```

This is a one-line defense-in-depth. Rename NEVER touches path — enforced by code review.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `SwiftData` lightweight-migrates additive properties to existing `@Model` when all new properties have defaults, without requiring a `MigrationStage` | Pattern 1 / Open Question 4 | If wrong, first launch after Phase 2 deploy would fail to open the existing SchemaV1 store. Mitigation: pre-production app with no shipped users — can wipe and re-create. Low risk in practice but confirm by running Phase 1 app, then rebuilding with Phase 2 model and launching in the same simulator |
| A2 | `UIImage` is `@unchecked Sendable` on iOS 17 via Apple's UIKit overlay — passing `[UIImage]` into `Task.detached` under Swift 6 compiles | Pattern 5 concurrency notes | If wrong, the scan-import path requires converting UIImages to `Data` on the main actor before the hop, making the Task larger. Adjust pattern accordingly |
| A3 | `UIDocumentPickerViewController` with `asCopy: true` gives us a URL that can be copied via standard `FileManager.copyItem` without `start/stopAccessingSecurityScopedResource` — but defensive pattern is harmless | Pattern 4 / Open Question 6 | If defensive pattern is insufficient for `asCopy: true` on iOS 18, fall back to `asCopy: false` + full security-scoped lifecycle. Plan should include a fallback check |
| A4 | PhotosPicker `loadTransferable(type: Data.self)` returns the original container bytes byte-for-byte (no re-encode) | Pattern 3 / Open Question 3 | If iOS re-encodes, a HEIC source becomes a re-encoded HEIC with potential quality drift. Pragmatic impact: imperceptible for travel document use case. Low risk |
| A5 | iOS 17 PDFKit `PDFPage(image:)` creates correctly-rendering pages (iOS 16 regression is fixed) | Pattern 5 / Pitfall 5 | If regression persists on a specific iOS 17.x point release, scanned PDFs render blank. Mitigation: test on iPhone 16e simulator iOS 17 + current iOS 18.x simulator before Phase 2 ships |
| A6 | `Application Support/Documents/` is created by `FileManager.createDirectory(..., withIntermediateDirectories: true)` on first use without additional entitlement | Pattern 1 / Pitfall 6 | Highly unlikely to be wrong — standard iOS sandbox behavior. Cost of verifying: one manual test |
| A7 | SwiftData cascade delete on `Trip → Document` fires synchronously inside `modelContext.save()` such that calling `FileStorage.removeTripFolder` immediately after save is safe (i.e., no pending cascade work) | Pattern 10 | If cascade is async or deferred, file folder might be removed while SwiftData still holds a reference to the docs. Phase 1 RESEARCH.md Assumption A2 already flagged iOS 17.x cascade bugs exist — reverify in Phase 2 integration tests |

Any claim above surfaced with `[ASSUMED]` in-text also lives here for planner / discuss-phase awareness.

---

## Open Questions

All six Open Questions from CONTEXT.md are answered inline above. Residual uncertainty:

1. **A1 (SwiftData lightweight migration) — confirm at implementation** by running Phase 1 app first (creates SchemaV1 store with placeholder Document), then rebuilding with Phase 2 model extensions and re-launching. If store fails to open, bump to SchemaV2 with a `MigrationStage.lightweight(...)`. First-task plan item should include this verification checkpoint.

2. **A3 (asCopy + security-scoped on iOS 18) — defensive pattern applied**, but monitor Apple Developer Forums and Xcode 26.2 release notes for clarification. If a future iOS update makes `asCopy: true` strict about security-scoped access, our defensive pattern already covers it.

3. **A7 (cascade timing) — covered by test** `tripCascadeDeleteRemovesTripFolder`. If the test is flaky, switch to a two-step pattern: collect doc paths first, delete Trip, save, *then* remove files (Pattern 10 already does this).

---

## Sources

### Primary (HIGH confidence — Apple + Apple-verified)

- [Apple — VNDocumentCameraViewController](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller) — Scanner VC API surface and delegate contract
- [Apple — Bringing Photos picker to your SwiftUI app](https://developer.apple.com/documentation/PhotoKit/bringing-photos-picker-to-your-swiftui-app) — PhotosPicker native SwiftUI usage
- [Apple — UIDocumentPickerViewController](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller) — Files app import
- [Apple — PDFKit](https://developer.apple.com/documentation/pdfkit) — PDFDocument / PDFPage / PDFView APIs
- [Apple — UniformTypeIdentifiers](https://developer.apple.com/documentation/uniformtypeidentifiers) — UTType.pdf, UTType.image
- [Apple — startAccessingSecurityScopedResource()](https://developer.apple.com/documentation/foundation/nsurl/startaccessingsecurityscopedresource()) — Security-scoped resource API
- [Apple WWDC24 — What's new in SwiftData](https://developer.apple.com/videos/play/wwdc2024/10137/) — Lightweight migration, #Expression, additive schema changes
- [Apple WWDC22 — What's new in PDFKit](https://developer.apple.com/videos/play/wwdc2022/10089/) — PDFKit modern usage
- [Apple Developer Forums 713814](https://developer.apple.com/forums/thread/713814) — asCopy and security-scoped resource behavior (community observations)
- [Apple Developer Forums 717692](https://developer.apple.com/forums/thread/717692) — PDFPage(image:) iOS 16 regression + iOS 17 status
- [Apple Developer Forums 749531](https://developer.apple.com/forums/thread/749531) — PhotosPicker edge cases (iCloud photos, nil data)
- [Apple Developer Forums 709764](https://developer.apple.com/forums/thread/709764) — PhotosPicker transferable type guidance
- [.planning/phases/01-foundation-trips/01-RESEARCH.md](../01-foundation-trips/01-RESEARCH.md) — Prior VersionedSchema + Swift Testing patterns, Xcode 26.2 notes

### Secondary (MEDIUM confidence — community sources verified against Apple docs)

- [scanbot.io — VNDocumentCameraViewController iOS Document Scanner tutorial (2024)](https://scanbot.io/techblog/vndocumentcameraviewcontroller-ios-document-scanner-tutorial/) — Complete SwiftUI bridge with coordinator pattern
- [fatbobman.com — Implementing iOS Notes Document Scanning](https://fatbobman.com/en/posts/docscaner/) — VisionKit deep-dive
- [Swift Senpai — How to Use the SwiftUI PhotosPicker](https://swiftsenpai.com/development/swiftui-photos-picker/) — loadTransferable patterns
- [Swift with Majid — PhotosPicker in SwiftUI](https://swiftwithmajid.com/2023/04/25/photospicker-in-swiftui/) — PhotosPicker idioms
- [Hacking with Swift — Importing an image into SwiftUI using PhotosPicker](https://www.hackingwithswift.com/books/ios-swiftui/importing-an-image-into-swiftui-using-photospicker) — Data-self transferable usage
- [Use Your Loaf — Accessing Security Scoped Files](https://useyourloaf.com/blog/accessing-security-scoped-files/) — start/stopAccessingSecurityScopedResource
- [nemecek.be — How to let user select file from Files](https://nemecek.be/blog/155/how-to-let-user-select-file-from-files) — UIDocumentPickerViewController usage
- [dev.to/artem_poluektov — iOS PDFKit: creating PDF document in Swift](https://dev.to/artem_poluektov/ios-pdfkit-creating-pdf-document-in-swift-insertingdeleting-pages-4cdj) — PDFDocument.insert(PDFPage(image:)) pattern
- [Medium — Document Scanner in SwiftUI App (Yuliia Vanchytska)](https://medium.com/@yuliiavanchytska/document-scanner-in-swiftui-app-6e7731bf5604) — End-to-end SwiftUI + VisionKit example

### Tertiary (LOW confidence — single source, confirmation pending at implementation)

- Community folklore on `@ModelActor`-to-main-context merge bugs on iOS 18 — not directly documented by Apple; consistent with STATE.md blocker flag; mitigation (avoid `@ModelActor` in v1) is already locked by D18

---

## Metadata

**Confidence breakdown:**

- Document model / SchemaV1 extension: HIGH — Apple WWDC24 + AzamSharp 2026 article + Phase 1 RESEARCH.md precedent
- VisionKit bridge / coordinator pattern: HIGH — Apple docs + multiple 2024 community sources + fatbobman.com
- PhotosPicker → disk pipeline: HIGH — Apple Developer Forums 709764 + Swift Senpai (loadTransferable(type: Data.self) is the canonical answer)
- UIDocumentPickerViewController + asCopy: MEDIUM — documentation is ambiguous on security-scoped resource interaction; defensive pattern covers the gap
- PDFKit multi-page assembly: HIGH for API shape (Apple docs); MEDIUM for background-thread safety claim (community experience positive, no official statement)
- Swift 6 concurrency crossing: HIGH — Apple's Sendable guidance + Phase 1 patterns
- Application Support vs Documents: HIGH on directory choice; MEDIUM on iCloud backup semantics
- File lifecycle + trip cascade: HIGH — straightforward FileManager usage
- Viewer (PDFView / ScrollView+Image): HIGH — well-established SwiftUI + PDFKit patterns
- Rename + delete UI: HIGH — iOS 16/17+ native affordances verified

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (VisionKit + PhotosUI + PDFKit APIs are stable and change slowly; re-verify Swift 6 concurrency patterns and `asCopy` behavior on any Xcode / iOS point release between now and Phase 2 implementation start)
