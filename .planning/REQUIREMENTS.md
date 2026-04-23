# Requirements: Travellify

**Defined:** 2026-04-18
**Core Value:** Fast, reliable on-trip access to your documents, packing list, and today's activities — a traveler on the ground must be able to pull up their passport scan, check off packing items, and see what's next without friction.

## v1 Requirements

### Foundation

- [x] **FOUND-01**: App persists all data locally via SwiftData across launches, device restarts, and app kills
- [x] **FOUND-02**: SwiftData schema wrapped in `VersionedSchema` from first release (zero migrations initially, infrastructure in place)
- [x] **FOUND-03**: All `@Model` classes follow CloudKit-safe conventions (optional inverse relationships, no `@Attribute(.unique)`, no `.deny` delete rules) to preserve a clean v2 migration path

### Trips

- [x] **TRIP-01**: User can create a trip with a name and a date range (start date and end date)
- [x] **TRIP-02**: User can define a trip as multi-stop by adding multiple destinations (Paris → Rome → Florence) under a single trip
- [x] **TRIP-03**: User can browse a list of all their trips sorted by date
- [x] **TRIP-04**: User can open a trip to see its documents, packing list, and activities in one place
- [x] **TRIP-05**: User can edit a trip's name, dates, and destinations
- [x] **TRIP-06**: User can delete a trip, which cascades to delete all of its documents, packing items, and activities

### Documents

- [x] **DOC-01**: User can add a document to a trip by scanning it with the camera (VisionKit document scanner, multi-page + perspective correction)
- [x] **DOC-02**: User can add a document to a trip by importing from Photos (PHPickerViewController)
- [x] **DOC-03**: User can add a document to a trip by importing a PDF or image from the Files app (UIDocumentPickerViewController)
- [x] **DOC-04**: User can view a document full-screen with pinch-to-zoom, supporting both images and PDFs
- [x] **DOC-05**: User can rename a document after import
- [x] **DOC-06**: User can delete a document from a trip
- [x] **DOC-07**: Document binaries are stored in the filesystem (not as SwiftData `Data` blobs) with file paths referenced from the model
- [ ] ~~**DOC-08**~~: *(moved to v1.x POLISH-05 — Face ID lock deferred past first TestFlight; see Polish section below)*

### Packing

- [x] **PACK-01**: User can build a packing list for a trip from scratch, organized by user-created categories (e.g., Toiletries, Electronics, Clothing)
- [x] **PACK-02**: User can add a packing item under a category with a name
- [x] **PACK-03**: User can edit a packing item's name or category
- [x] **PACK-04**: User can delete a packing item
- [x] **PACK-05**: User can add, rename, and delete categories
- [x] **PACK-06**: User can check off a packing item by swiping the row (and swipe again to uncheck)
- [x] **PACK-07**: Packing list displays a progress indicator showing checked-off items over total (e.g., "12 / 23 packed") at the top of the list

### Activities

- [x] **ACT-01**: User can create an activity with title, date & time, location (text), and notes
- [ ] **ACT-02**: User can attach one or more photos to an activity from Photos (PHPickerViewController)
- [x] **ACT-03**: User can view all activities in a trip as a chronological day-by-day grouped list (grouped by date, sorted by time within each day)
- [ ] **ACT-04**: User can edit all fields of an existing activity (title, date/time, location, notes, photos)
- [x] **ACT-05**: User can delete an activity
- [ ] **ACT-06**: Activity photos are stored as file paths in the filesystem (not inline in SwiftData), with thumbnails generated at import time
- [x] **ACT-07**: User can opt in to a local notification reminder for an individual activity; when enabled, a `UNNotificationRequest` is scheduled to fire before the activity's start time
- [x] **ACT-08**: When an activity's date/time changes, its pending notification is rescheduled; when deleted, pending notification is cancelled
- [x] **ACT-09**: A `NotificationScheduler` respects iOS's 64-pending-notifications system cap by scheduling the soonest 64 and re-evaluating when the app foregrounds

### Trip Reminders (added Phase 6)

- [ ] **TRIP-07**: User can opt in to a local notification reminder for a trip; when enabled, a `UNNotificationRequest` is scheduled to fire before the trip's `startDate` by a user-selected lead time (1 day / 3 days / 1 week / 2 weeks)
- [ ] **TRIP-08**: When a trip's `startDate` changes, its pending reminder is rescheduled; when the trip is deleted, its pending reminder is cancelled
- [ ] **TRIP-09**: Trip reminders share the 64-pending-notifications soonest-N pool with activity reminders via identifier prefix `trip-<uuid>` vs. `<activity-uuid>`

## v2 Requirements

Deferred — tracked but out of v1 roadmap.

### Sync

- **SYNC-01**: User's trip data syncs across their devices via CloudKit
- **SYNC-02**: App handles offline edits with last-write-wins conflict resolution
- **SYNC-03**: Schema migration from v1 local-only store to CloudKit-synced store is lossless

### Sharing

- **SHARE-01**: User can invite another user to view or edit a trip
- **SHARE-02**: Shared trip permissions (view-only vs editor) are enforceable

### Polish (v1.x)

- **POLISH-01**: "Today" view filter showing only activities for the current date
- **POLISH-02**: "Uncheck all" action to reset a packing list for reuse
- **POLISH-03**: Tappable activity location opens in Apple Maps (deep link)
- **POLISH-04**: Calendar export per-activity via EventKit (one-way)
- **POLISH-05** *(was DOC-08)*: User can opt in, via Settings, to require Face ID / passcode authentication before accessing the Documents section of any trip (LocalAuthentication framework) — deferred past first TestFlight

## Out of Scope

| Feature | Reason |
|---------|--------|
| iPad / Universal layout | iPhone-only in v1 to narrow layout surface area |
| Android / cross-platform | iOS native only |
| Map view of activities | Deferred until day-by-day list validated; Apple Maps deep link covers 90% of need |
| Calendar / timeline visual view | Day-by-day list is sufficient; visual calendar defers to post-v1 |
| Document OCR / auto-categorization | Requires CoreML pipeline; manual rename is a two-tap alternative |
| Email import / booking auto-detection | Privacy-heavy, requires email access; manual entry is v1 model |
| Trip templates / copy-from-past-trip packing | Defer until real usage reveals template patterns |
| Budget / expense tracking | Separate product domain; Splitwise et al. handle this |
| Weather integration | Native Weather app is one swipe away; breaks offline-first trust |
| Post-trip journaling / photo album | Different product (archive vs on-trip utility); Polarsteps / Day One cover this |
| AI itinerary generation | Validate manual entry first; build only if users signal demand |
| Cloud sync / account system (v1) | Deferred to v2 milestone; ship local-only first |
| Multi-user / trip sharing (v1) | Deferred to v3 milestone; requires v2 account system |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| TRIP-01 | Phase 1 | Complete |
| TRIP-02 | Phase 1 | Complete |
| TRIP-03 | Phase 1 | Complete |
| TRIP-04 | Phase 1 | Complete |
| TRIP-05 | Phase 1 | Complete |
| TRIP-06 | Phase 1 | Complete |
| DOC-01 | Phase 2 | Complete |
| DOC-02 | Phase 2 | Complete |
| DOC-03 | Phase 2 | Complete |
| DOC-04 | Phase 2 | Complete |
| DOC-05 | Phase 2 | Complete |
| DOC-06 | Phase 2 | Complete |
| DOC-07 | Phase 2 | Complete |
| DOC-08 | *v1.x (POLISH-05)* | *Deferred past first TestFlight* |
| TRIP-07 | Phase 6 | Pending |
| TRIP-08 | Phase 6 | Pending |
| TRIP-09 | Phase 6 | Pending |
| PACK-01 | Phase 3 | Complete |
| PACK-02 | Phase 3 | Complete |
| PACK-03 | Phase 3 | Complete |
| PACK-04 | Phase 3 | Complete |
| PACK-05 | Phase 3 | Complete |
| PACK-06 | Phase 3 | Complete |
| PACK-07 | Phase 3 | Complete |
| ACT-01 | Phase 4 | Complete |
| ACT-02 | Phase 7 | Pending |
| ACT-03 | Phase 4 | Complete |
| ACT-04 | Phase 4 + 7 | Partial (non-photo fields done in Phase 4; photos editable after Phase 7) |
| ACT-05 | Phase 4 | Complete |
| ACT-06 | Phase 7 | Pending |
| ACT-07 | Phase 5 | Complete |
| ACT-08 | Phase 5 | Complete |
| ACT-09 | Phase 5 | Complete |

**Coverage:**
- v1 requirements: 35 total (DOC-08 demoted to v1.x POLISH-05; TRIP-07/08/09 added)
- Mapped to phases: 35
- Unmapped: 0

---
*Requirements defined: 2026-04-18*
*Last updated: 2026-04-23 — DOC-08 demoted to v1.x POLISH-05 (deferred past first TestFlight); TRIP-07/08/09 added for trip-level reminders in Phase 6*
