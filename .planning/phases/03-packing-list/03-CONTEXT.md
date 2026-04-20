# Phase 3: Packing List - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Users build, manage, and check off a categorized packing list per trip. Delivers PACK-01 through PACK-07: user-created categories; items under a category with a name; rename/move/delete items; rename/delete categories; swipe-to-check-off (leading) and swipe-to-delete (trailing); progress indicator "X / Y packed" at top of the list plus per-category X/Y in each section header.

**In scope:** PackingCategory + PackingItem schema; PackingListView wired into TripDetail; inline add/edit/check flows; trip-level + category-level progress.

**Out of scope (deferred by roadmap):** Activities (Phase 4), notifications (Phase 5), Face-ID document lock (Phase 6), activity photos (Phase 7), trip templates / copy-from-past-trip lists (future milestone), cloud sync (v2).

</domain>

<decisions>
## Implementation Decisions

### Data Model

- **D19 — PackingCategory is its own @Model with inverse to Trip.**
  ```
  @Model final class PackingCategory {
      var id: UUID = UUID()
      var name: String
      var sortOrder: Int
      var trip: Trip?                                     // CloudKit-safe optional inverse
      @Relationship(deleteRule: .cascade, inverse: \PackingItem.category)
      var items: [PackingItem]? = []
  }
  ```
  Rationale: cleanest rename (one row update, no batch migration), empty categories supported, matches Trip→Destination pattern from Phase 1 D2. Raw `String` field on PackingItem was rejected because rename would require batch update. A fixed enum was rejected because PACK-05 requires user-created categories.

- **D20 — PackingItem schema (expands Phase 1 placeholder).**
  ```
  @Model final class PackingItem {
      var id: UUID = UUID()
      var name: String
      var isChecked: Bool = false
      var sortOrder: Int
      var category: PackingCategory?                      // CloudKit-safe optional inverse
  }
  ```
  Also requires adding `packingCategories: [PackingCategory]? = []` (cascade) on `Trip` as a new relationship. `trip: Trip?` on PackingItem is **not** needed — items reach the trip through their category.

- **D21 — Ordering is creation order via `sortOrder: Int` on both PackingCategory and PackingItem.**
  New rows append to the end (max existing sortOrder + 1). Alphabetical was rejected because rename would reshuffle the list mid-session; drag-reorder within a category is out of scope for v1 (see D29 scope carve-out). Opens the door to drag-reorder later without a schema migration.

- **D22 — Cascade on Trip delete.**
  `@Relationship(deleteRule: .cascade)` on Trip → `packingCategories` and PackingCategory → `items`. SwiftData handles cleanup automatically — consistent with Trip → Destination cascade from Phase 1. No manual cleanup in `TripListView`'s delete action is needed (unlike Phase 2, which had filesystem side-effects that required explicit folder removal per D16).

### Screen Layout

- **D23 — Single `List` with one `Section` per category.**
  All items visible on one screen, grouped by SwiftUI `Section` with the category name as header. Category detail drill-down was rejected because it hides other categories' progress and adds a tap per interaction. Matches Apple Reminders structure.

- **D24 — Trip-level progress is an inline header row at the top of the list; scrolls away with content.**
  First row above all sections. Shows `"<checked> / <total> packed"` label with a thin `ProgressView(value:)` bar beneath. No sticky/pinned variant (avoids custom scroll-hide logic that fights iOS large-title nav). Not placed in the nav bar subtitle because the bar is a primary signal for on-trip use and deserves visual weight.

- **D25 — Each section header shows per-category `X/Y` on the trailing side.**
  Example header: `"Toiletries"` on the left, `"5/7"` on the right. Computed from the category's items. Useful for scanning progress the night before departure.

### Check-Off & Destructive Gestures

- **D26 — Leading swipe (swipe right) toggles check/uncheck.**
  Uses `.swipeActions(edge: .leading, allowsFullSwipe: true)`. Full swipe commits the toggle without tap. Green tint, `checkmark` SF Symbol. Matches Mail "Mark as Read" idiom.

- **D27 — Trailing swipe (swipe left, role: `.destructive`) deletes the item.**
  `.swipeActions(edge: .trailing, allowsFullSwipe: true)` with red tint and `trash` SF Symbol. No confirmation dialog for individual items (matches SwiftUI List destructive-swipe convention; cost of a mistake is low — user retypes a name). Context menu delete is **not** added for items — keeping actions to swipe only avoids redundancy.

- **D28 — Checked state: strikethrough name + `.secondary` foreground; item stays in place.**
  `.strikethrough(item.isChecked)` on the name + `.foregroundStyle(item.isChecked ? .secondary : .primary)`. Items do **not** move to a "Packed" subsection on check — avoids rows jumping mid-interaction.

- **D29 — Haptic feedback on both check and uncheck.**
  `.sensoryFeedback(.success, trigger: item.isChecked)` — fires on any state change, symmetric behavior.

### Item CRUD

- **D30 — Add item: inline "Add item" row at the bottom of each category section.**
  Tappable row showing `"+ Add item"` placeholder. Tap → row becomes an autofocused `TextField`; submit (Return) inserts the item and keeps focus for rapid multi-add. Empty submit dismisses focus without inserting. Supports PACK-02's "add a packing item under a category with a name."

- **D31 — Edit item name: single tap anywhere on the row enters inline rename.**
  Row name becomes editable `TextField` with the current name selected. Submit saves, tap outside / Return dismisses. Does not conflict with check-off because check-off is **swipe only** per PACK-06 (no tap-to-check). Supports PACK-03 (rename portion).

- **D32 — Move item to another category: drag-and-drop across sections (cross-category only).**
  User long-presses a row and drags it onto another section's area → item's `category` is reassigned, `sortOrder` recomputed to append at destination. **Intra-category reordering is out of scope** — confirms D21's creation-order decision. Supports PACK-03 (move portion).

- **D33 — Delete item: trailing swipe (D27). No additional surface.**

### Category CRUD

- **D34 — Add category: "Add category" row at the very bottom of the list.**
  Tappable row below the last section. Tap → `.alert` with a `TextField` for the category name + Save/Cancel. Matches Phase 2's rename alert pattern (D15). New category appends to the end of `packingCategories` with the next `sortOrder`. Supports PACK-05 (add).

- **D35 — Rename / Delete category: long-press the section header → `.contextMenu`.**
  Header becomes long-pressable. Context menu items: `Rename` → `.alert` with TextField; `Delete` → `.confirmationDialog` (role: `.destructive`) with item-count copy. Consistent with Phase 2 D15's context-menu pattern for destructive actions. Supports PACK-05 (rename + delete).

- **D36 — Delete-category cascade: confirm, then cascade via D22's relationship rule.**
  `.confirmationDialog` copy: `"Delete '<categoryName>' and its N items? This cannot be undone."` (mirrors Phase 2 D15 tone). On confirm, `context.delete(category)` triggers cascade deletion of all items. "Block if non-empty" and "move items to Uncategorized" variants were rejected — cascade matches the chosen relationship model and user expectations.

### Progress Computation

- **D37 — Progress values are computed on the fly from `@Query`-fetched items.**
  No stored `checkedCount`/`totalCount` fields on Trip or PackingCategory. Cheap to compute for realistic list sizes (<200 items per trip). Avoids sync bugs between aggregate and source-of-truth. Consistent with Phase 1 D8 (no ViewModels/repositories — views derive state from `@Query`).

### Empty State

- **D38 — Empty packing list: single-view empty state with text + hint to "+ Add category" row.**
  When a trip has zero categories, the list shows a centered empty-state view (title + subtitle) and the "Add category" row remains at the bottom as the discoverable action. Matches Phase 2's text-only empty state pattern (D15). No inline CTA button that duplicates the "Add category" row.

### Navigation Integration

- **D39 — `AppDestination.packingList(Trip.persistentModelID)` routes from TripDetail's Packing card.**
  Extends the enum exactly as Phase 2 extended it for documents (D17). TripDetail's Packing card (placeholder from Phase 1 plan 01-05) gets wired: shows `"<checked>/<total> packed"` summary; tap pushes to `PackingListView`.

### Claude's Discretion

The following are not locked by discussion and fall to Claude / planner judgment, as long as other decisions are respected:

- Exact spacing, font sizes, and SF Symbol choices (e.g., `checkmark.circle.fill` vs `checkmark`) — follow iOS defaults.
- Internal file structure of the feature (e.g., whether to split `PackingListView` + `PackingRow` + `CategoryHeader` into separate files) — mirror Phase 2 `Travellify/Features/Documents/` organization.
- TextField autofocus implementation (`@FocusState` placement).
- Keyboard-return behavior on the add-item TextField (submit vs. insert-and-continue) — prefer insert-and-continue per D30.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level specs
- `.planning/PROJECT.md` — SwiftUI + SwiftData, iPhone-only, local-only v1, clean & native
- `.planning/REQUIREMENTS.md` §Packing — PACK-01 through PACK-07 locked for Phase 3
- `.planning/ROADMAP.md` §Phase 3 — success criteria
- `CLAUDE.md` — stack, CloudKit v2-readiness rules, testing framework

### Prior phase context (carry-forward decisions)
- `.planning/phases/01-foundation-trips/01-CONTEXT.md` — D1–D9: schema conventions (UUID ids, optional inverses, `VersionedSchema`), no ViewModels / no repositories, `AppDestination` navigation, dark theme
- `.planning/phases/02-documents/02-CONTEXT.md` — D10–D18: context-menu pattern for destructive actions (D15), cascade-on-trip-delete pattern (D16), `AppDestination` extension precedent (D17)
- `.planning/phases/02-documents/02-UI-SPEC.md` — visual conventions established in Phase 2 (row spacing, section headers, empty state, dark theme colors)

### Existing model to extend
- `Travellify/Models/PackingItem.swift` — current placeholder (`id` + `trip`) will be replaced by D20 schema and will require a SchemaV1 migration entry in the VersionedSchema

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Travellify/Models/SchemaV1.swift`** — `TravellifySchemaV1` VersionedSchema already exists; adding PackingCategory and updating PackingItem happens inside this schema (still v1, no migration plan needed if Phase 3 ships before any v1 data is in users' hands).
- **`Travellify/App/AppDestination.swift`** — extend with `.packingList(PersistentIdentifier)` exactly as Phase 2 added `.documentList` (D17 pattern).
- **`Travellify/Features/Trips/TripDetailView.swift`** — already contains placeholder cards from Phase 1 plan 01-05; Packing card gets wired like Documents card did in Phase 2 plan 02-02.
- **Empty-state convention** — `Travellify/Features/Trips/TripEmptyState.swift` + `Travellify/Features/Documents/EmptyDocumentsView.swift` — same text-only centered style to mirror for `EmptyPackingListView`.
- **`.alert` + TextField for rename** — established in Phase 2 plan 02-05 (document rename); reuse the same pattern for category rename/add.

### Established Patterns
- **No ViewModels** — views own `@Query` directly and mutate via `@Environment(\.modelContext)`. Continue this for PackingListView.
- **`@Relationship(deleteRule: .cascade, inverse: ...)`** — already used for Trip → Destination in Phase 1; same macro shape applies for Trip → PackingCategory → PackingItem.
- **CloudKit-safe rules from Phase 1 D2** — every property has a default or is optional; all inverses are optional; no `@Attribute(.unique)`. New PackingCategory / PackingItem must follow these rules so v2 CloudKit migration doesn't require a schema rewrite.
- **Feature folder organization** — `Travellify/Features/<Feature>/` with `<Feature>ListView.swift`, `<Feature>Row.swift`, etc. Create `Travellify/Features/Packing/`.

### Integration Points
- `TripDetailView.swift` Packing card → new `AppDestination.packingList` route → new `PackingListView`.
- `TravellifyApp.swift` `ModelContainer(for: ...)` schema array — add `PackingCategory.self` (PackingItem is already there as placeholder).
- `Shared/PreviewContainer.swift` — extend preview seeds with a sample trip that has 1-2 PackingCategory rows + a few PackingItems so the list renders in Xcode previews.

### Tests to Add (per Phase 2 plan 02-06 pattern)
- Schema migration safety / CloudKit-safety grep gate (no `@Attribute(.unique)`, all inverses optional).
- `PackingTests` — model invariants, cascade behavior on Trip delete and on PackingCategory delete.
- `PackingProgressTests` — trip-level and per-category counts for edge cases (empty category, all-checked, no items).

</code_context>

<specifics>
## Specific Ideas

- Matches Apple Reminders' visual/interaction idiom for the checked state (strikethrough + secondary color, item stays in place).
- Matches Apple Mail's leading-swipe-for-positive-action idiom.
- Matches Phase 2 D15's long-press context menu for destructive actions on **category headers** (but individual items use trailing swipe — this divergence is intentional because the packing list is a high-frequency interaction surface and swipe is faster than long-press).

</specifics>

<deferred>
## Deferred Ideas

- **Intra-category drag-to-reorder** — explicitly out of scope for v1 per D21/D32. Candidate for polish phase if users request it.
- **"Uncategorized" catch-all category** — rejected in D36 for v1. Could revisit if user testing shows category-delete friction.
- **Trip templates / copy-from-past-trip packing list** — already out of scope per PROJECT.md. Future milestone.
- **Stored aggregate counts** (per-trip, per-category) — rejected in D37. Revisit only if profiling shows `@Query` recomputation is a bottleneck on long lists.
- **Per-item notes / quantity / weight** — not in PACK-01..07. Out of scope for Phase 3.
- **Pin / flag actions on leading or trailing swipe** — no such actions in scope for v1.

</deferred>

---

*Phase: 03-packing-list*
*Context gathered: 2026-04-21*
