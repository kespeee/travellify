---
phase: 04-activities-core
plan: 03
subsystem: Features/Activities (list surface)
tags: [swiftui, swiftdata, list, grouping, activities, tests]
requires:
  - TravellifySchemaV1.Activity (04-01)
  - ActivityDateLabels.dayLabel / shortRelativeDay / timeLabel (04-01)
  - ActivityEditSheet (04-02)
  - Trip model
provides:
  - ActivityListView (SwiftUI screen) — init(tripID: PersistentIdentifier)
  - ActivityRow, ActivityDayHeader, EmptyActivitiesView (Wave 2 Task 1)
  - ActivityGroupingTests + DayLabelTests (deterministic test coverage)
affects:
  - Travellify.xcodeproj/project.pbxproj (4 files registered — 1 in app target, 2 in test target, plus Task 1's 3 app-target files)
  - Travellify/Shared/ActivityDateLabels.swift (Rule 1 bug fix — see Deviations)
tech-stack:
  added: []
  patterns:
    - "Trip-scoped @Query with multi-key SortDescriptor [startAt asc, createdAt asc] (D42 / RESEARCH Pattern 1)"
    - "Dictionary(grouping:) by Calendar.current.startOfDay + keys.sorted() (RESEARCH Pattern 2 / D42)"
    - "Group { if empty { EmptyView } else { listContent } } empty-state gating (DocumentListView precedent)"
    - "Dual-sheet add/edit (.sheet(isPresented:) + .sheet(item:))"
    - "Full-swipe destructive delete without confirmation (D45)"
    - "Fixed UTC gregorian + en_US_POSIX calendar injection for deterministic date-label tests"
key-files:
  created:
    - Travellify/Features/Activities/ActivityRow.swift
    - Travellify/Features/Activities/ActivityDayHeader.swift
    - Travellify/Features/Activities/EmptyActivitiesView.swift
    - Travellify/Features/Activities/ActivityListView.swift
    - TravellifyTests/ActivityGroupingTests.swift
    - TravellifyTests/DayLabelTests.swift
  modified:
    - Travellify.xcodeproj/project.pbxproj
    - Travellify/Shared/ActivityDateLabels.swift
decisions:
  - "D42 honored verbatim: single multi-key @Query + client-side Dictionary(grouping:) by startOfDay; no per-day @Query. Empty gap days collapse automatically."
  - "D45 full-swipe destructive delete without confirmation: one-tap destructive action is acceptable because delete is non-archiving and scope is small; matches existing Documents list pattern."
  - "D48 empty state uses Group-gated full-screen EmptyActivitiesView (DocumentListView precedent), not a single List row — preserves proper vertical centering."
  - "Used shortRelativeDay in activitiesMessage and standalone dayLabel in section headers — two different tightnesses as specified."
metrics:
  duration: ~45min
  completed: 2026-04-21
---

# Phase 4 Plan 3: ActivityListView + Grouping + Tests Summary

Ship `ActivityListView` — the day-grouped chronological list screen for a trip's activities — plus its three supporting views (`ActivityRow`, `ActivityDayHeader`, `EmptyActivitiesView`) and deterministic Swift Testing coverage for grouping logic and relative-day label rules.

## Tasks Completed

| Task | Name                                                                         | Commit  |
| ---- | ---------------------------------------------------------------------------- | ------- |
| 1    | ActivityRow + ActivityDayHeader + EmptyActivitiesView                        | a3f93a7 |
| 2    | ActivityListView + ActivityGroupingTests + DayLabelTests (+ Rule 1 bug fix)  | 72c1de9 |

## Implementation Notes

### ActivityListView

`init(tripID: PersistentIdentifier)` mirrors `PackingListView`. The `@Query` is built inside `init` with a `#Predicate<Activity>` filtering on `activity.trip?.persistentModelID == tripID` and a multi-key `SortDescriptor` array `[SortDescriptor(\Activity.startAt), SortDescriptor(\Activity.createdAt)]`.

The trip is resolved lazily via `modelContext.model(for: tripID) as? Trip`; the toolbar `+` is disabled when `trip == nil` (edge case where the route references a deleted trip ID).

Grouping uses the canonical RESEARCH Pattern 2:

```swift
private var groupedByDay: [Date: [Activity]] {
    Dictionary(grouping: activities) { activity in
        Calendar.current.startOfDay(for: activity.startAt)
    }
}
private var sortedDays: [Date] { groupedByDay.keys.sorted() }
```

Empty days collapse naturally because `Dictionary(grouping:)` emits only keys that had at least one value.

### Row + header + empty state

- `ActivityRow`: HStack with a 72pt-wide leading time column (monospaced-digit secondary) + center title + optional secondary location line. No trailing chevron (tap is the primary affordance).
- `ActivityDayHeader`: HStack with `.headline` primary day label + optional activity count `.subheadline` secondary trailing.
- `EmptyActivitiesView`: VStack mirroring `EmptyPackingListView` — `calendar.badge.plus` 56pt secondary, "No activities yet" `.title2.weight(.semibold)`, and CTA body `.subheadline` secondary.

### Sheet + delete wiring

Dual-sheet pattern (DocumentListView precedent) wires the toolbar `+` via `.sheet(isPresented: $showAddSheet)` and row tap via `.sheet(item: $pendingEditActivity)`. Both present `ActivityEditSheet(activity:trip:)` from 04-02.

Delete uses `.swipeActions(edge: .trailing, allowsFullSwipe: true)` destructive role — calls `modelContext.delete` + shared `save(_:)` with errorMessage alert on failure. No confirmation dialog (D45).

### Tests

**ActivityGroupingTests** (5 cases) seeds a real in-memory `ModelContainer` with trip-scoped activities, fetches via the same multi-key `SortDescriptor`, and mirrors the view's grouping closure in a UTC-calendar helper. Cases: empty input, three non-contiguous days, within-day ascending order, createdAt tiebreak on equal startAt, day-boundary placement.

**DayLabelTests** (5 cases) fixes `now = 2026-04-22T12:00:00Z` and a UTC gregorian + `en_US_POSIX` calendar, then asserts Today/Tomorrow/Yesterday prefixes, the distant-date `EEE, MMM d` shape (comma presence as cheap proxy), and `shortRelativeDay` rules.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `ActivityDateLabels.dayLabel` / `shortRelativeDay` ignored injected `now`**

- **Found during:** Task 2 — `DayLabelTests` run (4 of 5 failed; only `distantDateUsesWeekdayDateForm` passed)
- **Issue:** The Wave 1 (04-01) implementation accepted `now: Date = Date()` and `calendar: Calendar = .current` parameters but its body called `calendar.isDateInToday(day)` / `isDateInTomorrow` / `isDateInYesterday`, which compare against the real system `Date()` — completely bypassing the injected `now`. Under test, `fixedNow = 2026-04-22T12Z` but the real system date is 2026-04-21, so every relative label was mis-classified.
- **Additional issue:** `dayLabel` used cached module-level `DateFormatter`s pinned to `.current` locale/timezone, making output non-deterministic under calendar injection.
- **Fix:** Replaced `isDateInToday`/`isDateInTomorrow`/`isDateInYesterday` with an explicit day diff: `calendar.dateComponents([.day], from: nowStart, to: dayStart).day`. Added a private `localizedString(from:template:calendar:)` helper that builds a per-call `DateFormatter` pinned to the injected calendar's `timeZone` and `locale`, so month/weekday strings render deterministically under test injection.
- **Files modified:** `Travellify/Shared/ActivityDateLabels.swift`
- **Commit:** `72c1de9`
- **Why Rule 1 (bug, not architectural):** The public API signature is unchanged; the fix makes the function honor the contract its signature already advertised. No callers needed updating.

**2. [Test fix] Type mismatch in `ActivityGroupingTests.withinDaySortIsAscendingByStartAt`**

- **Found during:** Task 2 — first test build
- **Issue:** `#expect(extracted == [1 * 3600, 3 * 3600, 5 * 3600])` failed because `extracted` is `[TimeInterval]` (from `startAt.timeIntervalSince(base)`) and `[Int]` literals don't unify with `[TimeInterval]` through `==`.
- **Fix:** Wrapped literals in `TimeInterval(...)` explicitly.
- **Files modified:** `TravellifyTests/ActivityGroupingTests.swift`
- **Commit:** `72c1de9`

## Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Travellify.xcodeproj -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e' test` → **`** TEST SUCCEEDED **`**
- All 5 new `ActivityGroupingTests` cases green.
- All 5 new `DayLabelTests` cases green.
- No regressions across pre-existing suites (SchemaTests, TripTests, DocumentTests, PackingTests, PackingProgressTests, ActivityTests, ImportTests, FileStorageTests, SmokeTests, ViewerTests, PartitionTests).

## Self-Check: PASSED

- FOUND: Travellify/Features/Activities/ActivityRow.swift
- FOUND: Travellify/Features/Activities/ActivityDayHeader.swift
- FOUND: Travellify/Features/Activities/EmptyActivitiesView.swift
- FOUND: Travellify/Features/Activities/ActivityListView.swift
- FOUND: TravellifyTests/ActivityGroupingTests.swift
- FOUND: TravellifyTests/DayLabelTests.swift
- FOUND commit: a3f93a7
- FOUND commit: 72c1de9
