---
phase: 02-documents
verified: 2026-04-20T00:00:00Z
status: passed
score: 7/7 requirements verified
head: 4a94a5306a2b225d629ca38306f011e40d148359
test_run: "** TEST SUCCEEDED ** (iPhone 16e simulator, xcodebuild test)"
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: N/A
  gaps_closed: []
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "VisionKit scan end-to-end on physical device"
    expected: "Tap Scan → capture 2 pages → combined PDF row appears with displayName 'Scan <date>'; open in viewer shows 2 pages"
    why_human: "Simulator has no camera; VNDocumentCameraViewController cannot render. Required for DOC-01 full validation."
  - test: "Image viewer pinch-zoom"
    expected: "Import a photo → open viewer → two-finger pinch scales image between 1x and 5x; double-tap resets to 1x"
    why_human: "MagnificationGesture behavior is not unit-testable; must be exercised interactively in simulator."
  - test: "Rename alert Save-disabled on empty/whitespace"
    expected: "Open rename → clear text field → Save button greys out and is non-tappable"
    why_human: "SwiftUI .alert TextField binding state not easily introspected from a unit test."
---

# Phase 2: Documents — Verification Report

**Phase Goal:** Deliver end-to-end document management for a trip — scan (VisionKit), import from Photos and Files, full-screen viewing with pinch-zoom (images) and native PDF rendering, rename, delete, and file-system-backed storage with trip-cascade cleanup — all on a CloudKit-safe SwiftData schema.

**Verified:** 2026-04-20
**HEAD:** `4a94a53`
**Status:** PASSED (with 3 manual-only verifications routed to human per `02-VALIDATION.md` §Manual-Only Verifications)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Document @Model stores filesystem path (not blob), CloudKit-safe | PASS | `Travellify/Models/Document.swift:12-29` — `fileRelativePath: String`, `kindRaw: String`, no `@Attribute(.unique)`, no `deleteRule:.deny`, no `Data` field, no `externalStorage` |
| 2 | FileStorage service provides write/copy/remove/resolve with path-traversal defense | PASS | `Travellify/Services/FileStorage.swift:58-70` (write), `74-93` (copy), `98-103` (remove), `106-111` (removeTripFolder), `115-130` (validators reject `..`, absolute, `/`) |
| 3 | User can scan a document → combined PDF inserted | PASS (auto) / PASS-manual | Auto: `TravellifyTests/ImportTests.swift:50-94` assembles 2-page PDF, verifies `%PDF-` magic + pageCount==2 + Document row + file on disk. Manual: physical-device VisionKit flow (human verification #1) |
| 4 | User can import from Photos → image Document with preserved bytes | PASS | `TravellifyTests/ImportTests.swift:98-123` round-trips JPEG bytes through FileStorage; `DocumentImporter.swift:41-70` handles PhotosPickerItem → Data → disk |
| 5 | User can import PDF/image from Files → copied with sandboxed path | PASS | `TravellifyTests/ImportTests.swift:127-157` verifies path matches `<UUID>/<UUID>.pdf` regex and bytes preserved; `FilesImporter.swift` uses `asCopy:true` + `.pdf/.image` UTType filter |
| 6 | User can view PDF full-screen (PDFKit) and image full-screen (pinch-zoom) | PARTIAL-auto / PASS-manual | Auto: `ViewerTests.swift:24-35` confirms `PDFView` loads `PDFDocument(url:)`. Viewer branches on `document.kind` at `DocumentViewer.swift:16-24`. Pinch-zoom gesture is manual (human verification #2) |
| 7 | User can rename a document; `fileRelativePath` is never mutated | PASS | `DocumentListView.swift:156-172` mutates only `displayName`; `DocumentTests.swift:60-84` asserts `fileRelativePath == pathBefore` after rename. Invariant T-02-08 grep = 0 matches |
| 8 | User can delete a document; file and model both removed | PASS | `DocumentListView.swift:189-205` (file-first, then model.delete+save); `DocumentTests.swift:88-125` verifies disk file + model row both gone |
| 9 | Trip cascade-delete removes `<tripUUID>/` folder | PASS | `TripListView.swift:70-82` captures `tripIDString` pre-delete, calls `FileStorage.removeTripFolder` post-save; `DocumentTests.swift:159-204` verifies folder + children gone after cascade |
| 10 | Import I/O runs off-main; SwiftData insert on @MainActor | PASS | `DocumentImporter.swift:22-25,57-59,90-92` use `Task.detached`; inserts are `@MainActor`. `ImportTests.swift:161-179` asserts off-main during write + `MainActor.assertIsolated()` after await |
| 11 | TripDetail Documents card pushes to DocumentListView | PASS | `TripDetailView.swift:67-83` — `NavigationLink(value: AppDestination.documentList(trip.persistentModelID))` with count + latest displayName; `AppDestination.swift:6` has `.documentList` case |
| 12 | NSCameraUsageDescription present in app target | PASS | `Travellify.xcodeproj/project.pbxproj:506,613` — `INFOPLIST_KEY_NSCameraUsageDescription` set in both Debug and Release configs |

**Score:** 12/12 observable truths verified (3 items depend on human verification for full coverage per 02-VALIDATION.md manual-only list).

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Travellify/Models/Document.swift` | D10 fields (id, trip?, displayName, fileRelativePath, kindRaw, importedAt), no Data blob, no unique, no externalStorage | PASS | All fields present with defaults for lightweight SchemaV1 migration (lines 12-20). Computed `kind` passthrough (23-26) |
| `Travellify/Services/FileStorage.swift` | baseDirectory, tripFolder, resolveURL, write, copy, remove, removeTripFolder, path-traversal defense | PASS | All 7 static APIs present. Private `validateRelativePath` rejects empty/`..`/absolute (115-121); `validateComponent` rejects `/`/`..`/leading `.` (123-130) |
| `Travellify/App/AppDestination.swift` | `.documentList(PersistentIdentifier)` case added | PASS | Line 6 |
| `Travellify/Features/Documents/DocumentListView.swift` | @Query tripID filter, empty state, "+" Menu (Scan/Photos/Files), contextMenu rename+delete, fullScreenCover viewer, no swipeActions | PASS | @Query with predicate (32-37), EmptyDocumentsView branch (58-59), Menu with 3 items (84-106), contextMenu only (65-74). `grep swipeActions` = 0. `grep 'doc.fileRelativePath ='` = 0 (T-02-08) |
| `Travellify/Features/Documents/DocumentRow.swift` | Icon by kind + displayName + importedAt + chevron | PASS | Icon branches doc.richtext vs photo (7-9); accessibility label combined (45) |
| `Travellify/Features/Documents/EmptyDocumentsView.swift` | Text-only copy pointing to "+" | PASS | "No Documents Yet" + "Tap + to scan, pick a photo, or import a file." |
| `Travellify/Features/Documents/DocumentViewer.swift` | fullScreenCover body, PDF/image branch on kind, top chrome (X + title), error fallback | PASS | Branch at lines 18-24; MagnificationGesture clamped 1.0–5.0 (45); double-tap reset (51-56); errorBody when resolveURL returns nil (64-73) |
| `Travellify/Features/Documents/PDFKitView.swift` | UIViewRepresentable wrapping PDFView w/ autoScales + singlePageContinuous | PASS | Lines 8-13; updateUIView guards on URL inequality (17-19) |
| `Travellify/Features/Documents/Import/ScanView.swift` | UIViewControllerRepresentable for VNDocumentCameraViewController with coordinator | PASS | Coordinator retained via makeCoordinator (18-20); onFinish/onCancel/onError callbacks wired (29-49) |
| `Travellify/Features/Documents/Import/ScanPDFAssembler.swift` | [UIImage] → PDFDocument → Data, callable off-main | PASS | Pure static function, no main-actor dep; throws on page creation or serialization failure |
| `Travellify/Features/Documents/Import/FilesImporter.swift` | UIDocumentPickerViewController with `[.pdf, .image]` + `asCopy:true` | PASS | Lines 10-13; single-select (14); delegate coordinator for onPicked/onCancel |
| `Travellify/Features/Documents/Import/DocumentImporter.swift` | @MainActor import funcs; Task.detached for I/O; D13 auto-naming | PASS | Scan (11-36), Photos (40-70), Files (74-103). Auto-names: "Scan <date>", "Photo <date>", source-filename-without-ext |
| `Travellify/Features/Trips/TripDetailView.swift` | Documents card wired to `.documentList` push w/ count + latest | PASS | `documentsCard` computes count + latest (67-84); NavigationLink to AppDestination.documentList |
| `Travellify/Features/Trips/TripListView.swift` | On trip delete success → remove `<tripUUID>/` folder | PASS | Lines 70-82; UUID string captured pre-delete; removeTripFolder via `try?` after save success |
| `TravellifyTests/FileStorageTests.swift` | Round-trip, missing file, remove no-op, removeTripFolder, path traversal, no-unique-no-deny | PASS | 6 `@Test` cases, all pass |
| `TravellifyTests/DocumentTests.swift` | Default fields, kind round-trip, rename preserves path, delete removes file+model, path-not-data, trip cascade | PASS | 6 `@Test` cases, all pass |
| `TravellifyTests/ImportTests.swift` | Scan assembly, photos bytes, files copy, off-main-then-main | PASS | 4 `@Test` cases, all pass |
| `TravellifyTests/ViewerTests.swift` | PDFView URL load smoke | PASS | 1 `@Test` case, passes |
| `TravellifyTests/Resources/*` | tiny-jpeg.jpg, tiny-heic.heic, tiny-pdf.pdf | PASS | All 3 fixtures present |

---

## Key Link Verification (Wiring)

| From | To | Via | Status |
|------|-----|-----|--------|
| TripDetailView documents card | DocumentListView | `NavigationLink(value: .documentList(tripID))` + AppDestination enum | WIRED (`TripDetailView.swift:74`) |
| DocumentListView "+" Menu → Scan | ScanView sheet → DocumentImporter.importScanResult | `.sheet(isPresented: $showScanSheet)` + `runImport { try await DocumentImporter.importScanResult(...) }` | WIRED (`DocumentListView.swift:109-123`) |
| DocumentListView "+" Menu → Photos | PhotosPicker → onChange → DocumentImporter.importPhotosItem | `.onChange(of: photosItem)` | WIRED (`DocumentListView.swift:137-141`) |
| DocumentListView "+" Menu → Files | FilesImporter sheet → DocumentImporter.importFileURL | `.sheet(isPresented: $showFilesSheet)` | WIRED (`DocumentListView.swift:125-135`) |
| DocumentImporter (all three) | FileStorage.write / FileStorage.copy | `Task.detached { try FileStorage… }.value` | WIRED |
| DocumentImporter | ModelContext.insert + save | `@MainActor` insert after await | WIRED |
| DocumentRow tap | DocumentViewer | `.fullScreenCover(item: $openedDocument)` | WIRED (`DocumentListView.swift:143-145`) |
| DocumentViewer | FileStorage.resolveURL | `FileStorage.resolveURL(for: document)` → branch kind | WIRED (`DocumentViewer.swift:17-24`) |
| contextMenu Rename | `.alert` with TextField | Binding via `docPendingRename` + `renameDraft` | WIRED (`DocumentListView.swift:147-178`) |
| contextMenu Delete | `.confirmationDialog` → FileStorage.remove + modelContext.delete | file-first then model (D16) | WIRED (`DocumentListView.swift:180-209`) |
| TripListView trip delete | FileStorage.removeTripFolder | Post-save `try?` cleanup | WIRED (`TripListView.swift:77`) |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Flows | Status |
|----------|---------------|--------|-------|--------|
| DocumentListView | `documents` | `@Query` filter on `trip?.persistentModelID == tripID` sort importedAt desc | Real SwiftData query on main context | FLOWING |
| DocumentRow | `document.displayName / kind / importedAt` | Bound to SwiftData @Model | Real data | FLOWING |
| TripDetailView documentsCard | `trip.documents ?? []` | SwiftData inverse relationship | Real data (count + max importedAt) | FLOWING |
| DocumentViewer | `FileStorage.resolveURL(for:)` → `UIImage(contentsOfFile:)` / `PDFDocument(url:)` | On-disk file written by importer | Real bytes from disk | FLOWING |

No hollow props. No hardcoded-empty arrays in render path. No static stub returns in service APIs.

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite on iPhone 16e | `xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination "platform=iOS Simulator,name=iPhone 16e"` | `** TEST SUCCEEDED **` — all 33+ tests pass including 17 Phase-2-owned tests | PASS |
| T-02-08 invariant (rename never mutates path) | `grep -c "doc.fileRelativePath =" DocumentListView.swift` | `0` | PASS |
| No swipeActions on DocumentListView | `grep swipeActions DocumentListView.swift` | `0` | PASS |
| No CloudKit-unsafe attributes in Models | `grep -rE "@Attribute\(\\.unique\)|deleteRule: \\.deny" Travellify/Models/` | `0` | PASS |
| No `Data`-typed field on Document | `grep '\\bData\\b' Travellify/Models/Document.swift` | `0` | PASS |
| No TODO(02-XX) markers in source | `grep 'TODO(02-' Travellify/` | `0` (only in planning docs, which is expected) | PASS |
| NSCameraUsageDescription present | `grep INFOPLIST_KEY_NSCameraUsageDescription pbxproj` | 2 matches (Debug + Release) | PASS |
| No externalStorage on Document | `grep externalStorage Document.swift` | `0` | PASS |

---

## Requirements Coverage

| Req | Description | Status | Evidence |
|-----|-------------|--------|----------|
| DOC-01 | Scan via VisionKit, multi-page + perspective correction → Document | PASS (auto path) / needs-human (device scan) | `ScanView.swift` bridges `VNDocumentCameraViewController`; `ScanPDFAssembler.assemble` combines pages; `ImportTests/scanAssembliesPDFAndInsertsDocument` green. VisionKit physical-device flow routed to human verification. |
| DOC-02 | Import from Photos (PhotosPicker) | PASS | `DocumentImporter.importPhotosItem` + Menu PhotosPicker item; `photosImportPreservesJpegBytes` green |
| DOC-03 | Import PDF/image from Files | PASS | `FilesImporter` uses `UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)`; `filesImportCopiesToDestination` green |
| DOC-04 | View full-screen w/ pinch-zoom (PDFs + images) | PASS (PDF auto + image manual) | `DocumentViewer` branches kind; `PDFKitView` auto-scales; image `MagnificationGesture` clamp 1.0–5.0. Pinch gesture is manual. |
| DOC-05 | Rename after import | PASS | Context-menu Rename → `.alert` with TextField; Save trims + disables on empty; `renamePersistsDisplayName` green |
| DOC-06 | Delete from trip | PASS | Context-menu Delete → `.confirmationDialog`; file-first delete; `deleteRemovesFileAndModel` green |
| DOC-07 | Filesystem-backed binaries with path on model (not Data blob) | PASS | `fileRelativePath: String`; FileStorage.write/copy puts files under `<AppSupport>/Documents/<tripUUID>/<docUUID>.<ext>`; `documentStoresPathNotData` + `tripCascadeDeleteRemovesTripFolder` green |

Orphaned requirements (in REQUIREMENTS.md Phase 2 without a plan claiming them): **none**. All 7 DOC-* IDs mapped and satisfied.

DOC-08 is correctly deferred to Phase 6 per ROADMAP.md and REQUIREMENTS.md traceability.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | No TODO/FIXME/placeholder stubs, no empty render branches, no hardcoded-empty props in render paths, no console-only handlers. All `TODO(02-XX)` markers from earlier plans have been replaced (verified via `grep TODO(02- Travellify/` = 0). |

Notes on patterns that are intentional (not anti-patterns):
- `try?` at `TripListView.swift:77` is deliberate per D16 ("orphan files are tolerable; model integrity takes priority").
- File-deletion errors in `DocumentListView.swift:192-196` are logged not surfaced, per D16.
- `importErrorMessage` alert surfaces a single generic string — by design per Plan 02-05 decision ("Something went wrong" shared surface).

---

## Invariant Check Summary

| Invariant | Check | Result |
|-----------|-------|--------|
| T-02-08 | rename never touches `fileRelativePath` | 0 matches ✓ |
| No `swipeActions` on DocumentListView | grep | 0 matches ✓ |
| No `@Attribute(.unique)` / `deleteRule:.deny` in Travellify/Models | grep | 0 matches ✓ |
| No `Data` blob on Document | grep `\bData\b` in Document.swift | 0 matches ✓ |
| `fileRelativePath` is String (not URL, not Data) | type inspection + `documentStoresPathNotData` test | String ✓ |
| Import off-main, insert on-main | `Task.detached` + `@MainActor` + `importRunsOffMainThenHopsToMain` test | ✓ |
| NSCameraUsageDescription in pbxproj | grep INFOPLIST_KEY_NSCameraUsageDescription | 2 matches (Debug+Release) ✓ |
| No TODO(02-XX) in source | grep in Travellify/ | 0 matches ✓ |

All 8 invariants PASS.

---

## Human Verification Required

The following three items are routed to human testing per `02-VALIDATION.md` §Manual-Only Verifications. They are not gaps in implementation but are outside the automated test envelope:

### 1. VisionKit scan end-to-end on physical device

**Test:** Launch on an iOS 17+ iPhone, open a trip → Documents → "+" → Scan Document. Capture 2 pages, tap Save.
**Expected:** New row appears with displayName "Scan <today's date>", kind = PDF, tapping opens a 2-page PDF in the viewer.
**Why human:** Simulator has no camera — VisionKit cannot render.

### 2. Image viewer pinch-zoom interaction

**Test:** Import a photo from Photos → open the document → perform two-finger pinch, then double-tap.
**Expected:** Image scales between 1.0x and 5.0x on pinch; double-tap resets to 1.0x with animation.
**Why human:** MagnificationGesture behavior is not unit-testable.

### 3. Rename alert Save-disabled on empty/whitespace input

**Test:** Long-press a document → Rename → clear the text field → observe Save button.
**Expected:** Save button greys out and is non-tappable; only tappable once a non-whitespace character is entered.
**Why human:** SwiftUI .alert TextField binding state not easily introspected in a unit test.

---

## Gaps Summary

**No gaps found.** Phase 2 goal is fully achieved at HEAD `4a94a53`:

- All 7 DOC-* requirements have working implementations with green automated tests.
- All 8 T-02-* and CloudKit-safety invariants pass.
- All locked decisions (D10–D18) are reflected in code: filesystem storage with relative paths, per-trip subfolder, single `+` Menu with Scan/Photos/Files, `.fullScreenCover` viewer, context-menu-only Rename+Delete (no swipe), explicit trip-cascade folder removal, off-main I/O + on-main insert, no `@ModelActor`, no `externalStorage`.
- Full test suite `** TEST SUCCEEDED **` on iPhone 16e simulator.
- 3 items remain for human verification (device-only and gesture-based) — these are intrinsic to the phase scope, not implementation gaps.

Phase 2 is ready to close. REQUIREMENTS.md already reflects `Complete` status for DOC-01..DOC-07 (verified at lines 109–115).

---

_Verified: 2026-04-20_
_Verifier: Claude (gsd-verifier)_
_HEAD: 4a94a5306a2b225d629ca38306f011e40d148359_
