# Phase 4 — Activities (Core) — CONTEXT

**Goal:** Users can create, view, edit, and delete a day-by-day itinerary of activities within a trip.
**Requirements:** ACT-01, ACT-03, ACT-04, ACT-05 (ACT-02/06 → Phase 7 photos; ACT-07/08/09 → Phase 5 notifications).
**Depends on:** Phase 3 (complete).

## Inherited (locked by prior phases — do not re-decide)

- **Stack:** SwiftUI + SwiftData, iOS 17+, Swift 6, Swift Testing.
- **SwiftData rules (CloudKit-safe):** UUID defaults, optional inverses, no `@Attribute(.unique)`, no `@Attribute(.externalStorage)` for binary assets.
- **Routing:** `AppDestination` enum in `Travellify/App/AppDestination.swift` — pattern: `.packingList(PersistentIdentifier)`.
- **Edit-sheet pattern:** Single sheet for add + edit (see `TripEditSheet`, `DocumentEditSheet`). Init takes optional model; nil = add mode.
- **List pattern:** `@Query` with trip-scoped `#Predicate`; sort via in-memory computed arrays when grouping is needed.
- **Cascade:** `Trip.activities` already declared with `@Relationship(deleteRule: .cascade, inverse: \Activity.trip)` (Trip.swift:24). Deleting the trip deletes its activities.
- **Styling:** Native iOS — SF Symbols, system colors, `.insetGrouped` list style.

## Decisions

### D40 — Activity model fields

Extend the existing placeholder `TravellifySchemaV1.Activity`:

```swift
@Model
final class Activity {
    var id: UUID = UUID()
    var trip: Trip?                // CloudKit-safe optional inverse
    var title: String = ""         // required at UI layer (non-empty)
    var startAt: Date = Date()     // date + time combined
    var location: String?          // plain text, optional
    var notes: String?             // optional free-form
    var createdAt: Date = Date()   // for deterministic tiebreak on equal startAt
    init() {}
}
```

- **Single `startAt: Date`** — not split date/time; not dual start/end. Matches ACT-01 ("date & time"). End time / duration is deferred (not requested).
- **No `isAllDay`** — time always required. Simpler model, deterministic sort.
- **`location: String?`** — plain text. Apple Maps deep link is POLISH-03 (deferred).
- **`notes: String?`** — free-form, multi-line `TextField(axis: .vertical)`.
- **`createdAt`** — used only as a tiebreak when two activities share the same `startAt`.

### D41 — Trip-range validation: soft-warn

- Activity dates are **not clamped** to `[trip.startDate, trip.endDate]`.
- Show an inline warning row in the edit sheet when `startAt` falls outside the trip range (e.g. "Outside trip dates"), but Save remains enabled.
- Rationale: users legitimately plan pre-trip (airport arrival) and post-trip (return flight) events; hard-clamp blocks real cases.

### D42 — Day grouping + sort

- **Group by day** using `Calendar.current.startOfDay(for: activity.startAt)` as the section key.
- **Skip empty gap days.** Only days that contain ≥1 activity render as a section. (No filler.)
- **Section header format — relative + date:**
  - Today → `"Today · Apr 22"`
  - Tomorrow → `"Tomorrow · Apr 23"`
  - Yesterday → `"Yesterday · Apr 21"`
  - Else → weekday short + date, e.g. `"Mon, Apr 22"`
  - Use `DateFormatter` with locale-aware short weekday + abbreviated month-day.
- **Within-day sort:** strict `startAt` ascending; tiebreak `createdAt` ascending. No `sortOrder` field. No manual reorder.
- **Cross-section reorder:** N/A — date changes move an activity to a different day automatically.

### D43 — Edit sheet (create + edit)

- Single `ActivityEditSheet` view, init signature `(activity: Activity?, trip: Trip)`.
  - `nil` → create mode; inserts new `Activity`, sets `.trip = trip`, assigns `startAt` per D44 default.
  - non-nil → edit mode; binds fields in place.
- **Fields (in order):**
  1. Title — `TextField`, required, Save disabled when trimmed empty.
  2. Date & time — `DatePicker(selection:, displayedComponents: [.date, .hourAndMinute])` with `.datePickerStyle(.compact)` (single row).
  3. Location — optional `TextField`.
  4. Notes — optional `TextField("Notes", text:, axis: .vertical)`, line limit 3–8.
  5. Inline trip-range warning (D41) appears between Date row and Save when applicable.
- **Save button** in toolbar; **Cancel** dismisses without mutation. Follows `TripEditSheet` structure.
- **No delete button inside the sheet** — deletion is via swipe on the list (D45).

### D44 — Default `startAt` when creating

Priority order:
1. If `trip.startDate` is in the future → default to `trip.startDate` at the next top-of-hour (09:00 if trip start is a date with no time component).
2. Else if today is within `[trip.startDate, trip.endDate]` → today at the next top-of-hour (rounded forward; `Date().nextHour`).
3. Else (trip fully in the past) → `Date()` at the next top-of-hour.

### D45 — Delete interaction

- **Swipe-to-delete**, trailing edge, no confirmation dialog.
- Matches Packing-item delete (fast, cheap to recreate).
- Deletes the activity via `modelContext.delete(activity)` + `save()`.

### D46 — Trip-detail Activities card: smart next-up

Card at `TripDetailView.swift` (line ~108–116; placeholder `SectionCard(title: "Activities", systemImage: "calendar", message: "Your itinerary will appear here.")`).

**Replace placeholder message with computed `activitiesMessage(for: trip)`:**

- If `activities` is empty → `"No activities yet"`.
- If there is a next activity with `startAt >= now` → `"Next: \(title) · \(relativeDayShort) at \(timeShort)"`
  - Example: `"Next: Louvre tour · Today at 2pm"` or `"Next: Seine cruise · Apr 23 at 10am"`.
  - `relativeDayShort`: Today / Tomorrow / otherwise short date.
  - `timeShort`: `DateFormatter` short time, lowercase am/pm.
- Else (all activities are in the past) → `"\(count) activit\(count == 1 ? "y" : "ies")"`.

Wrap the card in `NavigationLink(value: AppDestination.activityList(trip.persistentModelID))`.

### D47 — Navigation route

- Add case: `case activityList(PersistentIdentifier)` to `AppDestination` (AppDestination.swift:4).
- Add corresponding `navigationDestination` branch in `ContentView.swift` that resolves the trip via `modelContext.model(for:)` and pushes `ActivityListView(tripID: …)`.
- `ActivityListView` initializer mirrors `PackingListView`: `init(tripID: PersistentIdentifier)` with a trip-scoped `#Predicate`.

### D48 — Empty state

When the list has no activities:
- Centered `ContentUnavailableView`-style layout (mirrors `EmptyPackingListView`).
- SF Symbol: `"calendar.badge.plus"`.
- Title: `"No activities yet"`.
- Message: `"Tap + in the top right to add your first activity."`.
- Include `.accessibilityElement(children: .combine)` + `.accessibilityLabel`.

### D49 — Toolbar + add flow

- Navigation title `"Activities"` (`.large` display mode).
- Toolbar trailing `+` button (mirrors Packing + Trips pattern) that presents `ActivityEditSheet(activity: nil, trip: trip)` via `.sheet(isPresented:)`.
- `.scrollDismissesKeyboard(.immediately)`.

## Test coverage (for gsd-planner to include)

- `ActivityTests`: model defaults, cascade via trip delete, mutation persistence.
- `ActivityGroupingTests`: groupBy-day produces correct sections; within-day time sort; tiebreak by `createdAt`; skip-empty-days behavior.
- `DayLabelTests`: Today / Tomorrow / Yesterday / distant-date labels against a fixed `Calendar` + locale.
- `SchemaV1` + CloudKit-safety grep gate: ensure `Activity` has UUID default, optional inverse, no `.unique`, no `.externalStorage`.
- `PartitionTests` equivalent for "next upcoming" on TripDetail card.

## Canonical refs

- `/Users/a.satybaldin/Documents/projects/travellify/.planning/PROJECT.md`
- `/Users/a.satybaldin/Documents/projects/travellify/.planning/REQUIREMENTS.md` (ACT-01/03/04/05)
- `/Users/a.satybaldin/Documents/projects/travellify/.planning/ROADMAP.md` (Phase 4 block)
- `/Users/a.satybaldin/Documents/projects/travellify/.planning/phases/01-foundation-trips/01-CONTEXT.md` (schema, routing, edit-sheet pattern)
- `/Users/a.satybaldin/Documents/projects/travellify/.planning/phases/02-documents/02-CONTEXT.md` (edit-sheet + cascade precedents)
- `/Users/a.satybaldin/Documents/projects/travellify/.planning/phases/03-packing-list/` (most recent UX patterns: toolbar +, swipe-delete, empty state)
- `Travellify/Models/Trip.swift` (activities relationship already declared)
- `Travellify/Models/Activity.swift` (placeholder to extend)
- `Travellify/Models/SchemaV1.swift` (VersionedSchema registration)
- `Travellify/App/AppDestination.swift` (add `.activityList`)
- `Travellify/ContentView.swift` (add navigationDestination branch)
- `Travellify/Features/Trips/TripDetailView.swift` (wire Activities card, line ~108)
- `Travellify/Features/Packing/PackingListView.swift` (pattern reference for trip-scoped Query + toolbar +)
- `Travellify/Features/Trips/TripEditSheet.swift` (sheet pattern reference)

## Deferred (out of Phase 4)

- **ACT-02 / ACT-06** — Activity photos → Phase 7.
- **ACT-07 / ACT-08 / ACT-09** — Reminders / notifications → Phase 5.
- **POLISH-01** — "Today" filter view.
- **POLISH-03** — Apple Maps deep link on location tap.
- **POLISH-04** — EventKit calendar export.
- Manual reorder within a day (rejected; strict time-sort).
- Duration / end-time field (rejected; `startAt` only for v1).
- All-day activity toggle (rejected).

## Open questions for gsd-phase-researcher

- Best-practice date formatter caching pattern for a per-row label (avoid allocating in body).
- `@Query` sort-descriptor vs in-memory sort when grouping by day — which is more idiomatic with SwiftData iOS 17?
- SwiftUI pattern for inline trip-range warning in `Form` (row vs footer).
- Any Xcode 26 SourceKit quirks with `DatePicker(.compact)` in `Form`.

## Next steps

Run `/gsd-plan-phase 4` to produce plans. The planner should break work into:
1. Schema extension (`Activity` fields + SchemaV1 update + project.pbxproj registration remains unchanged since already registered).
2. `ActivityEditSheet` (add + edit).
3. `ActivityListView` (grouped list, toolbar +, swipe-delete).
4. Routing (`AppDestination.activityList` + ContentView branch + TripDetailView wiring + smart-next-up message).
5. Tests.
