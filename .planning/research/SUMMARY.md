# Project Research Summary

**Project:** Travellify
**Domain:** Native iOS travel companion app (documents + packing + itinerary)
**Researched:** 2026-04-18
**Confidence:** HIGH

## Executive Summary

Travellify is a local-first iPhone app that unifies three distinct travel tools — document storage (passport scans, tickets), packing checklist, and day-by-day activity itinerary — all scoped under a single Trip primitive. No competitor combines all three in a local-only, iPhone-native package. TripIt and Wanderlog own itinerary but ignore documents and packing entirely; Packr and PackPoint do packing only; Travel Document Vault handles documents only. This combination is a genuine gap for solo travelers who need offline reliability over collaboration features.

The recommended approach is a fully Apple-native stack: Swift 6, SwiftUI, SwiftData, and zero third-party dependencies in v1. Every architecture and model decision must be made with CloudKit sync (v2) in mind — the cost of getting this wrong now is a full schema rewrite before v2 can ship. This means VersionedSchema from the first commit, all relationship inverses optional, no uniqueness constraints, and all binary data (PDFs, photos) stored as file paths on disk rather than as Data blobs in SwiftData. Following these rules adds roughly 30–50 lines of boilerplate upfront and avoids weeks of migration work later.

The dominant risk cluster is SwiftData correctness: silent cascade delete failures, iOS 18 cross-context sync regression, and main-thread blocking during document import are all confirmed bugs or known pitfalls with specific workarounds. None of them are blockers if the architecture is set up correctly in Phase 1. The secondary risk is scope creep — cloud sync, map views, AI generation, and collaboration are all natural "next features" that must be deferred until core local-only value is proven.

---

## Key Findings

### Recommended Stack

The entire stack ships with the iOS SDK. There are no recommended third-party libraries for v1. Swift 6 strict concurrency catches data-race bugs at compile time, which is important because SwiftData's threading model is subtle — the main ModelContext is `@MainActor`-bound and heavy operations (file writes, bulk imports) must run on a `@ModelActor` background actor. SwiftUI's `@Observable` macro (iOS 17+) replaces ObservableObject and Combine entirely for this app's needs.

**Core technologies:**
- Swift 6 (language mode): primary language — strict concurrency catches SwiftData threading bugs at compile time
- SwiftUI (iOS 17+): all UI — declarative, pairs directly with SwiftData `@Query` and `@Observable`
- SwiftData (iOS 17+): local persistence — first-party ORM with `@Query` macro and single-flag CloudKit migration path
- Xcode 16.x: build environment — required for Swift 6 language mode and iOS 18 SDK
- VisionKit (`VNDocumentCameraViewController`): camera document scanning — wrapped via `UIViewControllerRepresentable`
- PhotosUI (`PhotosPicker`): photo import — pure SwiftUI API, iOS 16+, no permission prompt before picker
- UserNotifications: per-activity local reminders — calendar trigger, request permission lazily
- Swift Testing: unit/integration tests — Xcode 16, parallel execution, async-native

**Critical version floor:** iOS 17.0 minimum. SwiftData, `@Observable`, and SwiftUI PhotosPicker all require iOS 17.

### Expected Features

**Must have (v1 table stakes + differentiators):**
- Trip creation with name, date range, multi-destination support — root object; everything else depends on it
- Trip list browse and navigation — basic app shell
- Document import via camera scan (VisionKit), Photos, and Files app — the primary on-trip utility
- Document full-screen view (PDF + image, pinch-zoom) — the single most critical moment: passport at immigration
- Document rename and delete — without this, mis-labeled scans become permanent
- Packing list with categories and swipe check-off — expected by any travel app; flat lists feel amateur
- Add / edit / delete packing items and categories — personalization is non-negotiable
- Activity CRUD with title, date/time, location, notes, photos — the itinerary feature
- Day-by-day chronological activity list — the standard mental model
- Optional per-activity local notification reminder — low-cost, high-value
- SwiftData persistence across launches — foundational; any data loss is a critical bug

**Should have (v1.x, add after validation):**
- "Today" view — filter activity list to current date
- Packing progress indicator (X of Y packed)
- Uncheck-all / reset packing list
- Face ID / passcode lock on document tab

**Defer (v2+):**
- CloudKit sync — natural SwiftData migration path; design for it now, ship it later
- Map view for activities, calendar export, trip collaboration, AI itinerary generation

**Key competitive observation:** No competitor combines documents + packing + manual itinerary + offline-first in a single iPhone-native local-only app. This gap is Travellify's market position.

### Architecture Approach

The app uses a four-layer architecture: SwiftUI views consume `@Observable` ViewModels that call into SwiftData (via `ModelContext` for writes, `@Query` for reads) and a thin Services layer (FileStorageService, NotificationService, ScanImportService). All binary content — PDFs, images, activity photos — lives on disk under `~/Documents/Travellify/` with only relative paths stored in SwiftData models. Trip is the root aggregate; all models cascade-delete from it. Navigation uses `NavigationStack` with a typed `AppDestination` enum.

**Major components:**
1. SwiftData Models (Trip, Destination, TravelDocument, PackingCategory, PackingItem, Activity) — all wrapped in `TravellifySchemaV1: VersionedSchema` from day one; all relationship inverses optional for CloudKit readiness
2. FileStorageService — stateless struct; owns the `~/Documents/Travellify/` directory tree; called from ViewModels, returns relative paths stored in SwiftData
3. NotificationService — stateless struct wrapping `UNUserNotificationCenter`; schedules, cancels, and reschedules calendar-triggered notifications; enforces 64-cap via scheduling manager
4. ScanImportService — `UIViewControllerRepresentable` wrapper for VisionKit; coordinator holds scan state in an `@Observable` class to survive SwiftUI view re-renders
5. NavigationStack + typed `AppDestination` enum — safe path restoration with `try/catch` fallback

### Critical Pitfalls

1. **No VersionedSchema from day one** — first model change after shipping crashes all existing users. Wrap every `@Model` in `TravellifySchemaV1: VersionedSchema` on the first commit. Recovery after shipping without it requires a two-step release with high data loss risk.

2. **Storing binary data (images, PDFs) as `Data` on SwiftData models** — even moderate document lists cause main-thread stalls and memory kills on real devices. Store only relative file paths as `String`; write files via FileStorageService. CloudKit's 1 MB field size limit also blocks this approach for v2.

3. **Blocking the main actor during document import** — VisionKit and PhotosUI hand off data on the main actor. Use a `@ModelActor` background actor for all import work; post the inserted `PersistentIdentifier` back to the main actor for UI refresh.

4. **iOS 18 cross-context sync regression** — confirmed Apple bug: `@ModelActor` saves do not automatically update the main-actor `@Query`. Test every import flow on a physical iOS 18 device. Mitigation: explicit `NotificationCenter` broadcast of `NSManagedObjectContextDidSave` after each background save.

5. **CloudKit-breaking model decisions made in v1** — `@Attribute(.unique)`, non-optional properties without defaults, and `.deny` delete rules block CloudKit sync in v2 with no lightweight migration path. Design all properties as `var name: String = ""` from day one.

6. **64 pending local notification cap** — iOS silently discards notifications past the 64th with no API signal. Build a scheduling manager in Phase 5 that queries `pendingNotificationRequests()` before scheduling and reschedules the 64 soonest on `willEnterForeground`.

7. **NavigationPath decode crash after model change** — store only lightweight route identifiers (UUIDs), not full model snapshots. Wrap all path decoding in `try/catch` with empty-path fallback.

---

## Implications for Roadmap

Based on the dependency graph from FEATURES.md and the build order from ARCHITECTURE.md, a 7-phase structure is indicated.

### Phase 1: Foundation — Data Model + Navigation + Trip CRUD

**Rationale:** Trip is the root object; no other feature is meaningful without it. Schema versioning and navigation architecture must also be established here — retrofitting them is the highest-cost pitfall in the research.

**Delivers:** Working app with trip creation, trip list, and trip detail scaffold. In-memory schema versioning, NavigationStack with typed destinations.

**Addresses:** Trip creation (name + date range, multi-stop), trip list browse, trip navigation — all P1.

**Avoids:**
- Pitfall 1: VersionedSchema before any model ships
- Pitfall 5: Cascade delete rules at model definition time
- Pitfall 6: CloudKit-safe model design from first commit
- Pitfall 10: Safe NavigationPath restoration established here

**Research flag:** Standard patterns — skip `/gsd-research-phase`.

---

### Phase 2: Documents Feature

**Rationale:** Documents are the primary on-trip utility and Travellify's core differentiator. This phase also establishes FileStorageService and the `@ModelActor` import pattern — both reused by Activity photos in Phase 6. De-risking these patterns early reduces late-phase surprises.

**Delivers:** Full document import (camera scan, Photos, Files), full-screen viewer (PDF + image, pinch-zoom), rename and delete.

**Addresses:** Document import (camera/Photos/Files), document full-screen view, document rename/delete — all P1.

**Avoids:**
- Pitfall 2: File-path-only storage; no `Data` blobs on models
- Pitfall 3: `@ModelActor` background import; no main-thread file writes
- Pitfall 4: iOS 18 cross-context sync tested on physical device with explicit merge
- Pitfall 8: Dedicated `ScannerCoordinator`; scan state in `@Observable` outside the representable

**Research flag:** Needs `/gsd-research-phase` — VisionKit coordinator lifecycle and iOS 18 `@ModelActor` merge behavior are confirmed bug territories that need specific patterns pinned before implementation.

---

### Phase 3: Packing List Feature

**Rationale:** Simpler than Activities (no service dependencies, no file I/O). Validates the in-trip tab navigation pattern before the more complex Activity feature is added.

**Delivers:** Categorized packing list, swipe check-off / uncheck, add / edit / delete items and categories.

**Addresses:** Packing list with categories, check-off gesture, item/category CRUD — all P1.

**Research flag:** Standard patterns — skip `/gsd-research-phase`.

---

### Phase 4: Activities Feature (Core, No Photos or Notifications)

**Rationale:** Activity CRUD and day-by-day list are built first without notifications or photos to keep scope bounded. Stable data model is prerequisite for notification scheduling in Phase 5.

**Delivers:** Activity creation (title, date/time, location text, notes), day-by-day grouped list, edit and delete.

**Addresses:** Activity CRUD, day-by-day activity list — all P1.

**Research flag:** Standard patterns — skip `/gsd-research-phase`.

---

### Phase 5: Notifications

**Rationale:** Dedicated phase after Activity data model is stable. Notification scheduling bugs during model development are disproportionately disruptive — clean separation is the professional pattern.

**Delivers:** Per-activity notification toggle, NotificationService with full lifecycle (schedule / cancel / reschedule), 64-cap scheduling manager, lazy permission request with pre-permission prompt.

**Addresses:** Optional local notification per activity — P1.

**Avoids:**
- Pitfall 7: 64-pending-notification scheduling manager built here from the start
- Architecture anti-pattern 3: no mass re-schedule on app launch

**Research flag:** Standard patterns — skip `/gsd-research-phase`.

---

### Phase 6: Activity Photos

**Rationale:** Layers on top of both FileStorageService (proven in Phase 2) and Activity models (proven in Phase 4). Placed last among core features because it is the highest-memory-risk step and benefits from a mature base.

**Delivers:** PHPickerViewController multi-photo selection, immediate downsampling (1920 px max, serial processing), thumbnail generation (300 px), photo grid in ActivityDetailView, file cleanup on activity delete.

**Addresses:** Activity photos — P1.

**Avoids:**
- Pitfall 9: Immediate downsample after `loadTransferable`; peak RSS below 100 MB during 5-photo selection

**Research flag:** Standard patterns — memory-efficient PHPickerViewController patterns are well-documented. Skip `/gsd-research-phase`.

---

### Phase 7: Polish + TestFlight

**Rationale:** Empty states, error handling, haptics, and accessibility deferred until features are stable to avoid reworking UI that changes during development.

**Delivers:** Empty states for all list views, import error alerts, destructive action confirmations (trip delete), accessibility labels, TestFlight build. Addresses UX pitfalls: filename prompt after scan, scroll position on packing toggle, import progress feedback, stale notification cleanup.

**Research flag:** Standard patterns — skip `/gsd-research-phase`.

---

### Phase Ordering Rationale

- Trip must come first because it is the root aggregate and the schema versioning decision made here affects every subsequent model
- Documents before Activities because FileStorageService de-risked in Phase 2 is reused for photos in Phase 6 — catching edge cases (path construction, security-scoped resource access) before they silently affect the more complex Activity photo pipeline
- Packing before Activities because packing has no service dependencies and validates in-trip tab navigation with a simpler feature
- Notifications as a dedicated phase because scheduling bugs during model development are disproportionately disruptive
- Photos last because they combine the highest memory risk with the most service surface area

---

### Research Flags

**Needs `/gsd-research-phase` during planning:**
- Phase 2 (Documents): VisionKit `UIViewControllerRepresentable` coordinator lifecycle and iOS 18 `@ModelActor`-to-main-context merge pattern. Confirmed bug territories with workarounds that need to be pinned to exact iOS version behavior before implementation.

**Standard patterns — skip research phase:**
- Phase 1 (Foundation): SwiftData VersionedSchema, NavigationStack, Trip CRUD
- Phase 3 (Packing): Checklist UI, SwiftData CRUD
- Phase 4 (Activities): Day-grouped list, Activity CRUD
- Phase 5 (Notifications): UNCalendarNotificationTrigger, 64-cap manager
- Phase 6 (Photos): PHPickerViewController memory-efficient pattern
- Phase 7 (Polish): Empty states, alerts, haptics

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All decisions verified against Apple official documentation, WWDC 2024/2025 sessions, and 2025-2026 community articles. Zero third-party libraries — no dependency quality uncertainty. |
| Features | HIGH | Competitor analysis covers TripIt, Wanderlog, Tripsy, Polarsteps, Packr, PackPoint, Travel Document Vault. App Store listings and review sources cross-referenced. |
| Architecture | HIGH | Model design confirmed against official SwiftData/CloudKit docs. File storage pattern, NavigationStack approach, and service boundaries cross-referenced with Apple documentation and community post-mortems. |
| Pitfalls | HIGH | Critical pitfalls confirmed via Apple Developer Forums threads, official docs, and named community post-mortems. iOS 18 regression and cascade delete bug both confirmed in filed forum threads. |

**Overall confidence: HIGH**

### Gaps to Address

- **`@Attribute(.externalStorage)` vs. file-path-only for CloudKit v2:** Compatibility of `.externalStorage` with CloudKit sync is not definitively documented. Architecture recommends file-path-only storage with CKAsset-based swap in v2. Validate against CloudKit `CKSyncEngine` documentation before Phase 2 implementation begins.

- **PDF rendering in document viewer:** PDFKit does not have a native SwiftUI component. The exact `UIViewRepresentable` integration pattern for lazy page rendering should be confirmed during Phase 2 planning.

- **Business model:** TBD in PROJECT.md. Does not affect v1 technical decisions but should be resolved before TestFlight to determine whether StoreKit scaffolding belongs in Phase 7.

---

## Sources

### Primary (HIGH confidence)

- Apple Developer Documentation — SwiftData `@Model`, `VersionedSchema`, `SchemaMigrationPlan`, `@Relationship` deleteRule, `ModelContainer`
- Apple Developer Documentation — VisionKit, PhotosUI `PhotosPicker`, UserNotifications, NavigationStack
- WWDC25: SwiftData — Dive into inheritance and schema migration (session 291)
- WWDC24: What's new in SwiftData (session 10137)
- fatbobman.com — Key Considerations Before Using SwiftData; Designing Models for CloudKit Sync; Concurrent Programming in SwiftData
- AzamSharp — If You Are Not Versioning Your SwiftData Schema (2026)
- Hacking with Swift — SwiftData VersionedSchema migration, unit testing SwiftData, CloudKit iCloud sync
- Apple Developer Forums — iOS 18 ModelContext cross-context sync regression (thread 757521); SwiftData cascade delete bug (thread 740649); 64 pending notification limit (thread 811171)

### Secondary (MEDIUM confidence)

- AzamSharp — SwiftData Architecture Patterns and Practices (2025, verified against Apple docs)
- matteomanferdini.com — SwiftData MVVM patterns
- Jacob Bartlett — High Performance SwiftData Apps
- Christian Selig — PHPickerViewController memory-efficient image loading (2020, pattern confirmed applicable to SwiftUI PhotosPicker)
- Wanderlog, TripIt, MacStories, Polarsteps competitor analysis sources

### Tertiary (MEDIUM-LOW confidence)

- Medium/@jpmtech — SwiftData large file storage (pattern cross-checked against official docs)
- Infosys Digital Experience — Swift Testing vs XCTest comparison (verified against Apple docs)
- Tuist blog — project generation context (used only to confirm single-module apps do not benefit)

---
*Research completed: 2026-04-18*
*Ready for roadmap: yes*
