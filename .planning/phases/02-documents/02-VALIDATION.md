---
phase: 2
slug: documents
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-19
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `02-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (ships with Xcode 16+) |
| **Config file** | None required (test target already wired in Phase 1) |
| **Quick run command** | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Travellify.xcodeproj -scheme Travellify` (compile-only — catches Swift 6 concurrency errors fast, no simulator boot) |
| **Full suite command** | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination "platform=iOS Simulator,name=iPhone 16e"` |
| **Estimated runtime** | ~8s quick (compile), ~45s full suite (boot + tests) |

---

## Sampling Rate

- **After every task commit:** Run quick build (compile-only).
- **After every plan wave:** Run full `xcodebuild test` suite on iPhone 16e.
- **Before `/gsd-verify-work`:** Full suite green + manual simulator smoke (Photos import → list → viewer, Files import → list → viewer) + physical-device scan test if hardware available.
- **Max feedback latency:** 45 seconds (full suite).

---

## Per-Task Verification Map

| Req ID | Behavior | Test Type | Automated Command | File Exists |
|--------|----------|-----------|-------------------|-------------|
| DOC-01 | Scan produces combined PDF, inserts Document with `kind=.pdf`, file on disk | unit | `-only-testing:TravellifyTests/ImportTests/scanAssembliesPDFAndInsertsDocument` | ❌ W0 |
| DOC-01 | VisionKit bridge end-to-end (camera UI) | manual | Physical device: tap Scan, capture 2 pages, verify row | manual-only |
| DOC-02 | PhotosPicker `Data` → disk preserves original bytes | unit | `-only-testing:TravellifyTests/ImportTests/photosImportPreservesJpegBytes` | ❌ W0 |
| DOC-03 | Files importer copies source URL → `<tripUUID>/<docUUID>.<ext>` | unit | `-only-testing:TravellifyTests/ImportTests/filesImportCopiesToDestination` | ❌ W0 |
| DOC-04 | PDFView loads PDF URL smoke | smoke | `-only-testing:TravellifyTests/ViewerTests/pdfViewerLoadsDocumentUrl` | ❌ W0 |
| DOC-04 | Viewer pinch-zoom actually zooms | manual | Simulator two-finger pinch | manual-only |
| DOC-05 | Rename mutates `displayName` and persists | unit | `-only-testing:TravellifyTests/DocumentTests/renamePersistsDisplayName` | ❌ W0 |
| DOC-05 | Empty-trimmed rename rejected (Save disabled) | manual | Alert clear text → Save grey | manual-only |
| DOC-06 | Delete removes row + file; siblings untouched | unit | `-only-testing:TravellifyTests/DocumentTests/deleteRemovesFileAndModel` | ❌ W0 |
| DOC-07 | `fileRelativePath` is String (not Data); file exists on disk | unit | `-only-testing:TravellifyTests/DocumentTests/documentStoresPathNotData` | ❌ W0 |
| DOC-07 (cascade) | Deleting Trip removes `<tripUUID>/` folder | unit | `-only-testing:TravellifyTests/DocumentTests/tripCascadeDeleteRemovesTripFolder` | ❌ W0 |
| FileStorage | Write → resolve → read round-trip | unit | `-only-testing:TravellifyTests/FileStorageTests/writeThenResolveRoundTrip` | ❌ W0 |
| FileStorage | Missing file on `resolveURL` returns nil | unit | `-only-testing:TravellifyTests/FileStorageTests/missingFileReturnsNil` | ❌ W0 |
| FileStorage | Remove missing file is no-op (no throw) | unit | `-only-testing:TravellifyTests/FileStorageTests/removeMissingIsNoOp` | ❌ W0 |
| FileStorage | `removeTripFolder` removes subtree | unit | `-only-testing:TravellifyTests/FileStorageTests/removeTripFolderRemovesAllChildren` | ❌ W0 |
| Concurrency | Import writes off-main, inserts on-main (no thread-assert crash) | unit | `-only-testing:TravellifyTests/ImportTests/importRunsOffMainThenHopsToMain` | ❌ W0 |
| FOUND-03 | No new `@Attribute(.unique)` / `.deny` in Document model | static | `grep -rE "@Attribute\\(.unique\\|deleteRule: \\.deny" Travellify/Models/` (0 matches) | ✅ (script) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky — populated at execution time*

---

## Wave 0 Requirements

- [ ] `TravellifyTests/FileStorageTests.swift` — round-trip, missing file, remove, cascade folder
- [ ] `TravellifyTests/DocumentTests.swift` — model fields, rename, delete, cascade-removes-files, path-not-data
- [ ] `TravellifyTests/ImportTests.swift` — scan assembly (synthetic UIImages via `CGContext`), photos data write, files copy, concurrency off-main→on-main check (`Thread.isMainThread` + `#expect`)
- [ ] `TravellifyTests/ViewerTests.swift` — PDFView URL load smoke
- [ ] Test fixtures bundled in test target `Resources/`: `tiny-jpeg.jpg`, `tiny-heic.heic`, `tiny-pdf.pdf`
- [ ] `NSCameraUsageDescription` added to `Info.plist` (blocks DOC-01 physical-device test)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| VisionKit scan flow end-to-end | DOC-01 | Simulator has no camera — VisionKit cannot render | Run on physical iPhone (iOS 17+), tap Scan, capture 2 pages, confirm combined PDF row appears on list |
| Pinch-zoom in image viewer | DOC-04 | Gesture behavior not unit-testable | Simulator: import photo → open viewer → two-finger pinch → verify zooms and pans |
| Rename alert Save-disabled on empty trimmed | DOC-05 | SwiftUI `.alert` binding state not easily introspected | Open rename → clear text → confirm Save button greyed |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (4 test files + fixtures + Info.plist)
- [ ] No watch-mode flags (xcodebuild is one-shot)
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter after plans consume this

**Approval:** pending
