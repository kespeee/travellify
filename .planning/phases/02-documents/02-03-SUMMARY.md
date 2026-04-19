---
phase: 02-documents
plan: 03
subsystem: documents-import
tags: [visionkit, photosui, uikit, pdfkit, swift-concurrency, swiftdata]
dependency_graph:
  requires: [02-01, 02-02]
  provides: [import-scan, import-photos, import-files, document-importer-pipeline]
  affects: [DocumentListView, FileStorage]
tech_stack:
  added: [VisionKit, PDFKit]
  patterns: [UIViewControllerRepresentable-coordinator, Task.detached-sendable-primitives, MainActor-import-pipeline]
key_files:
  created:
    - Travellify/Features/Documents/Import/ScanView.swift
    - Travellify/Features/Documents/Import/ScanPDFAssembler.swift
    - Travellify/Features/Documents/Import/FilesImporter.swift
    - Travellify/Features/Documents/Import/DocumentImporter.swift
  modified:
    - Travellify/Features/Documents/DocumentListView.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "[02-03]: New Import/ files require manual PBXFileReference+PBXBuildFile registration in pbxproj — confirmed project uses explicit groups, not file-system-synchronized groups"
  - "[02-03]: ScanView coordinator methods have Swift 6 warnings about @MainActor isolation on delegate callbacks — compiler warnings only (not errors); do NOT add explicit @MainActor as UIKit overlay infers it automatically"
  - "[02-03]: DocumentImporter created alongside Task 1 bridges (pre-Task 2) because pbxproj already referenced it; all 4 files added to pbxproj in a single atomic group"
  - "[02-03]: Task.detached captures only Sendable primitives (String relativePath, Data, URL) — Trip/@Model never crosses actor boundary"
metrics:
  duration: ~23min
  completed: "2026-04-20"
  tasks_completed: 2
  files_created: 4
  files_modified: 2
---

# Phase 2 Plan 03: Import Bridges + DocumentImporter Pipeline Summary

Implemented all three document import flows (Scan/Photos/Files) via UIViewControllerRepresentable bridges and a shared `DocumentImporter` pipeline with off-main file I/O via `Task.detached` and `@MainActor` SwiftData inserts; wired DocumentListView to replace all `TODO(02-03)` stubs; added `NSCameraUsageDescription` to both Debug and Release app target buildSettings.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | ScanView + ScanPDFAssembler + FilesImporter | a8a9877 | Import/ScanView.swift, Import/ScanPDFAssembler.swift, Import/FilesImporter.swift |
| 2 | DocumentImporter + wire DocumentListView + NSCameraUsageDescription | b71551d | Import/DocumentImporter.swift, DocumentListView.swift, project.pbxproj |

## Xcode Target Membership

Manual pbxproj registration was required. The project uses explicit `PBXFileReference` and `PBXBuildFile` entries (not file-system-synchronized groups — confirmed from existing entries for FileStorage.swift, DocumentListView.swift etc.).

Added to pbxproj:
- New `Import` PBXGroup (`C20203A1B1C241829A0B5009`) under `Documents` group
- 4 PBXFileReference entries (BB, DD, FF, B1 prefixes with `0203A1` pattern)
- 4 PBXBuildFile entries (AA, CC, EE, A1 prefixes)
- 4 entries added to `8A4232BBCEEB498ABA81C38E` Sources build phase

## Swift 6 Concurrency Notes

**Coordinator @MainActor warnings (not errors):** The three delegate callback methods in `ScanView.Coordinator` produce Swift 6 warnings:
```
warning: main actor-isolated property 'onFinish' can not be referenced from a nonisolated context
```
These are **warnings only** — build succeeds. The UIKit overlay infers `@MainActor` on `VNDocumentCameraViewControllerDelegate` methods automatically. Per the research pattern, explicit `@MainActor` annotations are NOT added as they fight the overlay inference. These warnings are expected under Swift 6 `complete` concurrency checking and will appear again in Plan 02-06 tests. Tests should use `await MainActor.run { }` to invoke the coordinator callbacks if needed.

**Task.detached Sendable boundary:** All three `DocumentImporter` functions capture only `String` (relativePath, tripIDString), `Data`, and `URL` across the `Task.detached` boundary. `Trip` and `ModelContext` are never sent across actors — the entire function is `@MainActor` and only the I/O sub-step is detached.

**UIImage Sendable:** `UIImage` is `@unchecked Sendable` in Apple's UIKit overlay (iOS 17+). Passing `[UIImage]` into `Task.detached` compiles cleanly under Swift 6 strict concurrency.

## Simulator Smoke Test Observations

Full test suite (`xcodebuild test`) ran against iPhone 16e simulator and passed (exit code 0, two runs). Camera scan path requires physical device (VisionKit not available in simulator). Photos and Files import paths are testable in simulator but require interactive UI; covered by Plan 02-06 unit tests against `DocumentImporter` directly.

## NSCameraUsageDescription

Added as `INFOPLIST_KEY_NSCameraUsageDescription` to both Debug and Release `Travellify` target buildSettings blocks. Verified 2 occurrences in project.pbxproj. Value: `"Allow Travellify to use the camera to scan documents for your trips."`

## Plan 02-01 Assumption (Lightweight Migration)

No issues observed — the simulator store from prior runs continued to load without migration errors. The additive Document field defaults (all have SwiftData default values) remain compatible with SchemaV1 lightweight migration as confirmed in prior phases.

## Deviations from Plan

### Auto-created DocumentImporter alongside Task 1

**Found during:** Task 1 build verification
**Issue:** pbxproj already referenced `DocumentImporter.swift` in the Sources build phase after Task 1 edits, causing "Build input file cannot be found" error before Task 2 implementation.
**Fix:** Created `DocumentImporter.swift` with the full Task 2 implementation before the Task 1 verification build, then committed both sets of files in their respective task commits.
**Classification:** Rule 3 (auto-fix blocking issue) — the pbxproj edit for Task 1 included the Task 2 file reference to keep the group atomic; the file needed to exist for the build to succeed.

## Known Stubs

None. All three import paths are fully wired. The viewer (fullScreenCover) remains a `TODO(02-04)` stub as intended — not within scope of this plan.

## Threat Surface Scan

No new network endpoints, auth paths, or trust boundaries introduced beyond those documented in the plan's threat model (T-02-10 through T-02-15). All mitigations implemented as specified:
- T-02-10/T-02-15: `asCopy: true` + defensive `start/stopAccessingSecurityScopedResource` in `FileStorage.copy`
- T-02-11: `relativePath` constructed only from UUID strings; source filename used only for `displayName`
- T-02-12: Only user-safe error copy surfaced via `importErrorMessage`

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| ScanView.swift exists | FOUND |
| ScanPDFAssembler.swift exists | FOUND |
| FilesImporter.swift exists | FOUND |
| DocumentImporter.swift exists | FOUND |
| 02-03-SUMMARY.md exists | FOUND |
| Commit a8a9877 exists | FOUND |
| Commit b71551d exists | FOUND |
| TODO(02-03) count in DocumentListView = 0 | PASS |
| INFOPLIST_KEY_NSCameraUsageDescription count in pbxproj = 2 | PASS |
| xcodebuild test exit code = 0 | PASS (2 runs) |
