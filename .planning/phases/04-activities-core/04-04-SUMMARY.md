---
phase: 04-activities-core
plan: 04
subsystem: Routing + TripDetail wiring + Tests
tags: [swiftui, swiftdata, navigation, activities, tests, phase-complete]
requires:
  - AppDestination (01-03)
  - ActivityListView (04-03)
  - ActivityDateLabels.activitiesMessage (04-01)
  - TripDetailView scaffold (01-05)
provides:
  - AppDestination.activityList routing case
  - ContentView branch pushing ActivityListView(tripID:)
  - TripDetailView.activitiesCard — NavigationLink + smart-next-up message
  - NextUpcomingTests (7 cases locking D46 message rules)
affects:
  - Travellify.xcodeproj/project.pbxproj (NextUpcomingTests registered to test target)
  - Phase 4 is now complete end-to-end: create / view / edit / delete activities via UI
tech-stack:
  added: []
  patterns:
    - "NavigationLink(value: AppDestination.case) + .buttonStyle(.plain) card wrapping (packingCard precedent)"
    - "View-thin helper: all message computation stays in ActivityDateLabels; view holds no inline logic"
    - "Test-target pbxproj registration: 4 edit points (BuildFile + FileReference + PBXGroup + Sources)"
key-files:
  created:
    - TravellifyTests/NextUpcomingTests.swift
  modified:
    - Travellify/App/AppDestination.swift
    - Travellify/ContentView.swift
    - Travellify/Features/Trips/TripDetailView.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "D46/D47 honored verbatim: single new case, single switch branch, single card helper mirroring packingCard shape"
  - "Activities card message is read ONLY from ActivityDateLabels.activitiesMessage(for:) — TripDetailView has no inline computation (view-thin)"
  - "Phase 4 complete: all ACT-01/03/04/05 requirements observable in-app"
metrics:
  duration: ~10min
  completed: 2026-04-22
---

# Phase 4 Plan 4: Routing + TripDetail Wiring + NextUpcomingTests Summary

Close Phase 4. The Activities card on `TripDetailView` becomes a live `NavigationLink` pushing `ActivityListView`, and its message is now the smart "Next: …" string computed by `ActivityDateLabels.activitiesMessage(for:)`. Seven new `NextUpcomingTests` cases lock every branch of the D46 message contract. With this plan landed, a user can complete the full loop — browse trip → tap Activities card → see day-grouped list → add/edit/delete activities, with the trip detail card reflecting state.

## Tasks Completed

| Task | Name                                                                          | Commit  |
| ---- | ----------------------------------------------------------------------------- | ------- |
| 1    | Extend AppDestination + ContentView branch + TripDetailView Activities card   | 1c8b5de |
| 2    | NextUpcomingTests (7 cases) + pbxproj test-target registration                | becd8ea |

## Implementation Notes

### AppDestination

Single additive case appended: `case activityList(PersistentIdentifier)`. No other enum members touched; `Hashable` synthesis extends naturally.

### ContentView

One new switch branch inside the existing `.navigationDestination(for: AppDestination.self)` closure — mirrors the three Phase 2/3 branches exactly:

```swift
case .activityList(let id):
    ActivityListView(tripID: id)
```

### TripDetailView

Added a `@ViewBuilder private func activitiesCard(for trip: Trip)` next to the existing `packingCard(for:)`, and replaced the inline Activities `SectionCard` placeholder at lines 38–43 with `activitiesCard(for: trip)`. The helper's shape matches the `packingCard` precedent exactly: `NavigationLink(value: AppDestination.activityList(trip.persistentModelID)) { SectionCard(...) }.buttonStyle(.plain)`.

The card's message comes exclusively from `ActivityDateLabels.activitiesMessage(for: trip)` — the view owns no message-derivation logic. `minHeight: 220` preserves the card's visual footprint from the placeholder era.

Reactivity: `trip.activities` updates propagate through the existing `modelContext.model(for: tripID) as? Trip` resolution already in place; no `@Query` or `@Bindable` was added to `TripDetailView`.

### NextUpcomingTests

Seven cases seeded against a real in-memory `ModelContainer` with all 6 SchemaV1 types:

1. `emptyTripReturnsNoActivitiesYet` — `msg == "No activities yet"`
2. `oneUpcomingTodayProducesTodayNextMessage` — prefix `"Next: "`, contains title, contains `" · Today at "`
3. `oneUpcomingTomorrowProducesTomorrowNextMessage` — contains title, contains `" · Tomorrow at "`
4. `oneUpcomingFiveDaysOutUsesDistantRelative` — no Today/Tomorrow, contains `" at "`
5. `allPastActivitiesProduceCountMessage` — exact `"1 activity"` / `"3 activities"`
6. `equalStartAtTiebreakByCreatedAtChoosesEarlierCreated` — later-created title excluded, earlier-created included
7. `mixOfPastAndFutureChoosesFutureAsNext` — future title present, past title absent

All cases inject `now` explicitly; Task 2's Rule-1 fix from Plan 04-03 (making `ActivityDateLabels` honor injected `now`/`calendar`) pays off here — assertions for Today/Tomorrow pass without flakiness even when the test runner's system clock drifts during the run.

### pbxproj

Four-point registration following the `ActivityTests.swift` precedent from 04-01 and `ActivityGroupingTests.swift` from 04-03:

1. `PBXBuildFile` UUID `AD0404010203040506070801`
2. `PBXFileReference` UUID `AD0404010203040506070802`
3. Added to the `TravellifyTests` PBXGroup children
4. Added to the test-target `PBXSourcesBuildPhase` files list (UUID `2254D2B3CA9043AFBA55EAD9`)

Test-target only — not the app target. Clustered UUID prefix `AD0404…` leaves room for a hypothetical follow-up plan 04-05 if ever needed, though Phase 4 is closing here.

## Verification

### Build + tests

- `xcodebuild -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e' build` → **BUILD SUCCEEDED**
- `xcodebuild test -only-testing:TravellifyTests/NextUpcomingTests` → **7 / 7 green**
- `xcodebuild test` (full target) → ** TEST SUCCEEDED **, no regressions across SchemaTests / TripTests / PartitionTests / DocumentTests / ImportTests / ViewerTests / FileStorageTests / PackingTests / PackingProgressTests / ActivityTests / ActivityGroupingTests / DayLabelTests / SmokeTests / NextUpcomingTests

### Grep gates

- `grep -c "case activityList" Travellify/App/AppDestination.swift` → **1**
- `grep -c "case .activityList" Travellify/ContentView.swift` → **1**
- `grep -c "ActivityListView(tripID:" Travellify/ContentView.swift` → **1**
- `grep -c "activitiesCard(for:" Travellify/Features/Trips/TripDetailView.swift` → **2** (helper def + call site)
- `grep -n "AppDestination.activityList" Travellify/Features/Trips/TripDetailView.swift` → hit
- `grep -n "ActivityDateLabels.activitiesMessage" Travellify/Features/Trips/TripDetailView.swift` → hit
- `grep -c "Your itinerary will appear here" Travellify/Features/Trips/TripDetailView.swift` → **0** (placeholder removed)
- `grep -c "NextUpcomingTests.swift" Travellify.xcodeproj/project.pbxproj` → **4** (BuildFile + FileReference + PBXGroup + Sources)
- Anti-pattern check: `grep -n "let activities =" Travellify/Features/Trips/TripDetailView.swift` → empty (no inline computation)

### Manual smoke checklist

Physical simulator interaction not performed in this headless executor pass, but the Wave 3 smoke path and this plan's plumbing are structurally intact:

- [x] AppDestination.activityList compiles and is hashable (xcodebuild verified)
- [x] ContentView handles all four destination cases (build exhaustiveness enforced)
- [x] Activities card calls `ActivityDateLabels.activitiesMessage(for: trip)` (grep verified)
- [x] Activities card wraps `NavigationLink(value: .activityList(...))` with `.buttonStyle(.plain)` (grep verified)
- [ ] `Launch app → open trip → tap Activities → list appears` — pending user manual smoke run; all code paths present
- [ ] `Add activity → card re-computes to "Next: <title> · Today at <time>"` — pending user manual smoke run

### Locale / time-format note

`ActivityDateLabels.shortTimeFormatter` uses `DateFormatter.timeStyle = .short` with `Locale.current`. On a US-locale simulator, expect `"Today at 2:00 PM"`; on fr_FR expect `"Today at 14:00"`. Tests assert the separator `" · Today at "` and `" at "` — locale-tolerant.

## Deviations from Plan

None. Plan executed exactly as written. No Rule 1/2/3 fixes triggered.

## Phase 4 Acceptance

With this plan complete, the Phase 4 ROADMAP success criteria are all observable:

1. **Create:** User can create an activity with title, date & time, optional location, optional notes (Wave 2 `ActivityEditSheet`).
2. **View grouped:** User can see all activities in a trip grouped by date in chronological order, with within-day time sort (Wave 3 `ActivityListView` — `Dictionary(grouping:)` by startOfDay + multi-key `SortDescriptor`).
3. **Edit:** User can edit any field of an existing activity (Wave 3 row tap → Wave 2 sheet in edit mode).
4. **Delete:** User can delete an activity (Wave 3 trailing full-swipe destructive action).

Plus the Phase 4 nicety:
- **Smart next-up trip-detail card:** `ActivityDateLabels.activitiesMessage(for:)` renders empty / "Next: <title> · <relative> at <time>" / past-count via this plan's wire-up.

Requirement `ACT-03` (the "View all activities grouped by date" requirement this plan closes) is now fully delivered. Combined with ACT-01 (04-02), ACT-04 (04-02 edit flow), and ACT-05 (04-03 swipe-delete) Phase 4 is complete.

Ready signal for Phase 4 verification: `/gsd-verify-phase 4`.

## Self-Check: PASSED

- FOUND: Travellify/App/AppDestination.swift (activityList case)
- FOUND: Travellify/ContentView.swift (activityList branch)
- FOUND: Travellify/Features/Trips/TripDetailView.swift (activitiesCard helper)
- FOUND: TravellifyTests/NextUpcomingTests.swift
- FOUND commit: 1c8b5de
- FOUND commit: becd8ea
- Build: BUILD SUCCEEDED / Tests: TEST SUCCEEDED on iPhone 16e
