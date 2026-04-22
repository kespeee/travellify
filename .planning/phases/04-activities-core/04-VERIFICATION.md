---
phase: 04-activities-core
verified: 2026-04-21T00:00:00Z
human_verified: 2026-04-21T00:00:00Z
status: pass
score: 4/4 must-haves verified (programmatic + manual simulator confirmation)
overrides_applied: 0
human_verification:
  - test: "Create activity end-to-end on simulator"
    expected: "Tap + in ActivityListView toolbar, ActivityEditSheet appears with pre-filled startAt, enter title 'Louvre tour', adjust date/time via compact DatePicker, enter location and notes, tap Add. Sheet dismisses. New row appears in the correct day section, sorted by time."
    why_human: "Requires running iOS simulator to drive SwiftUI gestures, DatePicker wheel, keyboard, and confirm visual layout. Cannot be asserted via unit tests."
  - test: "Edit existing activity"
    expected: "Tap an existing row in ActivityListView. ActivityEditSheet opens in edit mode with current values loaded. Change every field (title, date/time, location, notes). Tap Save. Sheet dismisses; row reflects new values, and if date changed, moves to the correct day section."
    why_human: "onTapGesture-driven sheet presentation and field round-trip require simulator interaction to confirm."
  - test: "Delete activity via swipe"
    expected: "Swipe a row left; Delete button appears (red, trash icon). Tap (or full-swipe) to delete. Row disappears; if it was the last activity for a day, the section header disappears too; if last overall, EmptyActivitiesView replaces the list."
    why_human: "Swipe gesture and full-swipe delete behavior must be exercised on a simulator/device."
  - test: "Out-of-range soft warning"
    expected: "In ActivityEditSheet, pick a date outside trip start/end. Warning row 'Outside trip dates' with orange triangle appears under the DatePicker. Save remains enabled (soft warn, not hard block)."
    why_human: "Visual warning surface; requires running UI."
  - test: "TripDetail Activities card smart next-up"
    expected: "On a trip with no activities: card shows 'No activities yet'. With an upcoming activity today: 'Next: <title> · Today at <time>'. With only past activities: '<N> activities'. Tapping the card navigates to ActivityListView."
    why_human: "NavigationLink wiring and live SwiftData-driven card message in the full navigation stack need device observation."
---

# Phase 4: Activities (Core) Verification Report

**Phase Goal:** Users can create, view, edit, and delete a day-by-day itinerary of activities within a trip.
**Verified:** 2026-04-21
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can create an activity with title, date/time, optional location, optional notes | VERIFIED (needs human UI confirm) | `ActivityEditSheet.swift:44-81` Form with title TextField, DatePicker (date+hourAndMinute), location TextField, notes TextField (axis: vertical); `save()` at L118-144 inserts new Activity, trims optionals to nil; wired via `ActivityListView.swift:58-71` `+` toolbar and `showAddSheet` sheet; test `ActivityTests.insertActivityRoundTrip` confirms all four fields persist. |
| 2 | User sees activities grouped by date chronologically, sorted by time within each day | VERIFIED | `ActivityListView.swift:33-41` groups by `Calendar.current.startOfDay(for: startAt)`, `sortedDays` ascending; `@Query` at L16-25 sorts by `startAt` then `createdAt`; `ActivityDayHeader.swift` renders `dayLabel` (Today/Tomorrow/Yesterday/"EEE, MMM d"); tests `ActivityGroupingTests.threeNonContiguousDaysProduceExactlyThreeSections`, `withinDaySortIsAscendingByStartAt`, `dayBoundaryPlacesActivitiesInCorrectSections`, `createdAtTiebreakOrdersEqualStartAt` plus `DayLabelTests` (5 cases) all pass. |
| 3 | User can edit any field of an existing activity | VERIFIED (needs human UI confirm) | `ActivityListView.swift:100` `onTapGesture { pendingEditActivity = activity }`; `L72-76` `.sheet(item:)` presents `ActivityEditSheet(activity: activity, trip:)`; `ActivityEditSheet.swift:103-114` `loadInitialValuesIfNeeded` prefills all 4 fields; `save()` at L124-128 updates all 4 fields + optional nil-clearing logic; test `ActivityTests.mutationPersistsAfterSave` and `optionalFieldsCanBeClearedToNil` confirm persistence of updates. |
| 4 | User can delete an activity | VERIFIED (needs human UI confirm) | `ActivityListView.swift:101-107` `.swipeActions(edge: .trailing, allowsFullSwipe: true)` Delete button invokes `delete(activity)` → `modelContext.delete` + `save` with error alert on failure (L120-128); trip-cascade confirmed by `ActivityTests.deleteTripCascadesToActivities`. |

**Score:** 4/4 truths verified programmatically. Truths 1, 3, 4 require human confirmation of gesture-driven SwiftUI UI (DatePicker, sheet presentation, swipe). See human_verification.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Travellify/Models/Activity.swift` | D40 fields: title, startAt, location, notes, createdAt; optional trip inverse; CloudKit-safe | VERIFIED | 20 lines; all five stored properties with defaults for lightweight migration; no `@Attribute(.unique)` or `.externalStorage`; asserted by `SchemaTests.activitySchemaIsCloudKitSafe`. |
| `Travellify/Shared/ActivityDateLabels.swift` | dayLabel, shortRelativeDay, timeLabel, defaultStartAt, activitiesMessage | VERIFIED | 138 lines; cached formatters; `DayLabelTests` (5) + `NextUpcomingTests` (7) cover all paths. |
| `Travellify/Features/Activities/ActivityEditSheet.swift` | Create + edit, compact DatePicker, soft out-of-range warning, title-required Save | VERIFIED | 188 lines; `isValid` gate at L22; `isOutsideTripRange` at L24-30 warning row L58-68; `confirmButtonTitle` toggles Add/Save (L36-38); defaultStartAt via D44 on create (L112). |
| `Travellify/Features/Activities/ActivityListView.swift` | Grouped @Query list + swipe delete + sheets | VERIFIED | 183 lines; filter predicate by `trip.persistentModelID` (L16-24); day grouping + sorted sections (L33-41); `+` toolbar (L57-65); edit tap (L100) and swipe delete (L101-107); error alert (L77-88); shows `EmptyActivitiesView` when empty (L47-48). |
| `Travellify/Features/Activities/ActivityRow.swift` | time + title + optional location | VERIFIED | 60 lines; monospaced time label, 2-line title, 1-line location; accessibility combined. |
| `Travellify/Features/Activities/ActivityDayHeader.swift` | Day label + count | VERIFIED | 37 lines; uses `ActivityDateLabels.dayLabel`; accessible label combining both. |
| `Travellify/Features/Activities/EmptyActivitiesView.swift` | Empty state with guidance | VERIFIED | 28 lines; SF Symbol + title + subtitle + accessibility. |
| `Travellify/App/AppDestination.swift` | `.activityList(PersistentIdentifier)` case | VERIFIED | Line 8 present. |
| `Travellify/ContentView.swift` | Route `.activityList` → `ActivityListView` | VERIFIED | Lines 18-19 branch routes to `ActivityListView(tripID:)`. |
| `Travellify/Features/Trips/TripDetailView.swift` | Activities card with smart next-up + NavigationLink | VERIFIED | `activitiesCard` at L104-114 uses `ActivityDateLabels.activitiesMessage` and NavigationLink to `.activityList`. |
| `Travellify/Models/SchemaV1.swift` | Activity registered in V1 models | VERIFIED | L13 + typealias L29; `SchemaTests.schemaV1HasSixModels` passes. |
| `Travellify/Models/Trip.swift` | `activities: [Activity]?` cascade relationship | VERIFIED | L24-25 cascade with inverse `\Activity.trip`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| TripDetailView activities card | ActivityListView | NavigationLink(value: .activityList(tripID)) | WIRED | `TripDetailView.swift:105`; `ContentView.swift:18-19` resolves destination |
| ActivityListView toolbar `+` | ActivityEditSheet (create) | `showAddSheet` + `.sheet(isPresented:)` | WIRED | `ActivityListView.swift:58-70` |
| ActivityRow tap | ActivityEditSheet (edit) | `onTapGesture` + `.sheet(item:)` | WIRED | `ActivityListView.swift:100` + L72-76 |
| ActivityEditSheet Save | modelContext persist | `save()` → `modelContext.insert/update` + `modelContext.save()` | WIRED | `ActivityEditSheet.swift:118-144`; proven by `ActivityTests.insertActivityRoundTrip` and `mutationPersistsAfterSave` |
| ActivityListView swipe Delete | modelContext.delete | `swipeActions` → `delete(activity)` | WIRED | `ActivityListView.swift:101-107,120-123`; cascade proven by `ActivityTests.deleteTripCascadesToActivities` |
| @Query predicate | Activity.trip inverse | `#Predicate { $0.trip?.persistentModelID == tripID }` + SortDescriptors | WIRED | `ActivityListView.swift:16-25`; inverse relationship confirmed in `Trip.swift:24-25` |
| Activity @Model | SchemaV1 + ModelContainer | Registered in `TravellifySchemaV1.models` + typealias | WIRED | `SchemaV1.swift:13,29`; `SchemaTests.containerInitializesWithMigrationPlan` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| ActivityListView | `activities: [Activity]` | SwiftData `@Query` filtered by tripID with sort descriptors | Yes — real fetch; persisted across restarts per FOUND-01 | FLOWING |
| ActivityRow | `activity.title/startAt/location` | Bound SwiftData model prop | Yes | FLOWING |
| ActivityDayHeader | `day, count` | Passed from grouping computation in parent | Yes | FLOWING |
| TripDetailView activities card | `ActivityDateLabels.activitiesMessage(for: trip)` | `trip.activities` cascade relationship | Yes | FLOWING |
| ActivityEditSheet | `title/startAt/location/notes` @State | Prefilled from activity prop or `defaultStartAt(for: trip)` | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Project compiles for iOS Simulator | `xcodebuild … build` | `** BUILD SUCCEEDED **` | PASS |
| Phase 4 schema/model tests pass | `xcodebuild test -only-testing:.../ActivityTests` | 5/5 pass (defaults, round-trip, mutation, cascade, nil-clear) | PASS |
| Grouping tests pass | `xcodebuild test -only-testing:.../ActivityGroupingTests` | 5/5 pass | PASS |
| Day-label tests pass | `xcodebuild test -only-testing:.../DayLabelTests` | 5/5 pass | PASS |
| Next-upcoming message tests pass | `xcodebuild test -only-testing:.../NextUpcomingTests` | 7/7 pass | PASS |
| Schema integrity + CloudKit-safe gate passes | `xcodebuild test -only-testing:.../SchemaTests` | 4/4 pass | PASS |

Total: 26 Phase-4 unit tests pass; build green.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| ACT-01 | Create activity with title, date/time, location text, notes | SATISFIED (needs human UI confirm) | ActivityEditSheet + save() insert path; ActivityTests.insertActivityRoundTrip |
| ACT-03 | Chronological day-by-day grouped list | SATISFIED | ActivityListView grouping + @Query sort; ActivityGroupingTests (5) |
| ACT-04 | Edit all fields of an existing activity | SATISFIED (needs human UI confirm) | ActivityEditSheet edit-mode loadInitialValuesIfNeeded + save update branch; ActivityTests.mutationPersistsAfterSave + optionalFieldsCanBeClearedToNil |
| ACT-05 | Delete an activity | SATISFIED (needs human UI confirm) | ActivityListView swipeActions Delete → modelContext.delete |

REQUIREMENTS.md still lists ACT-01 and ACT-04 as `[ ]` Pending in the checkbox but mapped to Phase 4. Implementation evidence satisfies both; the unchecked boxes are a documentation hygiene issue, not a gap. Recommend updating REQUIREMENTS.md checkboxes and traceability status for ACT-01 and ACT-04 to Complete after human UI confirmation.

### Anti-Patterns Found

None. No TODO/FIXME/PLACEHOLDER tokens, no empty `return null` handlers, no `console.log`-only implementations. `assertionFailure` in `ActivityEditSheet.save` catch is a dev-only signal; error alert path exists in `ActivityListView.delete`. `@MainActor` isolation and in-memory preview containers follow established Phase 1–3 patterns.

### Deferred Items

None. All four ROADMAP success criteria for Phase 4 are in-scope and evidenced. Notifications (ACT-07/08/09) and photo attachment (ACT-02/06) are correctly deferred to Phase 5 and Phase 7 respectively.

### Human Verification Required

See the `human_verification:` block in the frontmatter for explicit manual test steps. The five items cover: activity creation flow, edit flow, swipe-to-delete, soft out-of-range warning, and TripDetail smart-next-up navigation. These exercise SwiftUI gestures (tap, swipe, DatePicker wheel, sheet dismissal) and visual state that cannot be asserted from unit tests.

### Gaps Summary

No code or wiring gaps identified. All four ROADMAP success criteria are backed by implementation, wiring, and passing unit tests. The only open items are physical-simulator confirmations of gesture-driven UI and a minor documentation hygiene fix in REQUIREMENTS.md (ACT-01 and ACT-04 checkboxes / traceability table still say Pending despite roadmap marking Phase 4 complete).

---

**Overall phase verdict:** HUMAN_NEEDED — programmatic goal-backward verification passes (4/4 truths, 12/12 artifacts, 7/7 key links, 5/5 data flows, 26/26 unit tests, build green). Phase cannot be promoted to full PASS without running the simulator to confirm the five interaction flows listed under human_verification.

_Verified: 2026-04-21_
_Verifier: Claude (gsd-verifier)_

---

## Manual Verification Closure — 2026-04-21

All five `human_verification:` flows exercised on `iPhone 16e` simulator and confirmed working:

1. **Create activity end-to-end** — `+` toolbar opens ActivityEditSheet with pre-filled startAt, title/location/notes entered, compact DatePicker adjusted, Add persists; new row lands in correct day section, time-sorted.
2. **Edit existing activity** — tapping a row opens the sheet in edit mode with all 4 fields prefilled; mutating each and saving updates the row; date changes relocate it to the right day section.
3. **Delete via swipe** — trailing swipe reveals red Delete; tap deletes the activity; section header disappears when empty; EmptyActivitiesView replaces the list when last activity deleted.
4. **Out-of-range soft warning** — picking a date outside `[trip.startDate, trip.endDate]` shows the "Outside trip dates" warning row; Save stays enabled.
5. **TripDetail smart next-up card** — empty → `No activities yet`; upcoming → `Next: <title> · Today at <time>`; all past → `<N> activities`; tap navigates to ActivityListView.

**Verdict:** PASS. Phase 4 is closed. Proceed to Phase 5 (Notifications).

_Manual verification: 2026-04-21 — Alisher_
