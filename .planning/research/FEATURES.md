# Feature Research

**Domain:** iOS travel companion app — documents, packing lists, day-by-day itinerary
**Researched:** 2026-04-18
**Confidence:** HIGH (competitor analysis from TripIt, Wanderlog, Tripsy, Polarsteps, PackPoint, Packr, Travel Document Vault; cross-referenced with App Store listings and review sources)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing = product feels broken or untrustworthy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Trip list with name and date range | Every travel app starts here; users need a browseable home screen | LOW | Multi-stop (multiple destinations, one trip) is the modern expectation — TripIt and Wanderlog both model trips this way |
| Add documents from camera, Photos, Files | Camera scan for passports/tickets is the primary reason to open the app at the border; users expect all three import paths | MEDIUM | VisionKit handles camera scan; PHPickerViewController for Photos; UIDocumentPickerViewController for Files app |
| View a document full-screen | Retrieving a passport scan at immigration is the single most critical on-trip moment | LOW | Pinch-to-zoom is required; support PDF and image formats |
| Rename and delete documents | Documents mis-named at import are a known pain point across all apps | LOW | Long-press or swipe context menu is the iOS convention |
| Packing list with categories | Every packing app (Packr, PackPoint, Packing List Checklist) uses categorized lists — toiletries, electronics, clothing etc. | LOW | Flat lists feel amateur; categories are the minimum bar |
| Check off and uncheck packing items | Core interaction of any checklist app | LOW | Swipe-to-check is the expected gesture in iOS packing apps (PackPoint, WhatToPack); tapping the row also acceptable |
| Add, edit, delete packing items and categories | Personalization is mandatory; canned lists are not sufficient for solo travelers | LOW | Inline editing preferred over modal; swipe-left reveals delete |
| Day-by-day chronological activity list | TripIt's killer feature and the standard mental model; users expect their itinerary grouped by date | LOW | Flat list sorted by date/time, grouped by day — no map or calendar view required in v1 |
| Activity with title, date/time, location, notes | Minimum fields expected by every itinerary app reviewed | LOW | Location is a text field only in v1; no map integration needed |
| Edit and delete an activity | Basic CRUD — any app missing this loses users immediately | LOW | — |
| Persist all data across app launches | SwiftData-backed storage; users expect nothing to disappear | LOW | Core requirement; any data loss is a critical bug |
| Offline access to all content | Travel app users are frequently without WiFi (on planes, at borders, in foreign airports); offline is a must, not a nice-to-have | LOW | v1 is local-only by design — this is naturally satisfied |

### Differentiators (Competitive Advantage)

Features that align with Travellify's core value and create meaningful separation from generic travel apps.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Per-trip document scoping | Documents live inside a specific trip, not in a global vault — users immediately know where to look during a trip | LOW | This is intentional architecture (per-trip scoping decision in PROJECT.md). TripIt and Wanderlog treat documents as an afterthought bolted onto bookings; Travellify makes it first-class |
| VisionKit camera scan for documents | Lets users scan a physical passport or paper confirmation at trip setup — faster than photographing from camera roll | MEDIUM | VisionKit's document scanner (VNDocumentCameraViewController) gives perspective correction and multi-page capture. Travel Document Vault and Passport.app do this well; most itinerary apps don't |
| Face ID / passcode lock on document access | A passport scan or e-ticket stored in a plain app is a trust problem; Face ID entry gate builds confidence | LOW | LocalAuthentication framework; opt-in per user; high trust impact for low implementation cost |
| Optional per-activity local notification | Let users set a reminder only for the activities that need one (tour start, airport pickup) — not a blanket alarm | LOW | UserNotifications; exactly the pattern in PROJECT.md; Tripsy and TripIt's reminders are tied to booking emails, not manual activities |
| "Today" view — activities for the current date | The on-trip use case is almost always "what am I doing today?" — a dedicated today tab removes all friction | LOW | Filter the day-by-day list to current date and show as the default landing view when a trip is active |
| Packing item progress indicator | A visible "12 of 23 packed" counter at the top of the list gives pre-departure confidence | LOW | Simple derived count from SwiftData; high perceived value for near-zero cost |
| Uncheck-all / reset packing list action | Reusable trip (same annual ski trip) needs a fast reset; also useful for "re-packing after checking in at hotel" | LOW | One action in context menu; Packing List & Daily Checklist app makes this its core UX — users actively ask for it |
| Multi-destination trip structure | A trip to "Japan" with stops in Tokyo → Osaka → Kyoto is the common case for modern travelers; single-destination is too limiting | LOW | The trip has a date range; destinations are sub-groupings inside it |

### Anti-Features (Deliberately NOT Build)

Features that are commonly requested or seen in competitors but create disproportionate complexity, maintenance burden, or scope drift for a v1 local-only app.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Document OCR / auto-categorization | Users want the app to read "PASSPORT" from a scan and auto-label it | Requires a CoreML pipeline or Vision framework text recognition pass, then classification logic; brittle on non-Latin scripts, glare, odd passport layouts | Manual rename is two taps; the pain is low vs the implementation complexity |
| Cloud sync / cross-device | Users expect their trip to show up on their iPad or Mac | Requires CloudKit entitlement, conflict resolution, offline merge strategy — triples the data layer complexity | Deferred to v2 where CloudKit + SwiftData migration is the clear path |
| Trip sharing / collaboration | Wanderlog's top differentiator; users traveling with family want it | Requires an account system, server, conflict resolution, and permissions model — none of which exist in v1 | Deferred to v3 per PROJECT.md; share via screenshot or AirDrop document export as stopgap |
| Email import / booking auto-detection | TripIt's flagship feature — forward a confirmation email and get a structured itinerary | Deep privacy implications (email access), requires either server-side parsing or MailKit entitlement; also produces incorrect entries that users then have to clean up | Manual activity creation is the v1 model; low-friction inline entry is the alternative |
| Map view for activities | Users assume a map — Wanderlog and Polarsteps both lead with it | Adds MapKit complexity, annotation management, and cluttered UI without validating the core list-based model first | Day-by-day list with tappable location strings that open Apple Maps (deep link) satisfies the need with near-zero cost |
| Calendar sync (EventKit) | Users want trip activities to appear in iOS Calendar | Bidirectional sync is complex; unidirectional export creates stale duplicates; users then edit the wrong source | Optional EventKit export per-activity is a v1.x addition; not in v1 |
| Budget tracking / expense log | Wanderlog and Tripsy both have this; users see it in competitors | Entirely separate domain (currency, categories, exchange rates, splitting); adds nav complexity for a feature orthogonal to the core value | Dedicated expense apps (Splitwise, Trail Wallet) do this better; don't compete |
| Weather integration | Users want forecast for each destination day | Requires WeatherKit entitlement + location permissions + async network call; breaks the offline-first trust | Local weather app is one swipe away; not Travellify's problem to solve |
| Trip templates / copy-from-past-trip lists | "I always pack the same things for ski trips" | Template management is its own data model; copying partially-checked lists creates confusion about state | Deferred explicitly in PROJECT.md; real usage will reveal which templates are wanted |
| iPad / Universal layout | Users with iPads want it | Split-view, multi-column navigation, and pointer support require a distinct layout pass; doubles layout testing scope | iPhone-only in v1 per PROJECT.md |
| Post-trip journaling / photo album | Polarsteps' core feature; users want to relive trips | Fundamentally different product direction (archive vs on-trip utility); competes with Notes, Day One, and Polarsteps | Let users export photos to their Camera Roll; Polarsteps handles the archive use case |
| AI itinerary generation | Polarsteps added this in summer 2025; Wanderlog and Layla.ai lead here | Requires API integration, significant prompt engineering, and user trust-building; also generates activities the user then has to edit | Manual entry in v1 validates whether users want AI assistance at all before building it |

---

## Feature Dependencies

```
Trip (name + date range)
    └── required by ──> Documents (scoped to trip)
    └── required by ──> Packing List (scoped to trip)
    └── required by ──> Activities (scoped to trip)
                            └── required by ──> Local Notifications (per-activity)

Document Import (camera/Photos/Files)
    └── enhances ──> Document View (full-screen)
                        └── enhances ──> Face ID Lock (optional gate)

Packing Item Check-off
    └── enhances ──> Progress Indicator (derived count)
    └── enhances ──> Uncheck-All / Reset Action

Day-by-Day Activity List
    └── enhances ──> "Today" View (filter current date)

Activity (title + date/time + location + notes)
    └── enhances ──> Photos on Activity (attach from Photos)
    └── enhances ──> Local Notification Reminder
```

### Dependency Notes

- **Trip is the root object:** Every other feature (documents, packing, activities) is meaningless without a trip to scope it to. Trip CRUD must ship first.
- **Document view requires document import:** Scanning is the entry point; the viewer is only useful once content exists.
- **"Today" view enhances the activity list but does not replace it:** The full day-by-day list is the foundation; "today" is a derived filter. Build the list first.
- **Local notifications require a dated activity:** Notification scheduling is meaningless without a date/time on the activity. Activities come first.
- **Face ID lock is additive to document view:** Implement document view first; Face ID is a trust layer on top, not a dependency.

---

## MVP Definition

### Launch With (v1)

| Priority | Feature | Why Essential |
|----------|---------|---------------|
| P1 | Trip creation (name + date range, multi-stop) | Root object — everything depends on it |
| P1 | Trip list and navigation | Users must browse and open trips |
| P1 | Document import (camera scan, Photos, Files) | The primary on-trip utility |
| P1 | Document full-screen view (PDF + image, pinch-zoom) | The moment that matters: passport at immigration |
| P1 | Document rename and delete | Without this, mis-labeled docs become permanent |
| P1 | Packing list with categories | Core companion feature expected by any travel app |
| P1 | Check-off / uncheck packing items (swipe gesture) | Core interaction; missing this makes the list useless |
| P1 | Add / edit / delete packing items and categories | Personalization is non-negotiable |
| P1 | Activity with title, date/time, location, notes, photos | The itinerary feature |
| P1 | Day-by-day chronological activity list | The itinerary view |
| P1 | Edit and delete activity | Basic CRUD |
| P1 | Optional local notification per activity | Low-cost, high-value; UserNotifications is already an iOS primitive |
| P1 | SwiftData persistence across launches | Foundational; any data loss is a critical bug |

### Add After Validation (v1.x)

- **"Today" view tab** — add once usage shows users open the app during active trips, not just during planning
- **Packing progress indicator (X of Y packed)** — add once packing list is validated as useful
- **Uncheck-all reset action** — add when users report wanting to reuse a list
- **Face ID / passcode lock on document tab** — add when user trust in document storage is confirmed
- **Activity photos attachment** — add after core activity CRUD is proven stable; PHPickerViewController is straightforward

### Future Consideration (v2+)

- **CloudKit sync** — v2 milestone per PROJECT.md; natural SwiftData migration path
- **Trip sharing / collaboration** — v3 per PROJECT.md; requires v2 account system
- **Calendar export (EventKit, one-way)** — v1.x or v2; low complexity, moderate value
- **Map view for activities** — v2 once list view is validated
- **Trip templates / copy-from-past-trip packing** — defer until real usage reveals patterns

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Trip creation + list | HIGH | LOW | P1 |
| Document import (camera/Photos/Files) | HIGH | MEDIUM | P1 |
| Document full-screen view | HIGH | LOW | P1 |
| Packing list with categories | HIGH | LOW | P1 |
| Packing check-off (swipe) | HIGH | LOW | P1 |
| Activity CRUD (day-by-day list) | HIGH | LOW | P1 |
| Local notification per activity | HIGH | LOW | P1 |
| Packing progress indicator | MEDIUM | LOW | P2 |
| "Today" view filter | MEDIUM | LOW | P2 |
| Uncheck-all packing reset | MEDIUM | LOW | P2 |
| Face ID document lock | MEDIUM | LOW | P2 |
| Activity photos | MEDIUM | LOW | P2 |
| Calendar export | MEDIUM | LOW | P2 |
| Map view for activities | MEDIUM | MEDIUM | P3 |
| Trip templates | MEDIUM | MEDIUM | P3 |
| CloudKit sync | HIGH | HIGH | P3 (v2) |
| AI itinerary generation | LOW | HIGH | P3 (v3) |

**Priority key:**
- P1: Must have for v1 launch
- P2: Add after v1 validation; low cost, meaningful improvement
- P3: Future milestone or v2+

---

## Competitor Feature Analysis

| Feature Area | TripIt | Wanderlog | Tripsy | Polarsteps | Packr / PackPoint | Travellify v1 |
|---|---|---|---|---|---|---|
| Document storage | None (bookings only) | None | Files app import, notes | None | None | Camera scan + Photos + Files — first-class |
| Packing list | None | None | None | None | Full-featured with categories | Categories + swipe check-off |
| Day-by-day itinerary | YES (from email) | YES (manual + map) | YES (manual) | GPS tracking | None | YES (manual, list only) |
| Offline access | Free tier | Pro only ($40/yr) | YES | Limited | YES | Always (local-only) |
| Activity reminders | Booking-based only | YES | YES | None | None | Per-activity, optional |
| Collaboration | YES (Pro) | YES (free) | YES | Social | Packr Premium | Not in v1 |
| Cloud sync | YES | YES | CloudKit | YES | Premium | Not in v1 |
| Map view | NO | YES — core feature | Apple Maps deep link | GPS route — core feature | NO | Not in v1; tappable location → Apple Maps |
| AI features | NO | Experimental | NO | YES (2025 release) | NO | Not in v1 |
| Platform | iOS, Android, Web | iOS, Android, Web | iOS, iPadOS, Mac, Watch | iOS, Android | iOS | iPhone only |
| Business model | Freemium ($49.99/yr Pro) | Freemium ($40-60/yr Pro) | Paid up-front | Freemium | One-time purchase | TBD |

**Key observation:** No competitor combines documents + packing + manual itinerary + offline-first in a single, iPhone-native, local-only app. TripIt does itinerary well but ignores documents and packing entirely. PackPoint / Packr do packing only. Travel Document Vault does documents only. Travellify's scoped-per-trip model for all three features is genuinely differentiated for the offline-first, solo-traveler use case.

---

## Sources

- [Wanderlog vs TripIt comparison (Wanderlog blog, 2024)](https://wanderlog.com/blog/2024/11/26/wanderlog-vs-tripit/)
- [Wanderlog vs TripIt — The Process Hacker](https://theprocesshacker.com/blog/wanderlog-vs-tripit)
- [TripIt Guide 2026 — Carly AI](https://www.usecarly.com/blog/tripit-alternative/)
- [Tripsy Review — MacStories](https://www.macstories.net/reviews/tripsy-review-the-ultimate-trip-planner-for-iphone-and-ipad/)
- [Tripsy Review 2025 — Wandrly](https://www.wandrly.app/reviews/tripsy)
- [Polarsteps Summer 2025 Release — Polarsteps News](https://news.polarsteps.com/news/polarsteps-summer-2025-release-is-here)
- [Travel Document Vault — AlternativeTo](https://alternativeto.net/software/travel-document-vault/about/)
- [PackPoint App Store listing](https://apps.apple.com/us/app/packpoint-travel-packing-list/id896337401)
- [Packr App Store listing](https://apps.apple.com/us/app/packr-travel-packing-list/id1208312901)
- [Best Packing List Apps 2026 — Smarter-ish](https://smarter-ish.com/best-packing-list-apps/)
- [Packing list best practices — CheckandPack](https://checkandpack.com/blog/top-checklist-apps-for-travelers-pack-smarter-travel-easier/)
- [Wanderlog offline access guide](https://wanderlog.com/blog/2024/10/15/how-to-ensure-your-travel-plans-are-accessible-offline/)

---
*Feature research for: iOS travel companion app (documents + packing + itinerary)*
*Researched: 2026-04-18*
