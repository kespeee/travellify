# Roadmap: Travellify

## Overview

Nine phases deliver a complete local-first iOS travel companion. Phase 1 lays the data foundation and trip management before any content feature exists. Phases 2–5 build the three core feature pillars in dependency order: documents first (establishes the file storage pattern reused by photos), then packing (simpler, validates in-trip navigation), then activities in two passes (core CRUD first, then notifications). Phase 6 delivers core functional polish and TestFlight-submission minimums (icon, privacy manifest, version metadata). Phases 7–9 re-scope v1.0 toward a design-led ship: a full UI overhaul to designer-provided mocks (Phase 7), a bug-bash / UI-fixes pass (Phase 8), and a dedicated testing phase (Phase 9 — UAT, expanded automated coverage, external TestFlight beta, bug-fix window) before App Store submission.

**Deferred to later milestones:**
- **v1.x** — Settings (first), Activity Photos (second)
- **v2.0** — CloudKit sync, user registration, onboarding

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation + Trips** - Data model, schema versioning, navigation shell, and full trip CRUD
- [x] **Phase 2: Documents** - Document import (camera/Photos/Files), full-screen viewer, rename, delete (completed 2026-04-20)
- [x] **Phase 3: Packing List** - Categorized packing list, swipe check-off, category and item CRUD, progress indicator (completed 2026-04-20)
- [x] **Phase 4: Activities (Core)** - Activity CRUD, day-by-day grouped list, edit and delete (completed 2026-04-22)
- [x] **Phase 5: Notifications** - Per-activity notification toggle, full lifecycle management, 64-cap scheduler (completed 2026-04-23)
- [x] **Phase 6: Polish + TestFlight Prep** - UI polish pass, trip-level reminders (TRIP-07/08/09), placeholder icon, PrivacyInfo manifest, version metadata (completed 2026-04-24)
- [ ] **Phase 7: UI Overhaul** - Full UI redesign against designer-provided mocks (Figma) — typography, color, spacing, iconography, component system; awaiting designs before planning
- [ ] **Phase 8: UI Fixes** - Targeted bug-bash and UI-fix pass: defects surfaced during Phase 7 overhaul and accumulated polish items found along the way
- [ ] **Phase 9: Testing + Release Readiness** - Manual UAT against all requirements, expanded automated coverage (integration + UI tests), external TestFlight beta with real users, bug-fix window; exits with App Store–submittable build

## Phase Details

### Phase 1: Foundation + Trips
**Goal**: Users can create and manage trips; the app's data foundation is correct and CloudKit-ready from the first commit
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, TRIP-01, TRIP-02, TRIP-03, TRIP-04, TRIP-05, TRIP-06
**Success Criteria** (what must be TRUE):
  1. User can create a trip with a name, start date, end date, and one or more destinations
  2. User can browse a sorted list of all their trips and open any trip to see its detail screen
  3. User can edit a trip's name, dates, and destinations after creation
  4. User can delete a trip; the deletion cascades cleanly (all future content will be removed with it)
  5. App data survives force-quit, device restart, and app reinstall without data loss
**Plans**: 6 plans
Plans:
- [x] 01-01-PLAN.md — Scaffold Xcode project (iOS 17 / Swift 6 / Swift Testing target); BLOCKING checkpoint falls back to Xcode GUI if CLI scaffold fails
- [x] 01-02-PLAN.md — SchemaV1 VersionedSchema + Trip/Destination/placeholder @Model types + ModelContainer wiring + PreviewContainer
- [x] 01-03-PLAN.md — AppDestination enum + NavigationStack root + TripListView with Upcoming/Past in-memory partitioning + empty state
- [x] 01-04-PLAN.md — TripEditSheet (create + edit) with validation, date normalization, destination add/remove/reorder
- [x] 01-05-PLAN.md — TripDetailView (header + 3 cards) + TabView shell + dark theme + swipe-to-delete with confirmation dialog; manual smoke-test passed
- [x] 01-06-PLAN.md — Swift Testing coverage: TripTests + SchemaTests + PartitionTests + CloudKit-safety grep gate
**UI hint**: yes

### Phase 2: Documents
**Goal**: Users can import, view, rename, and delete travel documents within a trip
**Depends on**: Phase 1
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06, DOC-07
**Success Criteria** (what must be TRUE):
  1. User can scan a document with the camera and it appears in the trip's document list with a name prompt
  2. User can import a photo from their Photos library and view it full-screen with pinch-to-zoom
  3. User can import a PDF from Files and view it page by page with pinch-to-zoom
  4. User can rename a document and delete a document from a trip
  5. Document files are stored on disk (not as data blobs in the database); app remains responsive during import
**Plans**: 6 plans
Plans:
- [x] 02-01-PLAN.md — Document @Model fields + DocumentKind enum + FileStorage service + AppDestination.documentList stub
- [x] 02-02-PLAN.md — DocumentListView (empty state + rows + toolbar Menu + context-menu rename/delete stubs + fullScreenCover stub) + TripDetail Documents-card NavigationLink wire-up
- [x] 02-03-PLAN.md — Scan/Photos/Files importer bridges + DocumentImporter (off-main write, on-main insert) + NSCameraUsageDescription
- [x] 02-04-PLAN.md — DocumentViewer (PDFKit for PDFs, zoomable image for .image) replacing the list's fullScreenCover stub
- [x] 02-05-PLAN.md — Rename + Delete action wiring (T-02-08 invariant) + trip-cascade folder cleanup in TripListView
- [x] 02-06-PLAN.md — Swift Testing coverage (FileStorageTests, DocumentTests, ImportTests, ViewerTests) + fixtures + CloudKit-safety gate
**UI hint**: yes

### Phase 3: Packing List
**Goal**: Users can build, manage, and check off a categorized packing list for each trip
**Depends on**: Phase 2
**Requirements**: PACK-01, PACK-02, PACK-03, PACK-04, PACK-05, PACK-06, PACK-07
**Success Criteria** (what must be TRUE):
  1. User can create categories (e.g., Toiletries, Electronics) and add named items under each
  2. User can swipe an item to check it off, and swipe it again to uncheck it
  3. User can edit an item's name or move it to a different category, and delete any item
  4. User can add, rename, and delete categories
  5. A progress indicator at the top of the list shows how many items have been checked off (e.g., "12 / 23 packed")
**Plans**: 4 plans
Plans:
- [x] 03-01-PLAN.md — Packing schema foundation: PackingCategory @Model + PackingItem replacement + Trip.packingCategories + AppDestination.packingList + stub view + repair existing tests
- [x] 03-02-PLAN.md — PackingListView scaffold: @Query-driven List with Section-per-category, PackingProgressRow, EmptyPackingListView, CategoryHeader + contextMenu, category add/rename/delete, TripDetail Packing card wire-up
- [x] 03-03-PLAN.md — Item CRUD + interactions: PackingRow with inline rename, leading/trailing swipeActions, sensoryFeedback, inline add-item row with dual @FocusState, cross-category drag-and-drop
- [x] 03-04-PLAN.md — Swift Testing coverage: PackingTests (model invariants + cascade) + PackingProgressTests (progress formula edge cases)
**UI hint**: yes

### Phase 4: Activities (Core)
**Goal**: Users can create, view, edit, and delete a day-by-day itinerary of activities within a trip
**Depends on**: Phase 3
**Requirements**: ACT-01, ACT-03, ACT-04, ACT-05
**Success Criteria** (what must be TRUE):
  1. User can create an activity with a title, date and time, optional location text, and optional notes
  2. User can see all activities in a trip grouped by date in chronological order, with activities sorted by time within each day
  3. User can edit any field of an existing activity
  4. User can delete an activity
**Plans**: 4 plans
Plans:
- [x] 04-01-PLAN.md — Activity schema extension (D40 fields) + ActivityDateLabels helpers + ActivityTests + SchemaTests CloudKit-safety assertion
- [x] 04-02-PLAN.md — ActivityEditSheet (create + edit; compact DatePicker; soft-warn out-of-range; title-required Save)
- [x] 04-03-PLAN.md — ActivityListView (grouped @Query + swipe-delete + sheets) + ActivityRow/DayHeader/EmptyActivitiesView + Grouping/DayLabel tests
- [x] 04-04-PLAN.md — Routing (AppDestination.activityList + ContentView branch + TripDetailView Activities card smart-next-up) + NextUpcomingTests
**UI hint**: yes

### Phase 5: Notifications
**Goal**: Users can opt in to a local reminder per activity, with the full scheduling lifecycle handled correctly
**Depends on**: Phase 4
**Requirements**: ACT-07, ACT-08, ACT-09
**Success Criteria** (what must be TRUE):
  1. User can toggle a reminder on or off for an individual activity; the system permission dialog appears only on first use, preceded by a custom explanation
  2. When an activity's date or time is edited, its pending reminder is automatically rescheduled to the new time
  3. When an activity is deleted, its pending reminder is cancelled
  4. The app schedules only the soonest 64 reminders when the user has more than 64 enabled across all trips
**Plans**: 4 plans
Plans:
- [x] 05-01-PLAN.md — Activity schema additions (D52) + ReminderLeadTime enum + ReminderFireDate helper + schema/fireDate tests
- [x] 05-02-PLAN.md — NotificationCenterProtocol + NotificationScheduler (@MainActor soonest-64 reconcile) + MockNotificationCenter + NotificationSchedulerTests
- [x] 05-03-PLAN.md — ActivityEditSheet Reminder Section (D64) + ReminderPrimingSheet (D53) + denied-state UI (D54) + reconcile hook on save + PermissionStateTests
- [x] 05-04-PLAN.md — AppDelegate (@preconcurrency UNUserNotificationCenterDelegate) + AppState deep-link + ScenePhase reconcile + trip/activity delete reconcile + ReminderLifecycleTests
**UI hint**: yes

### Phase 6: Polish + TestFlight Prep
**Goal**: Ship a polished TestFlight-submittable build: targeted UI fixes, trip-level reminders, placeholder icon, privacy manifest, version metadata.
**Depends on**: Phase 5
**Requirements**: TRIP-07, TRIP-08, TRIP-09
**Success Criteria** (what must be TRUE):
  1. Document thumbnails render at 3:4 aspect ratio; document names are horizontally centered in list rows; newly imported documents get sequential `doc-<N>` default names (per-trip)
  2. Packing empty state is vertically centered, not top-aligned
  3. TripEditSheet auto-aligns `endDate = startDate` when start > end; end-date picker is bounded by `startDate`
  4. ActivityEditSheet DatePicker is clamped to `trip.startDate...trip.endDate` in both create and edit modes
  5. User can opt in to a trip-level reminder with 1 day / 3 days / 1 week / 2 weeks lead time; fires before trip start; lifecycle (reschedule on date change, cancel on delete) matches activity reminders; shares the 64-cap soonest-N pool (identifier prefix `trip-`)
  6. Placeholder app icon present in Assets.xcassets; `PrivacyInfo.xcprivacy` committed declaring UserDefaults + FileTimestamp API reasons; MARKETING_VERSION=1.0, CURRENT_PROJECT_VERSION=1, bundle ID `com.kespeee.travellify` verified in pbxproj
**Out of scope**: Accessibility pass; error-handling audit; extra confirmation dialogs; archive/upload to App Store Connect (user-run manual step)
**Plans**: 4 plans (4 waves)
Plans:
- [x] 06-01-PLAN.md — UI polish bundle (D70–D75: doc thumbnail 3:4, centered name, doc-N default naming, packing empty-state centering, TripEditSheet date self-consistency, ActivityEditSheet DatePicker clamp)
- [x] 06-02-PLAN.md — Trip schema additive fields (D76) + TripReminderLeadTime enum (D77) + ReminderFireDate Trip overload (D78) + tests [TRIP-07 foundation]
- [x] 06-03-PLAN.md — NotificationScheduler union pipeline (D79) + TripEditSheet Reminder Section (D82) + deep-link .trip(UUID) (D81) + ReminderLifecycleTests trip variants [TRIP-07/08/09]
- [x] 06-04-PLAN.md — TestFlight minimums: placeholder icon (D85) + PrivacyInfo.xcprivacy (D86) + version/build/bundle-ID verification (D87) + D88 no-op
**UI hint**: yes

### Phase 7: UI Overhaul
**Goal**: Apply a full visual redesign to the shipped feature set against designer-provided Figma mocks — unified typography, color system, spacing, iconography, and component library across every screen (trips, documents, packing, activities, notifications UI)
**Depends on**: Phase 6
**Requirements**: None (no new functional requirements — visual/structural changes only; existing requirements must continue to pass)
**Success Criteria** (what must be TRUE):
  1. Every screen in the app matches the designer-provided Figma mocks (to be attached when designs are delivered)
  2. A reusable component/token layer exists so Phase 8/9 fixes and future v1.x features can extend the design system instead of forking styles
  3. All Phase 1–6 requirements continue to pass (no functional regressions introduced by the overhaul)

**Plans**: TBD — planning blocked until designer delivers Figma file. Do NOT run `/gsd-plan-phase 7` before designs arrive.
**UI hint**: yes (design-heavy phase)

### Phase 8: UI Fixes
**Goal**: Close the visual / interaction defects discovered during the Phase 7 overhaul and the polish items accumulated during normal use
**Depends on**: Phase 7
**Requirements**: None (tracks defects, not net-new requirements)
**Success Criteria** (what must be TRUE):
  1. Every defect captured in `.planning/phases/08-ui-fixes/UI-FIXES.md` (running scratchpad populated during Phase 7) is either fixed, explicitly deferred to v1.x, or explicitly rejected with rationale
  2. No visual or interaction regressions vs. Phase 7 overhaul
  3. App build + full test suite green on iPhone 16e simulator after the pass

**Plans**: TBD (scoped when `UI-FIXES.md` scratchpad stabilizes after Phase 7 work)
**UI hint**: yes

### Phase 9: Testing + Release Readiness
**Goal**: Exit with an App Store–submittable build — manual UAT + expanded automated coverage + external TestFlight beta + bug-fix window
**Depends on**: Phase 8
**Requirements**: None (validates all prior requirements)
**Success Criteria** (what must be TRUE):
  1. Manual UAT pass executed against every v1.0 requirement (FOUND-*, TRIP-*, DOC-*, PACK-*, ACT-*, TRIP-07/08/09) with documented results
  2. Expanded automated test coverage lands (integration tests across feature boundaries + XCUITest flows for critical paths: create trip, import document, check off packing, create+edit+delete activity with reminder)
  3. External TestFlight beta runs with at least one real user cycle; feedback triaged into Fixed / Deferred / Rejected buckets
  4. Bug-fix window resolves every P0/P1 item from the beta cycle before submission
  5. Final archive validated and submission-ready (icon swapped from placeholder, App Store metadata drafted)

**Plans**: TBD
**UI hint**: no (test + release engineering, not UI work)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Trips | 6/6 | Complete | 2026-04-19 |
| 2. Documents | 6/6 | Complete | 2026-04-20 |
| 3. Packing List | 4/4 | Complete | 2026-04-20 |
| 4. Activities (Core) | 4/4 | Complete | 2026-04-22 |
| 5. Notifications | 4/4 | Complete | 2026-04-23 |
| 6. Polish + TestFlight Prep | 4/4 | Complete | 2026-04-24 |
| 7. UI Overhaul | 0/? | Blocked on designs | - |
| 8. UI Fixes | 0/? | Not started | - |
| 9. Testing + Release Readiness | 0/? | Not started | - |

---
*Roadmap created: 2026-04-18*
*Last updated: 2026-04-24 — v1.0 re-scope: Activity Photos moved to v1.x; added Phase 7 UI Overhaul (awaits designs), Phase 8 UI Fixes, Phase 9 Testing + Release; POLISH-05 Face ID and DOC-08 removed from roadmap entirely*
