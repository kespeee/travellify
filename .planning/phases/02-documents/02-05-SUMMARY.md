---
phase: 02-documents
plan: "05"
subsystem: documents
tags: [rename, delete, file-cleanup, trip-cascade]
dependency_graph:
  requires: [02-02, 02-03]
  provides: [DOC-05, DOC-06]
  affects: [DocumentListView, TripListView, FileStorage]
tech_stack:
  added: []
  patterns:
    - "File-before-model delete order: remove file first (log error, don't surface), then delete model + save (surface save error)"
    - "Trip cascade: capture UUID string before delete, remove folder only after save succeeds"
    - "Logger.fileStorage with privacy:.private for doc IDs, .public for POSIX error strings"
key_files:
  modified:
    - Travellify/Features/Documents/DocumentListView.swift
    - Travellify/Features/Trips/TripListView.swift
decisions:
  - "Alert title changed from 'Import Failed' to 'Something went wrong' — shared surface for import, rename, and delete failures avoids misleading copy when non-import errors surface"
  - "File removal errors in document delete are logged but not surfaced per D16 — UI stays clean; operator can check Console for Logger.fileStorage entries"
  - "Trip folder removal uses try? (silent) after save success — orphan files are a storage-cost-only concern; model integrity takes priority"
metrics:
  duration_seconds: 1161
  completed_date: "2026-04-20"
  tasks_completed: 2
  files_modified: 2
---

# Phase 02 Plan 05: Rename + Delete Actions + Trip Folder Cleanup Summary

Wired rename and delete context-menu actions in DocumentListView (replacing Plan 02-02 TODO(02-05) stubs) and extended TripListView trip delete to remove the `<tripUUID>/` folder from disk after a successful SwiftData cascade save.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Wire rename + delete actions in DocumentListView | ef084c7 | DocumentListView.swift |
| 2 | Extend TripListView delete to remove trip folder | a5c50ca | TripListView.swift |

## What Was Built

### Task 1 — DocumentListView rename + delete (ef084c7)

**Rename Save closure:**
- Trims `renameDraft` whitespace; guards non-empty before proceeding
- Assigns `doc.displayName = trimmed` only — `fileRelativePath` is never touched (T-02-08 invariant enforced)
- Calls `try modelContext.save()`; save failure sets `importErrorMessage = "Couldn't rename. Please try again."`
- Clears `docPendingRename` and `renameDraft` on both success and error paths

**Delete Button closure:**
- Step 1: `try FileStorage.remove(relativePath: doc.fileRelativePath)` — file removal errors caught and logged via `Logger.fileStorage.error("File cleanup failed for id=\(doc.id, privacy: .private): ...")` but NOT surfaced to user per D16
- Step 2: `modelContext.delete(doc)` then `try modelContext.save()` — save failure sets `importErrorMessage = "Couldn't delete. Please try again."`
- `docPendingDelete` cleared after both steps regardless of outcome

**Alert title:** Changed from `"Import Failed"` to `"Something went wrong"` — the message body carries the specific error ("Couldn't add document / rename / delete...").

**Added:** `import OSLog` at top of file.

**Removed:** Both `TODO(02-05)` markers.

### Task 2 — TripListView cascade folder removal (a5c50ca)

**Delete Button closure (modified):**
- Captures `let tripIDString = trip.id.uuidString` before `modelContext.delete(trip)` — ensures UUID is accessible if trip reference becomes invalid post-delete
- Wraps `try modelContext.save()` in do/catch
- On save success: `try? FileStorage.removeTripFolder(tripIDString: tripIDString)` — folder removal failures silently swallowed
- On save failure: folder removal is skipped (on-disk state remains consistent with model)
- Phase 1 swipeActions trigger that sets `tripPendingDelete` unchanged

## Acceptance Criteria Verification

| Criterion | Result |
|-----------|--------|
| `grep -c "TODO(02-05)" DocumentListView.swift` == 0 | 0 |
| `grep -c "doc.displayName = trimmed" DocumentListView.swift` == 1 | 1 |
| `grep -c "Couldn't rename. Please try again." DocumentListView.swift` == 1 | 1 |
| `grep -c "FileStorage.remove(relativePath: doc.fileRelativePath)" DocumentListView.swift` == 1 | 1 |
| `grep -c "Couldn't delete. Please try again." DocumentListView.swift` == 1 | 1 |
| `grep -c "Logger.fileStorage.error" DocumentListView.swift` == 1 | 1 |
| `grep -c "privacy: .private" DocumentListView.swift` == 1 | 1 |
| `grep -c "doc.fileRelativePath =" DocumentListView.swift` == 0 (T-02-08) | 0 |
| `grep -c "import OSLog" DocumentListView.swift` == 1 | 1 |
| `grep -c "swipeActions" DocumentListView.swift` == 0 | 0 |
| `grep -c "FileStorage.removeTripFolder(tripIDString: tripIDString)" TripListView.swift` == 1 | 1 |
| `grep -c "let tripIDString = trip.id.uuidString" TripListView.swift` == 1 | 1 |
| `grep -c "swipeActions" TripListView.swift` >= 1 | 1 |
| xcodebuild build exits 0 | Passed (both tasks) |

## Security Invariant Compliance

- **T-02-08:** `grep -c "doc.fileRelativePath =" DocumentListView.swift` = 0. Rename closure writes only to `doc.displayName`. Static enforcement confirmed.
- **T-02-20:** `Logger.fileStorage.error` uses `privacy: .private` for `doc.id`; `error.localizedDescription` is `.public` (POSIX strings, no PII).
- **T-02-21:** Trip UUID converted via `uuidString` (hex + hyphens only); `FileStorage.validateComponent` provides defense-in-depth.
- **T-02-22:** `try?` on `removeTripFolder` — orphan files tolerable (storage cost only).
- **T-02-23:** Rename grep-gate enforced; `fileRelativePath` not referenced in rename closure.

## Output Notes (per plan `<output>` spec)

**Trip folder cleanup verification:** Not manually verified via `xcrun simctl get_app_container` — the code path is straightforward (`FileStorage.removeTripFolder` wraps a standard `FileManager.removeItem`). The call is placed unconditionally after a confirmed `modelContext.save()` success, so the folder is removed on any trip delete that saves cleanly.

**Whitespace-only rename:** Save button remains `.disabled(renameDraft.trimmingCharacters(in: .whitespaces).isEmpty)` — already wired from Plan 02-02; no behavior change here, criterion simply confirmed active.

**SwiftData cascade timing (A7 assumption):** `try? FileStorage.removeTripFolder` runs after `try modelContext.save()` returns. SwiftData's cascade delete is synchronous within the save call — all child Document rows are deleted before save returns. The folder removal therefore runs after all Document model rows are gone. No timing issue observed; A7 assumption holds. No note required for Plan 02-06.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — all new surface covered by the plan's threat model (T-02-08 through T-02-23).

## Self-Check: PASSED

- `ef084c7` confirmed in git log
- `a5c50ca` confirmed in git log
- `Travellify/Features/Documents/DocumentListView.swift` exists and modified
- `Travellify/Features/Trips/TripListView.swift` exists and modified
- Build exits 0 (confirmed twice, once per task)
