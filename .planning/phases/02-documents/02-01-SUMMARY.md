---
phase: 02-documents
plan: 01
subsystem: models, services, navigation
tags: [swiftdata, filesystem, navigation, document-model]
dependency_graph:
  requires: [01-foundation-trips]
  provides: [Document-D10-fields, DocumentKind-enum, FileStorage-service, AppDestination-documentList]
  affects: [02-02-document-list, 02-03-importers, 02-04-viewer, 02-05-rename-delete, 02-06-trip-wiring]
tech_stack:
  added: [OSLog (FileStorage logging)]
  patterns: [enum-as-namespace-with-static-methods, lightweight-swiftdata-migration, path-traversal-defense]
key_files:
  created:
    - Travellify/Services/FileStorage.swift
  modified:
    - Travellify/Models/Document.swift
    - Travellify/App/AppDestination.swift
    - Travellify/ContentView.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "D10 lightweight migration confirmed: additive fields with defaults do not require SchemaV2 — migrationPlanHasNoStages test still passes"
  - "FileStorage.swift required manual pbxproj registration (explicit PBXFileReference project, not file-system synchronized groups)"
  - "Services group added to Travellify group in pbxproj at same level as Models, Features, Shared"
metrics:
  duration: ~15min
  completed: 2026-04-20
  tasks_completed: 3
  files_changed: 5
---

# Phase 2 Plan 01: Foundation Model + FileStorage + Navigation Summary

**One-liner:** Extended Document @Model with D10 fields (displayName, fileRelativePath, kindRaw, importedAt), added DocumentKind enum (pdf|image), created FileStorage enum service with path-traversal defense, and extended AppDestination with .documentList case.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend Document @Model + DocumentKind | e72f5a5 | Travellify/Models/Document.swift |
| 2 | Create FileStorage service | e0f8d61 | Travellify/Services/FileStorage.swift, project.pbxproj |
| 3 | Extend AppDestination + ContentView stub | 0a0bfcd | Travellify/App/AppDestination.swift, Travellify/ContentView.swift |

## Verification Results

- `xcodebuild build` exit 0 (after each task)
- Full test suite: 16/16 passed (SmokeTests, TripTests, SchemaTests, PartitionTests all green)
- `migrationPlanHasNoStages` test still passes — confirms SchemaV1 lightweight migration assumption A1 is correct
- No `@Attribute(.unique)` or `deleteRule: .deny` in Document.swift — CloudKit safe
- `grep -rE "@Attribute\(.unique|deleteRule: \.deny" Travellify/Models/` returns zero

## SwiftData Migration Observation (A1 Confirmation)

**Confirmed:** Adding four fields with default values to `TravellifySchemaV1.Document` inside the existing SchemaV1 does NOT require a SchemaV2 or MigrationStage. The `TravellifyMigrationPlan.stages == []` invariant holds — the existing schema tests pass without modification. This is the pre-production lightweight migration path documented in RESEARCH §Pattern 1.

No workaround needed (no simulator wipe, no SchemaV2 bump).

## pbxproj Manual Registration

Since the project uses explicit PBXFileReference entries (hand-written pbxproj, not file-system synchronized groups), `Travellify/Services/FileStorage.swift` required manual registration:

- Added `B3C4D5E6F7A841829A0B3002` PBXFileReference entry
- Added `A2B3C4D5E6F741829A0B3001` PBXBuildFile entry
- Added `C4D5E6F7A8B941829A0B3003` Services PBXGroup under Travellify group
- Added FileStorage.swift to `8A4232BBCEEB498ABA81C38E` PBXSourcesBuildPhase

All downstream Phase 2 plans adding new files to Services must follow the same manual registration pattern.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `Travellify/ContentView.swift` line ~14: `Text("Documents coming soon")` stub arm for `.documentList` — intentional, tagged `TODO(02-02)`. Plan 02-02 will replace with `DocumentListView(tripID: id)`.

## Threat Flags

None. All T-02-01 and T-02-02 mitigations are in place:
- Path-traversal defense: `validateRelativePath` and `validateComponent` reject `..`, leading `/`, leading `.`
- Logger privacy: all document IDs and paths use `privacy: .private`

## Self-Check: PASSED

- `Travellify/Models/Document.swift` — exists, contains all 4 D10 fields
- `Travellify/Services/FileStorage.swift` — exists, contains all 7 static methods
- `Travellify/App/AppDestination.swift` — contains `case documentList(PersistentIdentifier)`
- `Travellify/ContentView.swift` — contains `.documentList` switch arm with `TODO(02-02)`
- Commits e72f5a5, e0f8d61, 0a0bfcd — all present in git log
