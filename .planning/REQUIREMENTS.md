# Requirements: Travellify

**Defined:** 2026-04-18
**Core Value:** Fast, reliable on-trip access to your documents, packing list, and today's activities — a traveler on the ground must be able to pull up their passport scan, check off packing items, and see what's next without friction.

## v1 Requirements

### Foundation

- [ ] **FOUND-01**: App persists all data locally via SwiftData across launches, device restarts, and app kills
- [ ] **FOUND-02**: SwiftData schema wrapped in `VersionedSchema` from first release (zero migrations initially, infrastructure in place)
- [ ] **FOUND-03**: All `@Model` classes follow CloudKit-safe conventions (optional inverse relationships, no `@Attribute(.unique)`, no `.deny` delete rules) to preserve a clean v2 migration path

### Trips

- [ ] **TRIP-01**: User can create a trip with a name and a date range (start date and end date)
- [ ] **TRIP-02**: User can define a trip as multi-stop by adding multiple destinations (Paris → Rome → Florence) under a single trip
- [ ] **TRIP-03**: User can browse a list of all their trips sorted by date
- [ ] **TRIP-04**: User can open a trip to see its documents, packing list, and activities in one place
- [ ] **TRIP-05**: User can edit a trip's name, dates, and destinations
- [ ] **TRIP-06**: User can delete a trip, which cascades to delete all of its documents, packing items, and activities

### Documents

- [ ] **DOC-01**: User can add a document to a trip by scanning it with the camera (VisionKit document scanner, multi-page + perspective correction)
- [ ] **DOC-02**: User can add a document to a trip by importing from Photos (PHPickerViewController)
- [ ] **DOC-03**: User can add a document to a trip by importing a PDF or image from the Files app (UIDocumentPickerViewController)
- [ ] **DOC-04**: User can view a document full-screen with pinch-to-zoom, supporting both images and PDFs
- [ ] **DOC-05**: User can rename a document after import
- [ ] **DOC-06**: User can delete a document from a trip
- [ ] **DOC-07**: Document binaries are stored in the filesystem (not as SwiftData `Data` blobs) with file paths referenced from the model
- [ ] **DOC-08**: User can opt in, via Settings, to require Face ID / passcode authentication before accessing the Documents section of any trip (LocalAuthentication framework)

### Packing

- [ ] **PACK-01**: User can build a packing list for a trip from scratch, organized by user-created categories (e.g., Toiletries, Electronics, Clothing)
- [ ] **PACK-02**: User can add a packing item under a category with a name
- [ ] **PACK-03**: User can edit a packing item's name or category
- [ ] **PACK-04**: User can delete a packing item
- [ ] **PACK-05**: User can add, rename, and delete categories
- [ ] **PACK-06**: User can check off a packing item by swiping the row (and swipe again to uncheck)
- [ ] **PACK-07**: Packing list displays a progress indicator showing checked-off items over total (e.g., "12 / 23 packed") at the top of the list

### Activities

- [ ] **ACT-01**: User can create an activity with title, date & time, location (text), and notes
- [ ] **ACT-02**: User can attach one or more photos to an activity from Photos (PHPickerViewController)
- [ ] **ACT-03**: User can view all activities in a trip as a chronological day-by-day grouped list (grouped by date, sorted by time within each day)
- [ ] **ACT-04**: User can edit all fields of an existing activity (title, date/time, location, notes, photos)
- [ ] **ACT-05**: User can delete an activity
- [ ] **ACT-06**: Activity photos are stored as file paths in the filesystem (not inline in SwiftData), with thumbnails generated at import time
- [ ] **ACT-07**: User can opt in to a local notification reminder for an individual activity; when enabled, a `UNNotificationRequest` is scheduled to fire before the activity's start time
- [ ] **ACT-08**: When an activity's date/time changes, its pending notification is rescheduled; when deleted, pending notification is cancelled
- [ ] **ACT-09**: A `NotificationScheduler` respects iOS's 64-pending-notifications system cap by scheduling the soonest 64 and re-evaluating when the app foregrounds

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
| FOUND-01 | Phase 1 | Pending |
| FOUND-02 | Phase 1 | Pending |
| FOUND-03 | Phase 1 | Pending |
| TRIP-01 | Phase 1 | Pending |
| TRIP-02 | Phase 1 | Pending |
| TRIP-03 | Phase 1 | Pending |
| TRIP-04 | Phase 1 | Pending |
| TRIP-05 | Phase 1 | Pending |
| TRIP-06 | Phase 1 | Pending |
| DOC-01 | Phase 2 | Pending |
| DOC-02 | Phase 2 | Pending |
| DOC-03 | Phase 2 | Pending |
| DOC-04 | Phase 2 | Pending |
| DOC-05 | Phase 2 | Pending |
| DOC-06 | Phase 2 | Pending |
| DOC-07 | Phase 2 | Pending |
| DOC-08 | Phase 6 | Pending |
| PACK-01 | Phase 3 | Pending |
| PACK-02 | Phase 3 | Pending |
| PACK-03 | Phase 3 | Pending |
| PACK-04 | Phase 3 | Pending |
| PACK-05 | Phase 3 | Pending |
| PACK-06 | Phase 3 | Pending |
| PACK-07 | Phase 3 | Pending |
| ACT-01 | Phase 4 | Pending |
| ACT-02 | Phase 7 | Pending |
| ACT-03 | Phase 4 | Pending |
| ACT-04 | Phase 4 | Pending |
| ACT-05 | Phase 4 | Pending |
| ACT-06 | Phase 7 | Pending |
| ACT-07 | Phase 5 | Pending |
| ACT-08 | Phase 5 | Pending |
| ACT-09 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 33 total
- Mapped to phases: 33
- Unmapped: 0

---
*Requirements defined: 2026-04-18*
*Last updated: 2026-04-18 — DOC-08 moved to Phase 6; ACT-02, ACT-06 moved to Phase 7*
