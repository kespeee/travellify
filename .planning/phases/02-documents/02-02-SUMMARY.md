---
phase: 02-documents
plan: 02
subsystem: documents-ui, navigation
tags: [swiftui, swiftdata, navigation, document-list, empty-state, context-menu]
dependency_graph:
  requires: [02-01-foundation-model-filestorage-navigation]
  provides: [DocumentListView, DocumentRow, EmptyDocumentsView, TripDetail-Documents-card-wire]
  affects: [02-03-importers, 02-04-viewer, 02-05-rename-delete]
tech_stack:
  added: [PhotosUI (PhotosPickerItem import in DocumentListView shell)]
  patterns: [Query-init-tripID-workaround, contextMenu-only-no-swipeActions, fullScreenCover-placeholder, NavigationLink-value-AppDestination]
key_files:
  created:
    - Travellify/Features/Documents/EmptyDocumentsView.swift
    - Travellify/Features/Documents/DocumentRow.swift
    - Travellify/Features/Documents/DocumentListView.swift
  modified:
    - Travellify/Features/Trips/TripDetailView.swift
    - Travellify/ContentView.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "DocumentRow preview uses immediately-invoked closure pattern (same as TripRow) — #Preview macro body is @ViewBuilder; let + mutation statements must be inside a closure, not at top level"
  - "DocumentRow imports SwiftData (required for Document model in non-DocumentListView file)"
  - "pre-registered DocumentListView.swift in pbxproj before file creation caused first build failure — future plans should create files first then register, or register and create atomically"
metrics:
  duration: ~25min
  completed: 2026-04-20
  tasks_completed: 3
  files_changed: 6
---

# Phase 2 Plan 02: Document List UI Summary

**One-liner:** DocumentListView with @Query tripID filter + EmptyDocumentsView + DocumentRow (kind-branched icon, chevron) + context-menu Rename/Delete placeholders; TripDetailView Documents card wired to push .documentList with count + latest-name display.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create EmptyDocumentsView + DocumentRow | ffa505d | Travellify/Features/Documents/EmptyDocumentsView.swift, DocumentRow.swift |
| 2 | Create DocumentListView + wire ContentView | b3e3648 | Travellify/Features/Documents/DocumentListView.swift, ContentView.swift, project.pbxproj |
| 3 | Wire TripDetailView Documents card | 6dcfb2f | Travellify/Features/Trips/TripDetailView.swift |

## Verification Results

- `xcodebuild build` exit 0 after each task
- Full test suite: 16/16 passed (SmokeTests, SchemaTests, PartitionTests, TripTests all green)
- `grep -c ".swipeActions" DocumentListView.swift` = 0 (D15 constraint confirmed)
- All 3 TODO tags confirmed: 5× `TODO(02-03)`, 1× `TODO(02-04)`, 2× `TODO(02-05)` in DocumentListView.swift
- `grep -rE "@Attribute\(.unique|deleteRule: \.deny" Travellify/Models/` = 0 (CloudKit safety maintained)
- PhotosUI imported in DocumentListView (iOS 16+ API)
- `TODO(02-02)` removed from ContentView — stub replaced with `DocumentListView(tripID: id)`

## TODO Marker Inventory (for downstream plans)

All markers are in `Travellify/Features/Documents/DocumentListView.swift`:

| Marker | Count | Location | Plan to resolve |
|--------|-------|----------|-----------------|
| `TODO(02-03)` | 5 | Scan sheet body, Files sheet body, 2× scan/files comments, onChange(of: photosItem) | Plan 02-03 importers |
| `TODO(02-04)` | 1 | fullScreenCover body (viewer placeholder) | Plan 02-04 viewer |
| `TODO(02-05)` | 2 | Rename alert Save action, Delete confirmationDialog Delete action | Plan 02-05 rename/delete |

## pbxproj Manual Registration

Three new files added to `Features/Documents/` group (new group created):

| File | PBXFileReference UUID | PBXBuildFile UUID |
|------|-----------------------|-------------------|
| EmptyDocumentsView.swift | E6F7A8B9CADB41829A0B4002 | D5E6F7A8B9CA41829A0B4001 |
| DocumentRow.swift | A8B9CADBECFD41829A0B4004 | F7A8B9CADBEC41829A0B4003 |
| DocumentListView.swift | CADBECFD0E1F41829A0B4006 | B9CADBECFD0E41829A0B4005 |

Documents group UUID: `DB0E1F2031425341829A0B50` under Features group `5562B32A48F5466CB919BC1F`.

All downstream Phase 2 plans adding files to `Features/Documents/` must register using the same manual PBXFileReference pattern.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DocumentRow preview #Preview body is @ViewBuilder — let/mutation statements illegal at top level**
- **Found during:** Task 1 build verification
- **Issue:** `#Preview { let doc = Document(); doc.displayName = ...; return List { ... } }` — `return` and intermediate `let` statements are not valid in a `@ViewBuilder` `#Preview` body
- **Fix:** Moved object setup into an immediately-invoked closure: `DocumentRow(document: { let d = Document(); ...; return d }())` — matches TripRow.swift preview pattern exactly
- **Files modified:** Travellify/Features/Documents/DocumentRow.swift
- **Commit:** ffa505d (included in same commit after fix)

**2. [Rule 3 - Blocking] DocumentRow missing `import SwiftData`**
- **Found during:** Task 1 build — `ModelContainer` and `ModelConfiguration` not in scope
- **Fix:** Added `import SwiftData` to DocumentRow.swift header
- **Files modified:** Travellify/Features/Documents/DocumentRow.swift
- **Commit:** ffa505d

**Note on registration order:** DocumentListView.swift was registered in pbxproj before the file was created on disk. The first build attempt failed with "Build input file cannot be found". Fixed by creating the file immediately. Future plans should create the file and register in pbxproj atomically (or create first, then register).

## Known Stubs

| Stub | File | Description | Resolves in |
|------|------|-------------|-------------|
| Scan sheet body | DocumentListView.swift ~line 87 | `Text("Scan importer — TODO(02-03)")` | Plan 02-03 |
| Files sheet body | DocumentListView.swift ~line 94 | `Text("Files importer — TODO(02-03)")` | Plan 02-03 |
| PhotosPicker onChange | DocumentListView.swift ~line 101 | No-op, sets `photosItem = nil` | Plan 02-03 |
| Viewer fullScreenCover | DocumentListView.swift ~line 105 | `Text("Viewer coming soon") + doc.displayName` | Plan 02-04 |
| Rename Save action | DocumentListView.swift ~line 119 | No-op, clears state only | Plan 02-05 |
| Delete action | DocumentListView.swift ~line 133 | No-op, clears state only | Plan 02-05 |

These stubs are intentional per plan objective — the navigation shell and list shape land in 02-02; actual importer/viewer/mutation bodies land in 02-03/04/05.

## Threat Flags

None. T-02-06 (tripID as PersistentIdentifier, not user string) is satisfied — `@Query` init takes `PersistentIdentifier` directly. T-02-07 (preview seed data DEBUG-only) is satisfied — all previews wrapped in `#if DEBUG`. T-02-08 (rename closure is no-op TODO(02-05)) is satisfied — deferred to Plan 02-05 which must enforce trim + non-empty + displayName-only assignment per the threat register.

## Self-Check: PASSED

- `Travellify/Features/Documents/EmptyDocumentsView.swift` — exists
- `Travellify/Features/Documents/DocumentRow.swift` — exists
- `Travellify/Features/Documents/DocumentListView.swift` — exists
- Commits ffa505d, b3e3648, 6dcfb2f — all present in git log
- `grep -c "DocumentListView(tripID: id)" Travellify/ContentView.swift` = 1
- `grep -c "AppDestination.documentList(trip.persistentModelID)" TripDetailView.swift` = 1
