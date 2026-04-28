---
phase: 07-ui-overhaul
plan: 04
subsystem: packing-list-redesign
tags: [phase-7, packing, glass-cards, chrome-stripped-list, additive-relationship, swiftdata-lightweight-migration, inline-rename, focus-state, context-menu, figma-157-3616-3781-3867]
dependency_graph:
  requires: [07-01-design-foundation, 07-02-trips-empty-state, 07-03-trips-populated-list]
  provides: [packing-item-row, packing-category-card, packing-list-redesigned, trip-packing-items-relationship]
  affects: [Trip.swift, PackingItem.swift, PackingListView.swift]
tech_stack:
  added: []
  patterns:
    - chrome-stripped-list-mirror-of-07-03
    - glass-effect-card-with-rounded-rect-24
    - parent-owned-renaming-state-with-inline-helper-views
    - focusstate-chained-add-via-refocus-on-commit
    - additive-cascade-relationship-cloudkit-safe
    - lazy-backfill-via-task-modifier
key_files:
  created:
    - Travellify/Features/Packing/PackingItemRow.swift
    - Travellify/Features/Packing/PackingCategoryCard.swift
  modified:
    - Travellify/Models/Trip.swift
    - Travellify/Models/PackingItem.swift
    - Travellify/Features/Packing/PackingListView.swift
    - Travellify.xcodeproj/project.pbxproj
    - TravellifyTests/PackingTests.swift
    - .planning/phases/07-ui-overhaul/07-CONTEXT.md
  deleted:
    - Travellify/Features/Packing/CategoryHeader.swift
    - Travellify/Features/Packing/EmptyPackingListView.swift
    - Travellify/Features/Packing/PackingProgressRow.swift
    - Travellify/Features/Packing/PackingRow.swift
decisions:
  - "[07-04] Inline rename state lives at PackingListView (parent), not on PackingItemRow itself — per-row @FocusState would lose focus when the row re-renders during typing. Two helper views (InlineItemRenameRow for uncategorized, InlineRenameRow inside PackingCategoryCard) own their own @FocusState and commit/cancel through callbacks. Mirrors Phase 3 pattern."
  - "[07-04] Backfill helper runs from PackingListView's `.task { }`, not on first save. SwiftData lightweight migration is purely structural; data-level backfill is application code. Walks `trip.packingCategories.flatMap { $0.items }` once and sets `item.trip = item.category?.trip` for any nil — idempotent, safe to re-run."
  - "[07-04] Trip delete double-cascades through both `Trip.packingCategories → items` and `Trip.packingItems`. SwiftData handles overlapping cascade rules idempotently (each item is reachable from two cascade paths but only deleted once). Verified by `deleteTripCascadesUncategorizedItems` test."
  - "[07-04] PackingListView body split into `listView`, `uncategorizedSection`, `uncategorizedItemRow(_:)`, `categoriesSection`, `categoryCardRow(_:)` @ViewBuilder helpers — Phase 3 documented `>~150-line ViewBuilder closures with mixed control flow` blow up the Swift 6 type-checker. First combined `var body` hit the 'compiler unable to type-check this expression in reasonable time' error; splitting into helpers resolved it."
  - "[07-04] Inline category rename uses a separate `InlineCategoryTitleCard` view (not the PackingCategoryCard with a TextField inside) — keeps PackingCategoryCard's body small and isolates @FocusState lifecycle."
  - "[07-04] Toolbar `+` creates an empty PackingCategory then immediately sets `renamingCategory = newCat` to surface the inline title TextField. Fallback name `'Untitled'` is committed if the user submits an empty string (avoids a category with name=\"\")."
  - "[07-04] Cross-category drag-and-drop deferred per D7-25 — Phase 3's flat-ForEach-over-discriminated-union pattern doesn't fit the new per-card structure. Phase 3 'Move' contextMenu action is also retired in this redesign for parity. To re-add, ride a 07-04 wave-2."
  - "[07-04] Phase 3 leading-swipe Pack/Unpack and `sensoryFeedback(.success, trigger:)` retired — Figma shows no swipe affordance and the tap-on-checkbox toggle is the canonical check-off path. Animation via `.easeInOut(0.2)` on `item.isChecked` is sufficient feedback."
  - "[07-04] Pre-existing duplicate PBXBuildFile entry for PackingRow.swift (identical line on rows 41 and 42 of pbxproj) was cleaned up as part of the file removal."
metrics:
  duration: ~50min
  completed: 2026-04-28
---

# Phase 7 Plan 04: Packing List Redesign Summary

Wave 4 of Phase 7 sub-phase 7.4 (Packing). Replaces Phase 3's `List(.insetGrouped)` body, `CategoryHeader`, `PackingRow`, `PackingProgressRow`, and `EmptyPackingListView` with the Figma 157:3616 / 157:3781 / 157:3867 design — uncategorized items render as flat checkbox rows at the top, categories render as `.glassEffect(.clear, in: RoundedRectangle(24))` cards with their own per-card "Add item" affordance. Additive schema gain (`Trip.packingItems` cascade + `PackingItem.trip` back-ref, lightweight migration, no SchemaV2 bump) lets uncategorized items live without a category. Toolbar `+` now adds CATEGORIES (D7-23) and triggers focused inline title rename on the new card. Phase 3 interactions preserved (D7-24): tap-on-checkbox toggle with strikethrough animation, tap-on-label inline rename, swipe-trailing Delete, long-press contextMenu (Rename / Move-deferred / Delete on items; Rename / Delete on category cards). Cross-category drag-and-drop deferred per D7-25.

## What Shipped

- **`Travellify/Models/Trip.swift`** — `@Relationship(deleteRule: .cascade, inverse: \PackingItem.trip) var packingItems: [PackingItem]? = []`. Sits beside the existing `packingCategories` relationship; double-cascade is idempotent. CloudKit-safe (optional, no @Attribute).
- **`Travellify/Models/PackingItem.swift`** — `var trip: Trip?` back-ref (no @Relationship needed; the inverse on Trip handles it). Optional per CloudKit-safe rules. Categorized items get this set lazily by `PackingListView.backfillItemTripIfNeeded()`.
- **`Travellify/Features/Packing/PackingItemRow.swift`** — Three-mode reusable row (40pt height, 8pt gap):
  - `.item(unchecked)`: 24×24 secondarySystemBackground square + separator stroke, `.headline.weight(.semibold)` `.primary` label, tap-on-label callback.
  - `.item(checked)`: accentColor fill + white checkmark SF Symbol, `.secondary` label, `.strikethrough(true)`, `.easeInOut(0.2)` animation on `isChecked`.
  - `.addPlaceholder`: dashed-border 24×24 + TextField with chained-add UX (refocus after commit).
- **`Travellify/Features/Packing/PackingCategoryCard.swift`** — Glass card (20pt internal padding, `.glassEffect(.clear, in: RoundedRectangle(24))`); 16pt VStack gap between title and items; 4pt VStack gap between rows. Title `.font(.title3.weight(.semibold))`, falls back to `"Untitled"` for empty names. Composes `PackingItemRow` rows + a final `.addPlaceholder` row. Private `InlineRenameRow` swaps in when `renamingItem?.id == item.id`.
- **`Travellify/Features/Packing/PackingListView.swift`** — Rewritten body:
  - `List` with `.listStyle(.plain)`, `.listRowSpacing(16)`, `.listRowInsets(top:0, leading:16, bottom:0, trailing:16)`, `.listRowBackground(Color.clear)`, `.listRowSeparator(.hidden)`, `.scrollContentBackground(.hidden)`, `.background(Color(.systemBackground).ignoresSafeArea())`.
  - Section 1: uncategorized items via `@Query allTripItems.filter { $0.category == nil }`. Each row: PackingItemRow with `.swipeActions(.trailing) { Delete }` + `.contextMenu { Rename, Delete }`. Trailing add-item placeholder row commits new uncategorized items.
  - Section 2: each `PackingCategory` as a `PackingCategoryCard` (or `InlineCategoryTitleCard` while renaming) wrapped with `.contextMenu { Rename, Delete }` at the List row level (D7-16 placement).
  - Toolbar `+` calls `addCategory()` → inserts empty PackingCategory, sets `renamingCategory = newCat` (surfaces InlineCategoryTitleCard with focused TextField).
  - `.task { backfillItemTripIfNeeded() }` walks existing categorized items once on appear, idempotently sets `item.trip = item.category?.trip` where missing.
  - Body split into `@ViewBuilder` helpers (`listView` / `uncategorizedSection` / `uncategorizedItemRow(_:)` / `categoriesSection` / `categoryCardRow(_:)`) — Swift 6 type-checker rejected the combined body with "unable to type-check this expression in reasonable time" error.
- **Deleted files (Figma redesign):**
  - `CategoryHeader.swift` — replaced by PackingCategoryCard's title + contextMenu
  - `EmptyPackingListView.swift` — replaced by inline "Add item" row (Figma 157:3616)
  - `PackingProgressRow.swift` — redundant with TripDetailView UpcomingTripCard PackingBlock
  - `PackingRow.swift` — replaced by PackingItemRow
- **`Travellify.xcodeproj/project.pbxproj`** — Net entry delta: 8 added (PackingItemRow + PackingCategoryCard, 4 each: PBXBuildFile, PBXFileReference, group child, sources phase) − 17 removed (4 deleted files × 4 entries each + the pre-existing duplicate PBXBuildFile entry for PackingRow.swift). UUID prefix `AD0704...` for plan 07-04.
- **`TravellifyTests/PackingTests.swift`** — Three new tests (all passing):
  - `uncategorizedItemPersistsViaTrip()` — round-trip an uncategorized item via Trip.packingItems
  - `itemTripBackfillIdempotent()` — verifies the backfill helper logic; idempotent on re-run
  - `deleteTripCascadesUncategorizedItems()` — Trip delete cascades to both categorized + uncategorized items
- **`TravellifyTests/PackingProgressTests.swift`** — kept as-is. The progress-count formulas (Trip-level + per-category) still apply at the data layer; only the `PackingProgressRow` UI was retired. The progress logic now lives only on `TripDetailView` UpcomingTripCard's PackingBlock.
- **`.planning/phases/07-ui-overhaul/07-CONTEXT.md`** — appended `Revision 2026-04-28 — Packing redesign (07-04)` block with D7-21…D7-25.

## Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e'` after every task: **BUILD SUCCEEDED**. Only warnings emitted are pre-existing iOS 26 deprecations of `CLGeocoder` / `geocodeAddressString` / `UIScreen.main` from 07-03's TripMapSnapshotProvider — unaffected by this plan.
- `xcodebuild test` full suite after Task 5: **TEST SUCCEEDED** — 116 tests passed, 0 failed (`xcresulttool` summary). New PackingTests entries verified by name in xcresult tests output.
- pbxproj entries verified by successful Xcode build (host `plutil -lint` rejects modern JSON-formatted Apple plist inputs per 07-02 precedent).

### Schema Migration Outcome

The two new fields (`Trip.packingItems`, `PackingItem.trip`) are additive optional relationships and trigger SwiftData lightweight migration automatically — no SchemaV2 bump, no MigrationPlan stage. Existing categorized items load with `trip == nil` and remain functional via `category.trip`; the backfill helper closes the loop on first appearance of `PackingListView`. Trip cascade is double-pathed (`Trip → packingCategories → items` and `Trip → packingItems`); SwiftData handles the overlap idempotently. Verified by `deleteTripCascadesUncategorizedItems` test (mixes a categorized item and an uncategorized one, deletes the trip, asserts both are gone).

### Manual Verification (deferred to user — requires runtime data)

Per the plan's wave-4 exit gate, the following visual flows should be smoke-tested on iPhone 16e simulator with a real persisted trip:

1. **Empty trip:** opens to a single dashed-border "Add item" row at the top under the large "Packing" title. No category cards.
2. **Type "Socks" + return** in the dashed row → row commits as an uncategorized PackingItemRow; a fresh dashed "Add item" row reappears below.
3. **Tap toolbar `+`** → new empty glass card appears with focused TextField for the title. Type "Toiletries" + return → card commits with that title and shows its own dashed "Add item" row.
4. **Type "Toothbrush" + return** in the category's "Add item" row → row commits inside the card; the focus stays on a fresh "Add item" row for chained adds.
5. **Tap an item's checkbox** → checkbox flips to accentColor + white checkmark; label switches to `.secondary` + `.strikethrough(true)` with `.easeInOut(0.2)` transition.
6. **Tap an item's label** → swaps to `InlineItemRenameRow` (uncategorized) or InlineRenameRow inside the card. Type new name + return → renames; focus loss with empty/unchanged input cancels.
7. **Long-press an item row** → contextMenu shows `Rename` + `Delete` (Move retired per D7-25).
8. **Long-press a category card** → contextMenu shows `Rename` + `Delete`. Rename surfaces InlineCategoryTitleCard with prefilled draft; Delete shows confirmationDialog with item-count messaging.
9. **Swipe-trailing Delete** on an item row → destroys it.
10. **Backfill check:** after upgrading from a Phase 3 build with categorized items, opening PackingListView for any trip should leave `item.trip == item.category?.trip` for every existing item (idempotent — no log spam, no duplicate save thrash).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Combined `var body` exceeded Swift 6 type-checker budget**
- **Found during:** Task 4 first build attempt
- **Issue:** Initial PackingListView.swift had the entire List structure inline in `var body`. xcodebuild reported `error: the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions` at line 157. Phase 3 CONVENTIONS already documented this as a known pitfall (`>~150-line ViewBuilder closures with mixed control flow`).
- **Fix:** Split into 5 `@ViewBuilder` helpers — `listView`, `uncategorizedSection`, `uncategorizedItemRow(_:)`, `categoriesSection`, `categoryCardRow(_:)`. Build went green immediately.
- **Files modified:** `Travellify/Features/Packing/PackingListView.swift`
- **Commit:** Task 4 commit (rolled into the same commit that introduced the rewrite — refactor was part of getting Task 4 to compile, not a separate fix).

**2. [Rule 2 - Missing] Pre-existing duplicate PBXBuildFile entry for PackingRow.swift cleaned up**
- **Found during:** Task 4 pbxproj surgery
- **Issue:** Lines 41 and 42 of `project.pbxproj` had identical PBXBuildFile entries for PackingRow.swift (`AB1234567890ABCD0123450C /* PackingRow.swift in Sources */`). Harmless duplicate (same UUID), but a latent inconsistency from a prior plan.
- **Fix:** Both removed as part of the PackingRow.swift deletion. pbxproj is now clean.
- **Files modified:** `Travellify.xcodeproj/project.pbxproj`
- **Commit:** Task 4 commit.

### Notes (not auto-fixes)

**1. Inline rename @FocusState placement**
- The plan's `<read_first>` hinted at the existing PackingRow inline-rename pattern; the actual implementation places `@FocusState` on dedicated helper views (`InlineItemRenameRow`, `InlineRenameRow`, `InlineCategoryTitleCard`), each driven by parent-owned `renamingItem: PackingItem?` / `renamingCategory: PackingCategory?` state. Embedding `@FocusState` directly in PackingItemRow would lose focus on each typing-induced re-render of the row's parent List. This is a clean Phase 3 parity, just structured differently because the redesigned layout has more potential focus owners (uncategorized rows, in-card item rows, category titles).

**2. Backfill helper signature**
- Plan specified the helper as a small `task` walk over `trip.packingCategories?.flatMap(\.items)`. Implemented as `private func backfillItemTripIfNeeded()` returning Void; only saves the context if any item was actually mutated (avoids no-op saves on every appear after the first). Idempotency is verified by `itemTripBackfillIdempotent()` test.

**3. Delete cascade with additive Trip.packingItems**
- The plan called out the double-cascade design (`Trip → packingCategories → items` AND `Trip → packingItems`). Verified empirically: SwiftData's deletion-rule engine handles overlapping cascade paths idempotently — the same PackingItem is reachable from both paths but the underlying SQLite DELETE is issued exactly once, and the test `deleteTripCascadesUncategorizedItems` confirms zero remaining items after `context.delete(trip)` for a mixed (categorized + uncategorized) fixture.

**4. Test file state**
- `PackingProgressTests.swift` was kept as-is rather than deleted. The plan's Task 5 said "if most of the file's tests no longer apply, DELETE the file". On inspection, the tests verify count formulas at the data layer (e.g. `categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count`) which are the same formulas now used by TripDetailView UpcomingTripCard's PackingBlock — they're not row-UI tests. Keeping them protects the count logic.

**5. Test-runner transient flake**
- Two early `xcodebuild test` runs reported `Travellify (...) encountered an error (The test runner hung before establishing connection.)` — a known macOS simulator flake unrelated to the code. After cleaning DerivedData and rebooting the simulator, the run produced a clean xcresult: 116 passed / 0 failed / 0 skipped (verified via `xcresulttool get test-results summary`).

**6. Disk-pressure incident during Task 5**
- Mid-task the host filesystem hit 98% (260 MiB free). Cleared old TravelPlanner/TravelAvia DerivedData (≈ 1.5 GiB recovered) and re-ran tests successfully. No project files were affected.

## Auth Gates

None encountered.

## Out of Scope (deferred per plan)

- **Cross-category drag-and-drop reorder** — D7-25; ride in 07-04 wave 2 if user feedback warrants.
- **Reorder within a single category** — same deferral.
- **Move-to-category via context menu** — Phase 3 Move action retired this wave.
- **Leading swipe Pack/Unpack** + `sensoryFeedback(.success, trigger:)` — Figma shows no swipe affordance; tap-on-checkbox is the canonical path.
- **TripDetailView packing card visual changes** — independent of this plan.
- **Settings packing options** — v1.x.

## Commits

| Task | Commit  | Message |
|------|---------|---------|
| 1    | 70bfcd4 | feat(07-04): additive Trip.packingItems + PackingItem.trip relationship |
| 2    | 29b8910 | feat(07-04): PackingItemRow component (3-state checkbox + label) |
| 3    | ff4cd99 | feat(07-04): PackingCategoryCard glass card component |
| 4    | fd3c333 | feat(07-04): refactor PackingListView with chrome-stripped List + new components |
| 5    | ff1d547 | docs(07-04): packing-redesign tests + D7-21..D7-25 CONTEXT addendum |

## Self-Check: PASSED

- All created files exist on disk:
  - `Travellify/Features/Packing/PackingItemRow.swift` ✓
  - `Travellify/Features/Packing/PackingCategoryCard.swift` ✓
- All deleted files removed from disk:
  - `Travellify/Features/Packing/CategoryHeader.swift` ✓ (gone)
  - `Travellify/Features/Packing/EmptyPackingListView.swift` ✓ (gone)
  - `Travellify/Features/Packing/PackingProgressRow.swift` ✓ (gone)
  - `Travellify/Features/Packing/PackingRow.swift` ✓ (gone)
- Commit hashes resolve in `git log --oneline`: 70bfcd4, 29b8910, ff4cd99, fd3c333, ff1d547
- Xcode build green on iPhone 16e simulator (Xcode 26.2)
- Full xcodebuild test suite green via xcresulttool: 116 passed / 0 failed
- 07-CONTEXT.md grep confirms D7-21…D7-25 present
