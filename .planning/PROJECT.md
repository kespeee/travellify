# Travellify

## What This Is

An iOS app that serves as a traveler's on-trip companion. For each trip, users store travel documents (passport scans, tickets, bookings), build and check off a packing list, and manage a day-by-day itinerary of activities with locations, notes, and photos. Built for solo travelers who want everything about a trip in one place on their phone.

## Core Value

**Fast, reliable on-trip access to your documents, packing list, and today's activities** — if nothing else works, a traveler on the ground must be able to pull up their passport scan, check off packing items, and see what's next in their itinerary without friction.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can create a trip with a name and date range, supporting multi-stop itineraries (multiple destinations in one trip)
- [ ] User can browse all their trips and open one to see its contents
- [ ] User can upload documents to a trip via camera scan (VisionKit), photo library, or Files app (PDF/image)
- [ ] User can view, rename, and delete documents within a trip
- [ ] User can build a packing list from scratch, organized by category (toiletries, electronics, clothing, etc.)
- [ ] User can swipe an item on the packing list to check it off (and swipe to uncheck)
- [ ] User can add, edit, and delete packing items and categories
- [ ] User can create an activity with title, date & time, location, notes, and attached photos
- [ ] User can view activities as a day-by-day chronological list within a trip
- [ ] User can edit or delete an activity
- [ ] User can optionally enable a local notification reminder per activity
- [ ] All data persists locally via SwiftData across app launches

### Out of Scope

- **Cloud sync (v1)** — deferred to a later milestone; v1 ships local-only via SwiftData
- **Multi-user / trip sharing** — deferred to a later milestone after cloud sync lands
- **Offline-first sync infrastructure** — app is "online only" semantically (no backend in v1), but local-only storage means it naturally works without a connection; no conflict resolution needed yet
- **iPad / Universal app** — iPhone-only in v1 to narrow surface area
- **Android / cross-platform** — iOS native only
- **Calendar/timeline view, map view** — day-by-day list only in v1; other views deferred
- **Trip templates / copy-from-past-trip packing lists** — users build lists from scratch in v1
- **Document OCR / auto-categorization** — docs are stored and named manually
- **Post-trip memory / journaling features** — focus is on-trip utility, not archive
- **Booking integrations (flights, hotels)** — user manually creates activities and uploads confirmations
- **Currency / translation / maps integrations** — out of scope; app is organizational, not a Swiss-army travel tool

## Context

- **Domain:** Travel utility apps. Users want a single app that replaces screenshots in camera roll, scattered notes, and paper printouts. Core use case is mid-trip access — finding a passport scan at passport control, checking the packing list the night before leaving, glancing at today's activities over breakfast.
- **User:** Solo traveler using their own iPhone. Willing to manually enter trip data; values a clean, calm interface over feature density.
- **Tech environment:** Native iOS with SwiftUI + SwiftData. No backend, no account system in v1. Apple frameworks where possible: VisionKit for scans, PhotosUI for photo picking, UserNotifications for reminders.
- **Evolutionary path:** v1 local-only → v2 cloud sync (likely CloudKit — minimal friction since it's already an iOS app) → v3 trip sharing with collaborators.

## Constraints

- **Tech stack**: SwiftUI + SwiftData — Local-first; **minimum iOS 26** (raised 2026-04-27 from iOS 17 to use Liquid Glass and `.glassProminent` button style natively, no fallback branches)
- **Platform**: iOS native, iPhone only — Swift/SwiftUI, no cross-platform framework
- **Storage**: SwiftData local persistence in v1 — No backend, no auth, no network layer needed yet
- **Design**: Clean & native — Use SF Symbols, system colors, stock iOS components; minimal custom styling in v1
- **Connectivity**: No online dependencies in v1 — All features must work on a local device without a server
- **Scope discipline**: v1 is deliberately narrow — Anything not explicitly in Active is a future milestone, not a stretch goal

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| iOS native with SwiftUI | User chose iOS-only; SwiftUI is the modern default and pairs cleanly with SwiftData | — Pending |
| SwiftData for persistence | Native, no dependencies, handles migrations — and sets up clean CloudKit migration path for v2 | — Pending |
| Per-trip content scoping | Trips are the organizing primitive; docs/packing/activities all belong to one trip | — Pending |
| Local-only in v1, cloud sync in v2 | Ship faster; validate core experience before investing in sync infrastructure | — Pending |
| Day-by-day list for activities | Simplest mental model; map/calendar views deferred until the list is proven useful | — Pending |
| Packing: from scratch each time | Defers templating complexity; real usage will reveal which templates are actually wanted | — Pending |
| iPhone-only, no iPad | Narrow the surface area for v1; Universal adds layout work without validating core value | — Pending |
| Notifications optional per-activity | Not every activity needs a reminder (e.g., "dinner at 8"); user picks | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-18 after initialization*
