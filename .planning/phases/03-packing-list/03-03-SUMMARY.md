---
phase: 03-packing-list
plan: 03
subsystem: ui
tags: [swiftui, swiftdata, packing, interactions, swipe, haptics, drag-drop, focusstate, inline-edit]

# Dependency graph
requires:
  - phase: 03-02
    provides: PackingListView scaffold, CategoryHeader, EmptyPackingListView, PackingProgressRow, errorMessage alert

provides:
  - PackingRow: item row view with Text/TextField branch, checked styling (strikethrough+secondary), .draggable(uuidString)
  - PackingListView: extended with dual @FocusState, item CRUD mutations, swipe actions, sensoryFeedback, inline add-item row, inline rename
  - CategoryHeader: extended with onDropItem + .dropDestination(for: String.self)

affects: [03-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@FocusState.Binding cannot use .constant — preview wrapper struct must own @FocusState and pass $focus"
    - "#Preview closure is @ViewBuilder in this SDK — no Void calls (insert, assignments) allowed; extract all setup into @MainActor factory function"
    - "Dual @FocusState domains (addItemFocus / renameItemFocus) — SwiftUI clears one when other gains focus (RESEARCH Pattern 2 / Pitfall 1)"
    - "Empty add-item submit: assign addItemFocus = nil (not the same id) to avoid SwiftUI re-focus loop (Pitfall 6)"
    - "FetchDescriptor<PackingItem>(predicate: #Predicate { $0.id == uuid }) for cross-category drag resolution (Pitfall 2)"
    - "@MainActor factory function pattern for preview container setup avoids @ViewBuilder Void expression errors"

key-files:
  created:
    - Travellify/Features/Packing/PackingRow.swift
  modified:
    - Travellify/Features/Packing/PackingListView.swift
    - Travellify/Features/Packing/CategoryHeader.swift
    - Travellify.xcodeproj/project.pbxproj

key-decisions:
  - "Preview for PackingRow uses @MainActor factory function + wrapper struct — #Preview closure is @ViewBuilder; Void calls from modelContext.insert() cause 'type () cannot conform to View'; FocusState.Binding has no .constant"
  - "CategoryHeader.onDropItem added in Task 3 but wired in PackingListView in Task 2 — committed together (cec327d) since PackingListView references the new parameter"
  - "Cross-category drop: same-category guard (item.category?.persistentModelID != category.persistentModelID) silently ignores intra-category drops per D32"
  - ".sensoryFeedback(.success, trigger: item.isChecked) applied per-row — symmetric on check and uncheck per D29"

patterns-established:
  - "For previews that require modelContext.insert() or other Void-returning setup: use @MainActor func makeXxxPreview() -> some View pattern"
  - "For views requiring @FocusState.Binding in previews: use a wrapper struct that owns @FocusState and passes $focus binding"

requirements-completed: [PACK-02, PACK-03, PACK-04, PACK-06]

# Metrics
duration: ~6min
completed: 2026-04-21
---

# Phase 3 Plan 03: Item Interactions Summary

**Swipe-to-check/delete, haptic feedback, inline add-item with rapid-multi-add, single-tap-to-rename, checked strikethrough styling, and cross-category drag-and-drop via PackingRow + extended PackingListView + CategoryHeader**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-20T21:56:47Z
- **Completed:** 2026-04-20T22:02:54Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Created `PackingRow.swift`: Text/TextField branch based on `isRenaming`; `.foregroundStyle(.secondary)` + `.strikethrough` on checked items; `.draggable(item.id.uuidString)` String payload; single tap calls `onTapToRename` (no tap-to-check per D26)
- Extended `PackingListView` with dual `@FocusState` (addItemFocus / renameItemFocus), binding helpers, six item mutation helpers (toggleChecked, deleteItem, insertItem, commitRename, fetchItem, moveItem), swipe actions (.leading green checkmark, .trailing destructive trash), `.sensoryFeedback(.success, trigger:)`, inline add-item HStack with rapid-multi-add focus loop
- Extended `CategoryHeader` with `onDropItem: (UUID) -> Void` and `.dropDestination(for: String.self)` that parses UUID string and calls onDropItem; intra-category drops silently ignored in PackingListView (D32)
- All item-CRUD save failures surface via the shared `errorMessage` alert from plan 02

## Task Commits

1. **Task 1: PackingRow** - `73191ee` (feat)
2. **Tasks 2+3: PackingListView item interactions + CategoryHeader drag-drop** - `cec327d` (feat)

## Files Created/Modified

- `Travellify/Features/Packing/PackingRow.swift` — New: Text/TextField branch, checked styling, draggable, @MainActor preview factory
- `Travellify/Features/Packing/PackingListView.swift` — Extended: dual @FocusState, 6 item mutation helpers, binding helpers, PackingRow + swipeActions + sensoryFeedback + inline add-item row replacing plain Text
- `Travellify/Features/Packing/CategoryHeader.swift` — Extended: onDropItem param + .dropDestination(for: String.self)
- `Travellify.xcodeproj/project.pbxproj` — Registered PackingRow.swift in PBXBuildFile, PBXFileReference, Packing group, Sources build phase

## Decisions Made

- `#Preview` closures in this SDK (iOS 26 / Xcode 26.2) are `@ViewBuilder` — `Void` expressions from `modelContext.insert()` and property assignments cause "type '()' cannot conform to 'View'" errors. Fix: extract all setup into `@MainActor func makeXxxPreview() -> some View` and have the `#Preview` body call only that function.
- `FocusState.Binding` has no `.constant` initializer — previews for views with `@FocusState.Binding` parameters require a wrapper struct that owns `@FocusState` and passes `$focus`.
- Tasks 2 and 3 committed together (`cec327d`) because PackingListView's `listContent` already calls `CategoryHeader(onDropItem:)` — splitting would leave the build broken between commits.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] #Preview @ViewBuilder rejects explicit `return` and Void expressions**
- **Found during:** Task 1 (PackingRow preview)
- **Issue:** `#Preview` macro closure is `@ViewBuilder` in iOS 26 SDK — `return List { ... }` causes "cannot use explicit 'return' statement"; `container.mainContext.insert()` causes "type '()' cannot conform to 'View'"
- **Fix:** Extracted all container setup into `@MainActor func makePackingRowPreview() -> some View`; `#Preview` body calls only `makePackingRowPreview()` — single view expression, no Void calls
- **Files modified:** `Travellify/Features/Packing/PackingRow.swift`
- **Commit:** `73191ee`

**2. [Rule 1 - Bug] FocusState.Binding has no .constant initializer**
- **Found during:** Task 1 (PackingRow preview)
- **Issue:** `renameItemFocus: .constant(nil)` fails — `FocusState<PersistentIdentifier?>.Binding` has no static `.constant`
- **Fix:** Created `PackingRowPreviewWrapper` struct owning `@FocusState private var focus` and passing `$focus` to PackingRow
- **Files modified:** `Travellify/Features/Packing/PackingRow.swift`
- **Commit:** `73191ee`

---

**Total deviations:** 2 auto-fixed (both Rule 1 — SDK-specific compile-time bugs in preview code only; production code unaffected)

## Drag-Drop Behavior Notes

- `.draggable(item.id.uuidString)` and `.dropDestination(for: String.self)` use `String` as the `Transferable` type — `PersistentIdentifier` and `UUID` are not `Transferable` in iOS 17+ (RESEARCH Pitfall 2)
- Cross-category drop resolves via `FetchDescriptor<PackingItem>(predicate: #Predicate { $0.id == uuid })` — fetches by the stable `PackingItem.id: UUID` field
- Same-category drops are silently ignored via guard in PackingListView's `onDropItem` closure (D32: intra-category reorder out of scope for v1)
- `isTargeted` closure left empty (no drop-highlight visual) — marked as optional polish for a future plan

## @FocusState Properties for Plan 04

The following state properties are targets for plan 04's test coverage:

| Property | Type | Domain | Behavior |
|----------|------|--------|----------|
| `addItemFocus` | `@FocusState PersistentIdentifier?` | Per category | Set to `category.persistentModelID` on tap; set to `nil` on empty submit; re-set to same ID after non-empty insert (rapid-multi-add) |
| `renameItemFocus` | `@FocusState PersistentIdentifier?` | Per item | Set to `item.persistentModelID` on tap; set to `nil` in `commitRename` |
| `newItemNames` | `@State [PersistentIdentifier: String]` | Per category | Keyed by `category.persistentModelID`; cleared to `""` after insert |
| `renameDrafts` | `@State [PersistentIdentifier: String]` | Per item | Seeded with `item.name` on tap; set to `nil` after commit |

## Known Stubs

None — all item interactions from the plan spec are fully implemented.

## Threat Flags

None — no new network endpoints, auth paths, file access, or schema changes introduced. All operations are local SwiftData writes on the main context.

## Self-Check: PASSED

Files exist and commits are in git log — verified below.
