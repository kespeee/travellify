# Phase 2 Context: Documents

**Phase:** 02-documents
**Requirements:** DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06, DOC-07
**Discussed:** 2026-04-19
**Supersedes:** nothing (extends Phase 1)
**Depends on:** Phase 1 (Trip, Destination, placeholder Document model already exist)

## Upstream Artifacts Loaded

- `.planning/PROJECT.md` — SwiftUI + SwiftData, iPhone-only, local-only v1, clean & native
- `.planning/REQUIREMENTS.md` — DOC-01..DOC-07 in Phase 2; DOC-08 (Face ID lock) deferred to Phase 6
- `.planning/ROADMAP.md` — Phase 2 success criteria locked
- `.planning/phases/01-foundation-trips/01-CONTEXT.md` — D1–D9 carry forward; placeholder `Document` model exists with `id: UUID` + `trip: Trip?`
- `CLAUDE.md` — VisionKit, PhotosUI, UIDocumentPickerViewController, `@Attribute(.externalStorage)` notes
- `.planning/STATE.md` blocker — VisionKit coordinator lifecycle + iOS 18 `@ModelActor`-to-main-context merge are confirmed bug territories (research flagged)

## Decisions

### D10 — Document model: filesystem path, no externalStorage

Fields on the `Document` `@Model` (extending the Phase 1 placeholder):

```
var id: UUID = UUID()
var trip: Trip?                       // CloudKit-safe optional inverse
var displayName: String               // editable name shown in UI
var fileRelativePath: String          // "<tripUUID>/<docUUID>.<ext>" under Documents base dir
var kind: DocumentKind                // enum: pdf | image  (raw String for CloudKit codability)
var importedAt: Date                  // creation timestamp
```

- **No `@Attribute(.externalStorage)`** — DOC-07 requires explicit filesystem storage with paths referenced from the model. We own file lifecycle directly (copy on import, delete on removal); `externalStorage` would hide those semantics and complicate CloudKit v2 migration (binary assets would need separate handling).
- **`fileRelativePath` stored relative to a base directory** (not absolute) — so app container UUID changes across OS reinstalls don't orphan data.
- **Base directory:** `Application Support/Documents/` (iOS Application Support, not user-visible Files). Backed up by iCloud by default; excluded from iCloud only if the user opts out later.
- **Per-trip subfolder:** `<Application Support>/Documents/<tripUUID>/<docUUID>.<ext>` keeps file ops local to a trip and makes trip cascade-delete a single `removeItem(at: tripFolder)`.
- **`DocumentKind` enum** stored as `String` raw value on model (CloudKit prefers primitives; enums with raw String are safe).

### D11 — Import flow: single "+" Menu with three items (Scan / Photos / Files)

- Toolbar "+" on `DocumentListView` → SwiftUI `Menu` drops down with three buttons: Scan Document, Choose from Photos, Import from Files.
- Each menu item maps to its own sheet:
  - Scan → `UIViewControllerRepresentable` wrapping `VNDocumentCameraViewController`.
  - Photos → native SwiftUI `PhotosPicker` (iOS 16+), `matching: .any(of: [.images])`, single selection for v1.
  - Files → `UIViewControllerRepresentable` wrapping `UIDocumentPickerViewController` with `allowedContentTypes: [.pdf, .image]` and `asCopy: true`. Must correctly call `startAccessingSecurityScopedResource()` / stop.
- **Permissions:** lazy — OS prompts on first camera use via VisionKit; PhotosPicker does not require an app-level prompt. No pre-flight explainer sheets in v1.
- **File types whitelisted:** PDF + common images (UTType.pdf, UTType.image — covers JPEG, PNG, HEIC). No Word/text in v1.

### D12 — Multi-page scan → one Document, one combined PDF

- VisionKit returns `VNDocumentCameraScan` with `pageCount` pages as `UIImage`s.
- On scan finish: render pages into a single `PDFDocument` (PDFKit), write to `<tripUUID>/<docUUID>.pdf`, create one `Document` row with `kind = .pdf`.
- **Rationale:** users mentally model "a scanned passport" as one document, not N page-images. Keeps the list clean and the viewer logic uniform (multi-page PDF = first-class case for PDFView).
- Single-page scans still saved as PDF (not image) — unified render path.

### D13 — Auto-name on import, rename later via context menu

- **Scan:** `displayName = "Scan YYYY-MM-DD"` (locale-aware date formatter).
- **Photos:** `displayName = "Photo YYYY-MM-DD"` (PHPickerResult rarely exposes a usable filename; date is reliable).
- **Files:** `displayName = <source URL lastPathComponent without extension>` (the Files app gives us a real filename).
- No modal name prompt blocking the import. Rename happens later via long-press context menu (see D15).

### D14 — Viewer: fullScreenCover, PDFKit PDFView (PDFs), ScrollView + magnification (images)

- **Presentation:** `.fullScreenCover` from the document list (not push, not sheet — sheet's swipe-down fights zoom gestures).
- **PDFs:** `PDFKit.PDFView` wrapped in `UIViewRepresentable`. Built-in pinch-zoom, scrolling, page navigation. `autoScales = true`, `displayMode = .singlePageContinuous`.
- **Images:** SwiftUI `ScrollView` with `Image(uiImage:)`. iOS 17+ native magnification via `MagnificationGesture` + `@State scale`. Double-tap to reset.
- **Chrome:** minimal top bar — `X` close button (leading) + document `displayName` (centered). No share button, no overflow menu, no bottom toolbar. Rename/delete remain list-level actions; no need to duplicate inside the viewer.
- Viewer loads file from `FileStorage.resolveURL(for: doc)` — synchronous for image `UIImage(contentsOfFile:)` and `PDFDocument(url:)` (both are fine on main thread for <20MB files).

### D15 — Delete & rename: long-press context menu only

- **No swipe-to-delete on document rows.** User explicitly chose context menu as the single action surface for both delete and rename (diverges from Trip's swipe-to-delete pattern).
- **Long-press on a document row** → SwiftUI `.contextMenu { … }` with two items:
  - Rename → presents a SwiftUI `.alert` with a `TextField` bound to a draft `@State`, Save/Cancel buttons. iOS 16+ supports `TextField` in alerts natively.
  - Delete → presents a `.confirmationDialog` (role: .destructive) with copy: **"Delete '<displayName>'? This removes the file from your device and cannot be undone."** + Delete/Cancel. Matches Trip delete tone.
- **Empty state:** text-only copy pointing to the "+" toolbar button. No inline CTAs.

### D16 — File cleanup: explicit, not hooked

- **On document delete (user-initiated):** the delete action runs:
  1. `FileStorage.remove(relativePath: doc.fileRelativePath)` — throws caught and logged, but does not block model delete.
  2. `context.delete(doc)`; `try context.save()`.
- **On trip cascade delete (Trip delete flow already exists from Phase 1):** before `context.delete(trip)`, collect `trip.documents?.map(\.fileRelativePath) ?? []`, then after `context.save()` succeeds, remove the trip's `<tripUUID>/` subfolder in one `removeItem(at:)` call.
- **No SwiftData `willSave`/`didSave` hook-based file cleanup** — hooks fire at uncertain points and partial-failure modes are hard to reason about.
- **No periodic orphan sweep in v1.** If a future bug leaks files, a sweep can be added in Phase 6 polish.
- **`FileStorage` is a single enum with static methods** (no protocol, no DI) — matches Phase 1's no-ViewModel/no-repository stance (D8).

### D17 — TripDetail Documents card → push to DocumentListView

- The placeholder Documents card on `TripDetailView` (from Phase 1 plan 01-05) gets wired:
  - Card shows count ("3 documents") + latest document's `displayName` if non-empty, else "No documents yet".
  - Tap the card → push `AppDestination.documentList(Trip.persistentModelID)` onto the existing `NavigationStack`.
  - Requires extending `AppDestination` enum (currently only `.tripDetail(PersistentIdentifier)`).
- Viewer opens as `.fullScreenCover` from inside `DocumentListView` (not from `TripDetailView`).

### D18 — Concurrency: file copy on background Task, main-context insert

- Import flow:
  1. User picks a source (camera/photos/files) → we receive a `URL` or `UIImage`/`PDFDocument`.
  2. Spawn a detached `Task` (background) that:
     - Generates a new UUID for the doc.
     - Writes the file to disk at `<tripUUID>/<newDocUUID>.<ext>`.
     - On success, hops back to `@MainActor` and inserts the `Document` model via the main `ModelContext`, sets `trip` relationship, saves.
  3. UI shows an inline progress indicator during import (spinner on the + button or a toast).
- **No `@ModelActor` for import in v1.** The blocker flag in STATE notes the iOS 18 `@ModelActor`-to-main-context merge issue is confirmed bug territory; until Phase 5+ proves a real performance need, we stay on the main context. File I/O on background Task is the slow part — SwiftData write itself is trivial (metadata row).
- **Files imported as-copy** (`asCopy: true` on `UIDocumentPickerViewController`) — no security-scoped URL retention needed after copy.

## Non-Decisions (locked by upstream, restated for planner)

- SwiftData `VersionedSchema` — adding fields to `Document` requires either SchemaV1 additive change (safe, if backward-compatible and no production data yet) OR a new SchemaV2 + MigrationPlan stage. Researcher confirms: since no users have Phase 1 data yet, SchemaV1 can absorb Document field additions without a migration stage.
- CloudKit rules still apply: no `@Attribute(.unique)`, no `.deny`, no `Data` blobs — fileRelativePath is a `String`, kind is a `String` raw enum.
- Swift 6 strict concurrency.
- Dark theme, native SF Symbols (camera, photo, folder for the import menu; doc.text for placeholder).
- iPhone 16e canonical simulator (from Phase 1 D7).
- No ViewModel layer — `@Query`, `@Bindable`, view-local `@Observable` only.
- Swift Testing for unit tests; no UI tests in Phase 2.

## Open Questions for Researcher

1. **VisionKit coordinator lifecycle on iOS 17/18** — what's the current confirmed-working pattern for bridging `VNDocumentCameraViewController` delegate callbacks back into a SwiftUI binding without the coordinator being deallocated mid-scan? (Flagged as bug territory in STATE.)
2. **PDFKit rendering cost on background thread** — is `PDFDocument`'s write-to-URL safe off the main thread on iOS 17.x? Any known bugs with large page counts?
3. **PhotosPicker → fileURL path** — PhotosPicker gives `PhotosPickerItem`, not URL. Best practice for converting `Transferable` Image data to a JPEG/HEIC written to disk without going through UIImage (quality loss)?
4. **SwiftData Document field additions to SchemaV1** — since no production data exists, can we extend the existing `SchemaV1` Document model directly (no `SchemaV2` + migration stage) or does `VersionedSchema` require bumping for any field addition? (Researcher confirms the cleanest path.)
5. **Application Support vs Documents directory trade-off** — iCloud backup behavior for large binary files; does App Store default iCloud backup include Application Support? Any storage-size guidance for v1?
6. **UIDocumentPickerViewController `asCopy: true`** — any remaining gotchas with security-scoped resource on iOS 17/18, or does `asCopy` fully neutralize the `startAccessing…` requirement?

## Out of Scope for Phase 2

- **DOC-08 (Face ID / passcode lock on Documents)** — owned by Phase 6 polish.
- Document thumbnails / grid view — v1 is list-only.
- OCR, text extraction, auto-categorization — explicitly out of v1 per REQUIREMENTS.
- Multi-select bulk delete — single-doc actions only in v1.
- Share sheet / export — deferred (not in REQUIREMENTS).
- Document preview-on-list (inline thumbnail of first page) — list shows icon + name + date only.
- Cross-trip document move — a document belongs to the trip it was imported into.
- Annotation / markup — out of v1.
- Localization.

## Downstream Handoff

**To researcher:** resolve the six Open Questions above; produce `02-RESEARCH.md` covering (a) VisionKit + SwiftUI bridge pattern with coordinator retention, (b) PhotosPicker → disk write pipeline without quality loss, (c) UIDocumentPickerViewController `asCopy` correctness on iOS 17/18, (d) PDFKit multi-page PDF assembly from `[UIImage]`, (e) SwiftData field-addition strategy inside existing `SchemaV1`, (f) Application Support vs Documents directory decision.

**To UI researcher (`/gsd-ui-phase 2`):** build UI-SPEC from D11 (import Menu), D13 (auto-naming), D14 (viewer fullScreenCover + PDFView + ScrollView image), D15 (long-press context menu with alert-for-rename + confirmationDialog-for-delete), D17 (TripDetail Documents card wiring). Empty state: text-only pointing to "+" toolbar.

**To planner:** use D10–D18 as locked constraints. Task breakdown order:
1. Extend `Document` model in `SchemaV1` with fields from D10.
2. `FileStorage` enum (static methods: `baseDirectory`, `write(data:to:)`, `remove(relativePath:)`, `resolveURL(for:)`, `tripFolder(tripID:)`).
3. Extend `AppDestination` enum with `.documentList(PersistentIdentifier)`.
4. `DocumentListView` (list + empty state + "+" Menu with 3 items).
5. Three importer bridges (ScanView, PhotosImporter, FilesImporter) each writing to disk + inserting Document on @MainActor.
6. `DocumentViewer` (fullScreenCover with PDFView/Image branch on `kind`).
7. Context menu: rename (alert + TextField) + delete (confirmationDialog + file cleanup).
8. Wire TripDetail Documents card → push `.documentList`.
9. Trip cascade-delete: remove `<tripUUID>/` folder after model delete.
10. Swift Testing coverage: FileStorage round-trip, Document model CRUD, cascade-delete-removes-files, importer happy path (mocked URL input).
