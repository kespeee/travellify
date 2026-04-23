---
phase: 06-polish-testflight
plan: 01
subsystem: ui-polish
tags: [documents, packing, trips, activities, datepicker, tdd]
requires: [phase-01, phase-02, phase-03, phase-04, phase-05]
provides:
  - "D70: 3:4 document thumbnail aspect ratio"
  - "D71: centered document display name"
  - "D72: DocumentImporter.nextDefaultName(in:) per-trip sequential doc-N naming"
  - "D73: vertically centered packing empty state"
  - "D74: bounded/auto-aligned trip date pickers"
  - "D75: activity DatePicker clamped to trip range (soft-warn preserved)"
affects:
  - "Phase 2 Document UI (thumbnail + row)"
  - "Phase 3 Packing empty state"
  - "Phase 1 TripEditSheet date inputs"
  - "Phase 4 ActivityEditSheet DatePicker"
tech_stack:
  added: []
  patterns:
    - "Swift regex literal (/^doc-(\\d+)$/) with wholeMatch + Optional capture parsing"
    - "SwiftUI DatePicker(in:) range-clamping"
    - "two-parameter onChange(of:) iOS 17+"
key_files:
  created: []
  modified:
    - Travellify/Features/Documents/DocumentThumbnail.swift
    - Travellify/Features/Documents/DocumentRow.swift
    - Travellify/Features/Documents/Import/DocumentImporter.swift
    - Travellify/Features/Packing/EmptyPackingListView.swift
    - Travellify/Features/Trips/TripEditSheet.swift
    - Travellify/Features/Activities/ActivityEditSheet.swift
    - TravellifyTests/ImportTests.swift
    - TravellifyTests/ActivityTests.swift
decisions:
  - "[06-01] localizedDateString() deleted — zero remaining callers after D72 wiring (minor deviation, Rule 2 cleanliness)"
  - "[06-01] DocumentRow VStack alignment: .leading kept per plan ('Leave VStack line 16 unchanged') despite grep acceptance criterion for alignment: .leading = 0; only Text frame alignment was flipped to .center (intended D71 surface)"
  - "[06-01] nextDefaultName uses Swift regex literal with optional capture-group parsing through wholeMatch — iOS 17 compatible"
metrics:
  duration: ~18min
  completed: 2026-04-24
  tasks: 2
  files_modified: 8
---

# Phase 6 Plan 1: UI Polish Bundle Summary

Six UI polish decisions (D70–D75) shipped across Documents, Packing, Trips, Activities. DocumentImporter gained `nextDefaultName(in:)` helper; three import paths now emit per-trip sequential `doc-N` names; legacy out-of-range day-level compare semantics locked by test.

## What Shipped

- **D70** — `DocumentThumbnail.swift:23` → `.aspectRatio(3.0/4.0, contentMode: .fit)`.
- **D71** — `DocumentRow.swift:24-25` → `multilineTextAlignment(.center)` + `frame(maxWidth: .infinity, alignment: .center)` on the `Text(document.displayName)`. VStack(alignment: .leading) preserved per plan.
- **D72** — `DocumentImporter.nextDefaultName(in:)` helper at line ~107 (new). Three call sites (`importScanResult`, `importPhotosItem`, `importFileURL`) replace prior auto-names. Regex `/^doc-(\d+)$/` via `wholeMatch`; `(trip.documents ?? []).max()`; no gap reuse. `localizedDateString()` removed (no remaining callers).
- **D73** — `EmptyPackingListView.swift` → `Spacer(minLength: 0)` pair wraps icon+titles inside the `VStack(spacing: 0)`.
- **D74** — `TripEditSheet.swift`:
  - Line 52: `DatePicker("Start Date", ...)` gained `.onChange(of: startDate) { _, newStart in if newStart > endDate { endDate = newStart } }`.
  - Line 56: `DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)`.
  - Removed: `showEndDateError` computed property, the `if showEndDateError { Text(...) }` branch.
  - `isValid` simplified to `true` — picker constraint + onChange auto-align make the prior invariant unreachable.
- **D75** — `ActivityEditSheet.swift`:
  - DatePicker at line 64–69 gained `in: trip.startDate...trip.endDate`.
  - `isOutsideTripRange` (line 37) and the soft-warn `HStack` (line 72) preserved; `grep -c isOutsideTripRange` == 2.

## Tests

All suites green on iPhone 16e (iOS 26 simulator, Xcode 26.2):

- `ImportTests/defaultNameStartsAtOne` — empty trip → `doc-1`
- `ImportTests/defaultNameIncrementsPastMax` — `[doc-1, doc-3]` → `doc-4` (no gap reuse)
- `ImportTests/defaultNameIgnoresNonMatching` — `[Passport.pdf, doc-2]` → `doc-3`
- `ActivityTests/outsideRangeDayLevel` — locks day-level `startOfDay` compare semantics
- Pre-existing ImportTests (4) + ActivityTests (5) all still pass.

## Commits

| Gate | Hash | Message |
|------|------|---------|
| Task 1 | 4fa7f1c | feat(06-01): apply D70/D71/D73/D74/D75 UI polish edits |
| RED   | a805f1c | test(06-01): add failing tests for nextDefaultName + day-level outside-range |
| GREEN | 8608ee8 | feat(06-01): implement D72 nextDefaultName(in:) + wire 3 import paths |

## Deviations from Plan

### Auto-fixed

**1. [Rule 2 - Cleanliness] Removed now-unused `localizedDateString()` helper**
- **Found during:** Task 2 GREEN
- **Issue:** After D72 wiring, the previously-used helper had zero callers in the entire codebase → Swift would emit an unused-private-function warning.
- **Fix:** Deleted the function body.
- **Files modified:** `Travellify/Features/Documents/Import/DocumentImporter.swift`
- **Commit:** 8608ee8
- **Also removed:** the `let sourceName = url.deletingPathExtension().lastPathComponent` local in `importFileURL` — it was solely used to compute the previous displayName fallback.

### Spec-vs-code tension resolved

**2. DocumentRow acceptance criterion `alignment: .leading == 0` not literally met**
- The `<action>` block explicitly said "Leave VStack (line 16) ... unchanged"; the VStack's `alignment: .leading` remains.
- Only the `Text(document.displayName)` block's `.leading` modifiers were flipped to `.center` (the actual D71 surface — the text is centered inside the grid cell).
- Grep count for `alignment: .leading` is 1, not 0 — by design. Flagged here so the verifier does not mis-read it.

## Output Questions (from plan)

- **`localizedDateString()`:** DELETED — no remaining callers.
- **Current line numbers post-edit:**
  - TripEditSheet.swift: startDate picker line 52, onChange 53–55, endDate picker line 56, `isValid` at line 25.
  - ActivityEditSheet.swift: `isOutsideTripRange` at line 37–43, DatePicker at lines 64–69, soft-warn HStack at lines 71–82.
- **Preview snapshot caveats:** none observed at build time (UI behavior validated by build, manual visual inspection to follow under `/gsd-verify-work`).
- **`isOutsideTripRange` reference count:** 2 in `ActivityEditSheet.swift` (definition + use site in the soft-warn branch). Confirmed.

## TDD Gate Compliance

- RED gate present (a805f1c — `test(06-01): add failing tests for nextDefaultName...`).
- GREEN gate present (8608ee8 — `feat(06-01): implement D72 nextDefaultName(in:) ...`).
- REFACTOR gate: not applicable (no refactor needed — initial implementation was already minimal).

## Self-Check: PASSED

- FOUND: Travellify/Features/Documents/DocumentThumbnail.swift
- FOUND: Travellify/Features/Documents/DocumentRow.swift
- FOUND: Travellify/Features/Documents/Import/DocumentImporter.swift
- FOUND: Travellify/Features/Packing/EmptyPackingListView.swift
- FOUND: Travellify/Features/Trips/TripEditSheet.swift
- FOUND: Travellify/Features/Activities/ActivityEditSheet.swift
- FOUND: TravellifyTests/ImportTests.swift
- FOUND: TravellifyTests/ActivityTests.swift
- FOUND commits: 4fa7f1c, a805f1c, 8608ee8
- Build: SUCCEEDED on iPhone 16e (Xcode 26.2).
- Tests: ALL PASSED (ImportTests + ActivityTests suites).
