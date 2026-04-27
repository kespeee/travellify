---
phase: 07-ui-overhaul
plan: 03
subsystem: trips-populated-list
tags: [phase-7, trips, populated-list, hero-card, mapkit, geocoding, context-menu, scrollview-lazyvstack]
dependency_graph:
  requires: [07-01-design-foundation, 07-02-trips-empty-state]
  provides: [trip-list-hero-card, trip-list-following-row, trip-map-snapshot-provider, populated-trips-redesign]
  affects: [TripListView.swift]
tech_stack:
  added: [MapKit (MKMapSnapshotter), CoreLocation (CLGeocoder)]
  patterns: [scrollview-lazyvstack-rows, mainactor-singleton-cache, task-id-trip-id-snapshot-fetch, navigationlink-with-buttonstyle-plain, sheet-item-edit, contextmenu-edit-delete]
key_files:
  created:
    - Travellify/Features/Trips/TripMapSnapshotProvider.swift
    - Travellify/Features/Trips/UpcomingTripCard.swift
    - Travellify/Features/Trips/FollowingTripRow.swift
  modified:
    - Travellify/Features/Trips/TripListView.swift
    - Travellify.xcodeproj/project.pbxproj
    - .planning/phases/07-ui-overhaul/07-CONTEXT.md
decisions:
  - "[07-03] AppDestination.tripDetail takes PersistentIdentifier, not UUID — used trip.persistentModelID at NavigationLink call sites (plan said trip.id; Trip.id is UUID, not the right type for the destination case)"
  - "[07-03] @MainActor TripMapSnapshotProvider singleton with inflight Task coalescing — Swift 6 strict concurrency clean; cache + inflight dicts are MainActor-isolated, no actor or @unchecked Sendable needed"
  - "[07-03] CLGeocoder retained per plan despite iOS 26 deprecation warning (suggests MKGeocodingRequest) — pre-existing API surface explicitly prescribed by plan; deprecation is a follow-up cleanup, not a Rule 1 bug"
  - "[07-03] Geocoding does NOT execute in #Preview (Trip() has no destinations) — only in simulator runtime against real trips with destination names; verified via build success and the plan's expected gradient-fallback preview behavior"
  - "[07-03] ForEach uses id: \\.id (UUID) instead of id: \\.persistentModelID — explicit and stable across SwiftData refetches; matches existing TripPartition return type [Trip]"
  - "[07-03] TripRow.swift left intact in pbxproj though no longer referenced by TripListView — safer to leave unused-but-compiled than to risk pbxproj surgery for an out-of-scope file removal; can be reaped in a later cleanup pass"
metrics:
  duration: ~30min
  completed: 2026-04-27
---

# Phase 7 Plan 03: Populated TripListView Summary

Wave 3 of Phase 7 sub-phase 7.2 (Trips). Replaces the populated `List(.insetGrouped)` body of `TripListView` with a custom `ScrollView` + `LazyVStack` that renders one `UpcomingTripCard` hero (Figma node 122:2783 — map snapshot, "Upcoming" badge, dual month/day date block, packing-progress block) and two follow-on sections — `FOLLOWING` (rest of upcoming) and `PAST` (past trips) — both built from the new compact `FollowingTripRow`. Map backgrounds come from a new `@MainActor` `TripMapSnapshotProvider` that geocodes destination names via `CLGeocoder` and renders bounding-region snapshots via `MKMapSnapshotter`. Empty branch (`TripEmptyState`), toolbar `+` conditional, sheet/alert wiring, and deep-link `AppDestination.tripDetail` flow are all preserved verbatim.

## What Shipped

- `Travellify/Features/Trips/TripMapSnapshotProvider.swift` — `@MainActor final class` singleton; `cache: [UUID: UIImage]` + `inflight: [UUID: Task<UIImage?, Never>]`; coalesces concurrent requests; per-destination `geocodeAddressString` then `MKMapSnapshotter.start()`; bounding region with 1.5× padding (min span 0.05°); returns `nil` when no destinations resolve, signaling caller to show gradient
- `Travellify/Features/Trips/UpcomingTripCard.swift` — 271pt hero: ZStack left panel (map snapshot or gradient fallback + bottom darkening LinearGradient + Badge top + name/destinations bottom) + 104pt right panel (DateBlock 116pt + PackingBlock flex). Private nested views: `Badge`, `DateBlock` (cross-year `MMM 'YY` suffix when `Calendar.year(start) != Calendar.year(end)`), `PackingBlock` (32pt ring + count + label, OR "No items in the packing list" footnote), `ProgressRing`. `task(id: trip.id)` fetches snapshot. `.contextMenu` Edit + Delete.
- `Travellify/Features/Trips/FollowingTripRow.swift` — compact row: 52pt `DatePill` (red uppercase MMM + bold day on `tertiarySystemBackground`) + flex VStack (`.title3.weight(.semibold)` name + days/destinations subtitle) + chevron. 24pt corner, `Color.black.opacity(0.56)` background. `.contextMenu` Edit + Delete.
- `Travellify/Features/Trips/TripListView.swift` — populated branch rewritten as `ScrollView { LazyVStack(spacing: 16) { ... } }`:
  - Hero from `upcomingTrips.first` (skip if no upcoming, e.g. past-only edge case)
  - `FOLLOWING` section header + `ForEach` for `upcomingTrips.dropFirst()`
  - `PAST` section header + `ForEach` for `pastTrips`
  - Each row wrapped in `NavigationLink(value: AppDestination.tripDetail(trip.persistentModelID))` + `.buttonStyle(.plain)`
  - New `@State private var tripToEdit: Trip?` + `.sheet(item: $tripToEdit) { TripEditSheet(mode: .edit($0)) }`
  - Empty branch (`TripEmptyState(onCreateTrip:)`), toolbar conditional `+`, `showNewTrip` sheet, `tripPendingDelete` alert, deep-link consumer all preserved verbatim
- `Travellify.xcodeproj/project.pbxproj` — 12 entries (4 per new Swift file): PBXBuildFile, PBXFileReference, group child under `Trips/`, sources-build-phase entry. UUID prefix `AD0703…` for plan 07-03.
- `.planning/phases/07-ui-overhaul/07-CONTEXT.md` — appended `Revision 2026-04-27 — Populated TripListView (07-03)` block with D7-08…D7-15 and a D7-03 sub-phase ordering note.

## Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e'` after each task: **BUILD SUCCEEDED**. Only warnings emitted are pre-existing iOS 26 deprecations of `CLGeocoder` / `geocodeAddressString` / `UIScreen.main` (acknowledged in plan; CLGeocoder is the API the plan prescribed)
- `xcodebuild test` full suite after Task 4: **TEST SUCCEEDED** — all Phase 1–6 + 07-01/07-02 tests green (~248s elapsed). Tests covered include TripTests, PartitionTests, ReminderLifecycleTests, NotificationSchedulerTests, ImportTests, packing/document/activity suites
- pbxproj entries verified by successful Xcode build (host `plutil -lint` rejects modern JSON-format Contents.json files; build-success is the canonical validator per 07-02 precedent)

### MapKit + Geocoding Outcome

**At preview time:** `#Preview` instantiates a fresh `Trip()` whose `destinations` array is empty. `TripMapSnapshotProvider.snapshot(for:)` short-circuits on the `names.isEmpty` guard and returns `nil` without geocoding or hitting MapKit. The card renders the gradient fallback. **No snapshot is fetched in preview.**

**At simulator runtime** with a real persisted trip carrying ≥1 destination name: the provider resolves each name via `CLGeocoder.geocodeAddressString` (serial; rate-limit ~1 req/sec), computes a bounding `MKCoordinateRegion`, and renders a snapshot via `MKMapSnapshotter.start()`. First fetch is slow (geocoding latency); the resulting `UIImage` is cached by `trip.id`, so subsequent reappearances of the hero (e.g. tab back, scroll back) return instantly from the in-memory cache. If geocoding fails for **all** destination names, the provider returns `nil` and the gradient fallback persists for the session.

This means: **the card appearance flips from gradient → map asynchronously the first time a populated `TripListView` renders for a trip with valid destination names**, and stays as the cached snapshot afterward.

### Manual Verification (deferred to user — requires runtime data)

- **Empty path** (no trips at all): `TripEmptyState` renders unchanged from 07-02 (illustration + "No trips yet" + CTA). Toolbar `+` hidden.
- **One-trip path** (single upcoming, no past): only the hero `UpcomingTripCard` renders; no `FOLLOWING`, no `PAST`.
- **Multi-trip path** (2+ upcoming): hero + `FOLLOWING` section with N-1 `FollowingTripRow`s.
- **Past-only edge case** (no upcoming, ≥1 past): `else` branch entered, hero skipped (no upcoming.first), only `PAST` section renders.
- **Tap on either card type**: pushes `TripDetailView` via `AppDestination.tripDetail(persistentModelID)` — same destination as before.
- **Long-press hero or row**: context menu shows Edit + Delete. Edit fires `.sheet(item: $tripToEdit) { TripEditSheet(mode: .edit(trip)) }`; Delete fires existing `tripPendingDelete` alert with cascade-warning copy.
- **Toolbar `+`**: still visible only when `!allTrips.isEmpty`; opens `TripEditSheet(mode: .create)`.
- **Background**: pure black on populated path; system background on empty path (07-02 unchanged).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] AppDestination.tripDetail takes PersistentIdentifier, not UUID**
- **Found during:** Task 4
- **Issue:** Plan pseudo-diff used `AppDestination.tripDetail(hero.id)` and `AppDestination.tripDetail(trip.id)`. The actual `AppDestination` enum case is `case tripDetail(PersistentIdentifier)`, while `Trip.id` is `UUID`. Compilation would fail with a type mismatch.
- **Fix:** All NavigationLink call sites use `AppDestination.tripDetail(trip.persistentModelID)` — matches existing destination grammar (same pattern used by the original `TripListView.row(for:)`). UUID still flows into `task(id: trip.id)` and the cache key in `TripMapSnapshotProvider`, where `UUID` is the correct value type.
- **Files modified:** `Travellify/Features/Trips/TripListView.swift`
- **Commit:** fdba2d2

### Notes (not auto-fixes)

**1. CLGeocoder deprecation warning ignored — plan-prescribed API**
- **Found during:** Task 1 build
- **Issue:** Xcode 26.2 SDK warns `'CLGeocoder' was deprecated in iOS 26.0: Use MapKit` and `'geocodeAddressString' was deprecated in iOS 26.0: Use MKGeocodingRequest`. Plan explicitly specified `CLGeocoder.geocodeAddressString` for the geocoding pipeline.
- **Resolution:** Kept the API per plan. The migration to `MKGeocodingRequest` is a follow-up cleanup task — not a correctness or security issue, not blocking, and changing it now would deviate from the plan's signature without a behavior change. Logging here so a future maintenance plan can pick it up.
- **Files affected:** `Travellify/Features/Trips/TripMapSnapshotProvider.swift`

**2. UIScreen.main deprecation warning ignored — same rationale**
- Same pattern: deprecated API used per plan; cleanup deferred. The replacement (looking up scale via traitCollection) requires a non-trivial pipe of trait collection from the SwiftUI environment into a non-View singleton; out of scope for this wave.

**3. TripRow.swift left in pbxproj as orphan code**
- TripListView no longer references `TripRow`. Removing its pbxproj entries is out of scope and risks bigger surgery; it compiles harmlessly. Future cleanup plan can prune it.

**4. plutil JSON-lint friction known from 07-02 precedent**
- Did not run `plutil -lint` on pbxproj; the host's `plutil` rejects modern JSON-formatted Apple plist inputs (07-02 documented this). Build-success on iPhone 16e simulator is the canonical validator.

## Auth Gates

None encountered.

## Out of Scope (deferred per plan)

- TripDetailView redesign — pending designer delivery (07-04+)
- TripEditSheet redesign — pending designer delivery (07-05+)
- "On trip" / in-progress badge state — designer hasn't shipped this; current hero always shows "Upcoming" badge
- Map snapshot disk cache — D7-10 ships in-memory only
- PAST section dim/restyle — same FollowingTripRow reused
- Light-mode color variants — deferred per CONTEXT.md
- Cross-section drag-reorder — out of scope; trips remain sorted by date
- Search / filter — not in v1.0
- CLGeocoder → MKGeocodingRequest migration (iOS 26 deprecation cleanup)
- TripRow.swift removal (orphan after this plan)
- Documents / Packing / Activities / Notifications UI redesigns — later sub-phases

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | ad2fe12 | feat(07-03): TripMapSnapshotProvider — geocoded MapKit snapshots with in-memory cache |
| 2 | 64edbbd | feat(07-03): UpcomingTripCard hero with map snapshot, date block, packing block |
| 3 | bed6931 | feat(07-03): FollowingTripRow small card for FOLLOWING / PAST sections |
| 4 | fdba2d2 | feat(07-03): TripListView populated body — hero + FOLLOWING + PAST cards |
| 5 | ab108e5 | docs(07-03): record D7-08…D7-15 populated-list decisions in CONTEXT.md |

## Self-Check: PASSED

- All 3 created files exist on disk: `Travellify/Features/Trips/TripMapSnapshotProvider.swift`, `UpcomingTripCard.swift`, `FollowingTripRow.swift` (verified via Write tool responses)
- All 5 commit hashes resolve in `git log --oneline`: ad2fe12, 64edbbd, bed6931, fdba2d2, ab108e5
- Xcode build green on iPhone 16e simulator (Xcode 26.2)
- Full xcodebuild test suite green — Phase 1–6 + 07-01/07-02 tests unaffected
- 07-CONTEXT.md grep confirms D7-08…D7-15 (count = 8)
- pbxproj has 12 new entries (4 per new file × 3 new files)
