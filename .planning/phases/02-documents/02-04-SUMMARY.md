---
phase: 02-documents
plan: 04
subsystem: documents-viewer
tags: [pdfkit, swiftui, uiviewrepresentable, magnificationgesture, fullscreencover]
dependency_graph:
  requires: [02-01, 02-02]
  provides: [document-viewer, pdf-viewer, image-viewer]
  affects: [DocumentListView]
tech_stack:
  added: [PDFKit.PDFView via UIViewRepresentable]
  patterns: [UIViewRepresentable-no-coordinator, MagnificationGesture-state-clamp, ZStack-chrome-overlay]
key_files:
  created:
    - Travellify/Features/Documents/PDFKitView.swift
    - Travellify/Features/Documents/DocumentViewer.swift
  modified:
    - Travellify/Features/Documents/DocumentListView.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "[02-04]: #Preview macro in Swift 6 does not permit Void-returning statements (property mutations) mixed with ViewBuilder expressions — used private preview struct with lazy stored properties instead of inline mutations"
  - "[02-04]: PDFKitView has no Coordinator — updateUIView guards on documentURL equality to avoid redundant PDFDocument re-init"
  - "[02-04]: errorBody gets .frame(maxWidth:.infinity, maxHeight:.infinity) so it fills the ZStack rather than pinning to center-top"
  - "[02-04]: DocumentViewer imports SwiftData only for the #Preview wrapper; main struct body has no SwiftData dependency"
metrics:
  duration: ~15min
  completed: "2026-04-20"
  tasks_completed: 2
  files_created: 2
  files_modified: 2
---

# Phase 2 Plan 04: DocumentViewer Full-Screen Cover Summary

Implemented `DocumentViewer` full-screen cover with branched body (PDFKit `PDFView` via `UIViewRepresentable` for PDFs; `ScrollView + Image + MagnificationGesture` for images), minimal top chrome (X + centered title over `.ultraThinMaterial`), and error body when file is missing. Replaced the `TODO(02-04)` placeholder in `DocumentListView.fullScreenCover` with `DocumentViewer(document: doc)`.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create PDFKitView + DocumentViewer | 6dea5ab | PDFKitView.swift, DocumentViewer.swift, project.pbxproj |
| 2 | Wire DocumentViewer into DocumentListView.fullScreenCover | ef9bcfb | DocumentListView.swift |

## Xcode Target Membership

Manual pbxproj registration performed. Two files added to the `Documents` PBXGroup (not inside `Import` subgroup — these are top-level viewer files):

- `B20204B2C2D341829A0B6002` — PBXFileReference for `PDFKitView.swift`
- `B30204B2C2D341829A0B6004` — PBXFileReference for `DocumentViewer.swift`
- `A20204B2C2D341829A0B6001` — PBXBuildFile for `PDFKitView.swift in Sources`
- `A30204B2C2D341829A0B6003` — PBXBuildFile for `DocumentViewer.swift in Sources`

Both entries added to `8A4232BBCEEB498ABA81C38E` Sources build phase.

## PDFView Rendering Notes

PDFKit `PDFView` with `autoScales = true` and `displayMode = .singlePageContinuous` renders cleanly in simulator. Native pinch-to-zoom is provided by `PDFView` itself — no gesture code needed. The `updateUIView` guard (`uiView.document?.documentURL != url`) prevents redundant `PDFDocument` re-initialization on view updates.

## Image MagnificationGesture Notes

`MagnificationGesture` with `lastImageScale * value` accumulation and `min(max(..., 1.0), 5.0)` clamping behaves correctly. Double-tap resets `imageScale` and `lastImageScale` both to `1.0` with `.easeInOut(duration: 0.2)` animation. The 1.0–5.0 range matches the plan spec.

## Top Chrome Legibility

`HStack` with `.ultraThinMaterial` background sits at the top of the `ZStack(alignment: .top)`. The leading X button (44x44), centered title with `.truncationMode(.middle)`, and trailing 44x44 spacer give symmetrical layout. The material reads correctly over both light (PDF white pages) and dark (photo) content.

## Deviations from Plan

### Auto-fixed: #Preview Swift 6 ViewBuilder restriction

**Found during:** Task 1 build verification (second attempt)
**Rule:** Rule 1 (bug — compile error)
**Issue:** `#Preview` macro body is `@ViewBuilder` in Swift 6. Property-mutation statements (`doc.displayName = ...`) return `Void` which cannot conform to `View`, causing "type '()' cannot conform to 'View'" compile error. The `DocumentListView` previews work because they only use `let` bindings (which are allowed by `@ViewBuilder`).
**Fix:** Replaced inline mutations in `#Preview` with a `private struct DocumentViewerPreview: View` that uses lazy stored property closures for both `container` and `doc` initialization, then wraps `DocumentViewer(document: doc)`.
**Files modified:** `DocumentViewer.swift`
**Commit:** 6dea5ab (same task commit)

### Auto-fixed: Missing `import SwiftData` in DocumentViewer.swift

**Found during:** Task 1 first build
**Rule:** Rule 3 (blocking — compile error: `ModelContainer` not in scope)
**Issue:** Preview struct references `ModelContainer` and `ModelConfiguration` which require `import SwiftData`.
**Fix:** Added `import SwiftData` alongside existing `import SwiftUI` and `import PDFKit`.
**Commit:** 6dea5ab (same task commit)

## Known Stubs

None. `DocumentViewer` is fully wired. The rename and delete actions in `DocumentListView` remain `TODO(02-05)` stubs as intended — not within scope of this plan.

## Threat Surface Scan

No new network endpoints, auth paths, or trust boundaries introduced. The viewer renders local on-disk files only. T-02-19 mitigation is active: viewer calls `FileStorage.resolveURL` which delegates path validation to `validateRelativePath` (Plan 02-01 path-traversal guards). Viewer never constructs its own file URLs from user input.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| PDFKitView.swift exists | FOUND |
| DocumentViewer.swift exists | FOUND |
| struct PDFKitView: UIViewRepresentable count = 1 | PASS |
| view.autoScales = true count = 1 | PASS |
| displayMode = .singlePageContinuous count = 1 | PASS |
| struct DocumentViewer: View count = 1 | PASS |
| FileStorage.resolveURL(for: document) count = 1 | PASS |
| MagnificationGesture() count = 1 | PASS |
| min(max(lastImageScale * value, 1.0), 5.0) count = 1 | PASS |
| onTapGesture(count: 2) count = 1 | PASS |
| "This document is unavailable." count = 1 | PASS |
| .ultraThinMaterial count = 1 | PASS |
| accessibilityLabel("Close") count = 1 | PASS |
| DocumentViewer(document: doc) in DocumentListView count = 1 | PASS |
| TODO(02-04) in DocumentListView count = 0 | PASS |
| "Viewer coming soon" in DocumentListView count = 0 | PASS |
| xcodebuild build exit code = 0 | PASS |
| xcodebuild test exit code = 0 | PASS |
| Commit 6dea5ab exists | FOUND |
| Commit ef9bcfb exists | FOUND |
