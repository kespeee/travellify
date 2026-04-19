# Roadmap: Travellify

## Overview

Seven phases deliver a complete local-first iOS travel companion. Phase 1 lays the data foundation and trip management before any content feature exists. Phases 2–5 build the three core feature pillars in dependency order: documents first (establishes the file storage pattern reused by photos), then packing (simpler, validates in-trip navigation), then activities in two passes (core CRUD first, then notifications). Phase 6 rounds the app into a shippable TestFlight build with security, empty states, and polish. Phase 7 adds activity photo attachment as a post-polish enhancement.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation + Trips** - Data model, schema versioning, navigation shell, and full trip CRUD
- [ ] **Phase 2: Documents** - Document import (camera/Photos/Files), full-screen viewer, rename, delete
- [ ] **Phase 3: Packing List** - Categorized packing list, swipe check-off, category and item CRUD, progress indicator
- [ ] **Phase 4: Activities (Core)** - Activity CRUD, day-by-day grouped list, edit and delete
- [ ] **Phase 5: Notifications** - Per-activity notification toggle, full lifecycle management, 64-cap scheduler
- [ ] **Phase 6: Polish + TestFlight** - Document lock (Face ID), empty states, error handling, accessibility, TestFlight build
- [ ] **Phase 7: Activity Photos** - Multi-photo import, thumbnails, photo grid in activity detail, file cleanup

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
- [ ] 02-01-PLAN.md — Document @Model fields + DocumentKind enum + FileStorage service + AppDestination.documentList stub
- [ ] 02-02-PLAN.md — DocumentListView (empty state + rows + toolbar Menu + context-menu rename/delete stubs + fullScreenCover stub) + TripDetail Documents-card NavigationLink wire-up
- [ ] 02-03-PLAN.md — Scan/Photos/Files importer bridges + DocumentImporter (off-main write, on-main insert) + NSCameraUsageDescription
- [ ] 02-04-PLAN.md — DocumentViewer (PDFKit for PDFs, zoomable image for .image) replacing the list's fullScreenCover stub
- [ ] 02-05-PLAN.md — Rename + Delete action wiring (T-02-08 invariant) + trip-cascade folder cleanup in TripListView
- [ ] 02-06-PLAN.md — Swift Testing coverage (FileStorageTests, DocumentTests, ImportTests, ViewerTests) + fixtures + CloudKit-safety gate
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
**Plans**: TBD
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
**Plans**: TBD
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
**Plans**: TBD
**UI hint**: yes

### Phase 6: Polish + TestFlight
**Goal**: The app is secure, handles edge cases gracefully, and is ready for TestFlight distribution
**Depends on**: Phase 5
**Requirements**: DOC-08
**Success Criteria** (what must be TRUE):
  1. User can enable a Face ID / passcode lock on the Documents section in Settings; the lock is enforced on every entry
  2. All list views show a clear empty state when no content exists yet (trips, documents, packing items, activities)
  3. Destructive actions (trip delete) show a confirmation alert before proceeding
  4. A TestFlight build installs and runs without crashes on a physical iPhone with iOS 17 or later
**Plans**: TBD
**UI hint**: yes

### Phase 7: Activity Photos
**Goal**: Users can attach photos to activities, view them in a grid, and have them managed correctly on disk
**Depends on**: Phase 6
**Requirements**: ACT-02, ACT-06
**Success Criteria** (what must be TRUE):
  1. User can select one or more photos from their Photos library and attach them to an activity
  2. Photos appear as a thumbnail grid in the activity detail view; tapping a thumbnail shows the full photo
  3. Photos are stored as files on disk (not data blobs); app memory stays within safe limits during multi-photo import
  4. When an activity is deleted, its associated photo files are removed from disk

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Trips | 6/6 | Complete | 2026-04-19 |
| 2. Documents | 0/6 | Not started | - |
| 3. Packing List | 0/? | Not started | - |
| 4. Activities (Core) | 0/? | Not started | - |
| 5. Notifications | 0/? | Not started | - |
| 6. Polish + TestFlight | 0/? | Not started | - |
| 7. Activity Photos | 0/? | Not started | - |

---
*Roadmap created: 2026-04-18*
*Last updated: 2026-04-20 — Phase 2 plans finalized (6 plans across 4 waves)*
