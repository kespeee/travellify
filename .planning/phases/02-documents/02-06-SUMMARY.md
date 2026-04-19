---
phase: 02-documents
plan: "06"
subsystem: testing
tags: [swift-testing, file-storage, documents, import, pdf, concurrency]
dependency_graph:
  requires: [02-01, 02-02, 02-03, 02-04, 02-05]
  provides: [DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06, DOC-07]
  affects: [02-VALIDATION.md]
tech_stack:
  added: []
  patterns:
    - Swift Testing @Test + #expect (no XCTest in new files)
    - In-memory ModelContainer for SwiftData unit tests
    - Reference-type BundleAnchor class for fixture lookup in Swift Testing structs
    - Task.detached returning value to avoid nonisolated(unsafe) var across isolation domains
    - Non-async free function isOnMainThread() to safely call Thread.isMainThread under Swift 6
    - MainActor.assertIsolated() for post-await actor isolation verification
key_files:
  created:
    - TravellifyTests/FileStorageTests.swift
    - TravellifyTests/DocumentTests.swift
    - TravellifyTests/ImportTests.swift
    - TravellifyTests/ViewerTests.swift
  modified:
    - .planning/phases/02-documents/02-VALIDATION.md
decisions:
  - "Used flat model list (Trip.self, Destination.self, ...) instead of Schema(versionedSchema:) in makeContainer() — SchemaV1 type name in tests is TravellifySchemaV1, not SchemaV1"
  - "Converted Swift regex literal /^.../ to try Regex(...) for filesImportCopiesToDestination — Swift 6 regex literal parser rejects backslash-hyphen and escaped forward slash in that literal form"
  - "Restructured importRunsOffMainThenHopsToMain to return Bool from detached task instead of mutating nonisolated(unsafe) var — Swift 6 Sendable checker flags local var mutation across isolation domains even with nonisolated(unsafe)"
  - "Extracted isOnMainThread() as a non-async free function — Thread.isMainThread is unavailable from async contexts in Swift 6; a synchronous wrapper bypasses the restriction legally"
  - "Used MainActor.assertIsolated() instead of Thread.isMainThread after await — assertIsolated is the Swift 6 idiomatic way to assert main-actor isolation post-await"
metrics:
  duration: "~35 minutes (including 3 compile-fix iterations)"
  completed: "2026-04-20"
  tasks_completed: 3
  files_created: 4
  files_modified: 1
  tests_passing: 42
---

# Phase 02 Plan 06: Swift Testing Suite Summary

Swift Testing coverage for all Phase 2 DOC requirements — 16 new tests across 4 files, all passing on iPhone 16e; phase is now Nyquist-compliant.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fixtures + pbxproj wiring | 289d24f (prior executor) | tiny-jpeg.jpg, tiny-heic.heic, tiny-pdf.pdf, project.pbxproj |
| 2 | FileStorageTests + DocumentTests | 7369fca | TravellifyTests/FileStorageTests.swift, TravellifyTests/DocumentTests.swift |
| 3 | ImportTests + ViewerTests + CloudKit gate | 87d3ac1 | TravellifyTests/ImportTests.swift, TravellifyTests/ViewerTests.swift |

## Test Coverage

### FileStorageTests (6 tests)
- `writeThenResolveRoundTrip` — FileStorage round-trip byte equality
- `missingFileReturnsNil` — resolveURL returns nil for absent file
- `removeMissingIsNoOp` — remove on missing path does not throw
- `removeTripFolderRemovesAllChildren` — subtree removal + directory gone
- `pathTraversalIsRejected` — `..` and absolute paths throw
- `noUniqueOrDenyInModels` — CloudKit-safety static gate (walks Travellify/Models/)

### DocumentTests (6 tests)
- `defaultFieldsAreSet` — empty string defaults, kindRaw=pdf, importedAt within 1s
- `kindRoundTrip` — kindRaw ↔ kind computed property
- `renamePersistsDisplayName` — T-02-08: displayName mutates, fileRelativePath immutable
- `deleteRemovesFileAndModel` — DOC-06: file gone + SwiftData row gone
- `documentStoresPathNotData` — DOC-07: compile-time + Mirror check that path is String
- `tripCascadeDeleteRemovesTripFolder` — cascade: SwiftData deletes model, explicit removeTripFolder deletes disk

### ImportTests (4 tests)
- `scanAssembliesPDFAndInsertsDocument` — DOC-01: synthetic UIImages → PDF, %PDF- magic, 2 pages, Document inserted
- `photosImportPreservesJpegBytes` — DOC-02: fixture bytes written and read back identically
- `filesImportCopiesToDestination` — DOC-03: path matches `<UUID>/<UUID>.pdf` regex, bytes equal
- `importRunsOffMainThenHopsToMain` — concurrency: detached task confirmed off-main, MainActor.assertIsolated() after await

### ViewerTests (1 test)
- `pdfViewerLoadsDocumentUrl` — DOC-04: PDFView loads tiny-pdf.pdf, pageCount == 1, documentURL matches fixture

**Total: 42 tests passing (16 new Phase 2 tests + 26 pre-existing)**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SchemaV1 type name mismatch**
- **Found during:** Task 3 (first compile)
- **Issue:** ImportTests used `Schema(versionedSchema: SchemaV1.self)` but the actual VersionedSchema type is `TravellifySchemaV1`. Other test files use the flat `ModelContainer(for: Trip.self, ...)` pattern.
- **Fix:** Replaced `Schema(versionedSchema: SchemaV1.self)` with flat model list matching FileStorageTests/DocumentTests pattern.
- **Files modified:** TravellifyTests/ImportTests.swift
- **Commit:** 87d3ac1

**2. [Rule 1 - Bug] Swift regex literal syntax rejected by Swift 6 parser**
- **Found during:** Task 3 (compile) — ImportTests.swift:144
- **Issue:** `/^[A-F0-9a-f\-]+\/[A-F0-9a-f\-]+\.pdf$/` — backslash-hyphen in character class and escaped forward slash are rejected by Swift's regex literal parser.
- **Fix:** Converted to `try Regex("^[A-F0-9a-f-]+/[A-F0-9a-f-]+\\.pdf$")`.
- **Files modified:** TravellifyTests/ImportTests.swift
- **Commit:** 87d3ac1

**3. [Rule 1 - Bug] Thread.isMainThread unavailable from async context (Swift 6)**
- **Found during:** Task 3 (compile) — two call sites in importRunsOffMainThenHopsToMain
- **Issue:** Swift 6 bans `Thread.isMainThread` in async contexts. The `Task.detached` async closure and `@MainActor` async test body both triggered the restriction.
- **Fix:**
  - Extracted `isOnMainThread()` as a non-async free function (Swift 6 permits `Thread.isMainThread` in synchronous non-isolated functions).
  - Restructured the test to return `Bool` from the detached task rather than mutating a `nonisolated(unsafe) var` — Swift 6 Sendable checker also flagged the shared local capture.
  - Replaced `#expect(Thread.isMainThread == true)` with `MainActor.assertIsolated()` for the post-await on-main assertion.
- **Files modified:** TravellifyTests/ImportTests.swift
- **Commit:** 87d3ac1

## Known Stubs

None — all tests exercise real implementations from plans 02-01 through 02-05.

## Threat Flags

None — test files introduce no new network endpoints, auth paths, or trust boundaries.

## Nyquist Compliance

`02-VALIDATION.md` updated: `nyquist_compliant: true`, `wave_0_complete: true`.

All Wave 0 gaps from the validation table are now covered by automated `@Test` functions. Manual-only verifications (VisionKit camera, pinch-zoom, rename-Save-disabled) remain tracked in the Manual-Only table and do not block Wave 0 sign-off.

## Self-Check: PASSED

- TravellifyTests/FileStorageTests.swift: exists, 6 @Test functions
- TravellifyTests/DocumentTests.swift: exists, 6 @Test functions
- TravellifyTests/ImportTests.swift: exists, 4 @Test functions
- TravellifyTests/ViewerTests.swift: exists, 1 @Test function
- Commits 7369fca and 87d3ac1: present in git log
- Full xcodebuild test: ** TEST SUCCEEDED ** (42/42)
- grep @Attribute(.unique) Travellify/Models/: 0 matches
