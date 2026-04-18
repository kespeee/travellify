# Phase 1 Context: Foundation + Trips

**Phase:** 01-foundation-trips
**Requirements:** FOUND-01, FOUND-02, FOUND-03, TRIP-01..06
**Discussed:** 2026-04-19
**Supersedes:** nothing (first phase)

## Upstream Artifacts Loaded

- `.planning/PROJECT.md` — product charter, constraints (SwiftUI + SwiftData, iOS 17+, iPhone-only, local-only v1)
- `.planning/REQUIREMENTS.md` — 33 v1 reqs; Phase 1 owns 9
- `.planning/ROADMAP.md` — success criteria locked
- `.planning/research/STACK.md` / `FEATURES.md` / `ARCHITECTURE.md` / `PITFALLS.md` — tech stack + CloudKit rules
- `.planning/phases/01-foundation-trips/01-UI-SPEC.md` — design contract (APPROVED 6/6)

## Decisions

### D1 — Destination is a separate `@Model` with an ordered Trip↔Destination relationship

Multi-stop itineraries need per-stop identity (names editable individually, reorderable, likely per-destination notes/dates in v2). An inline `[String]` on Trip would block that path.

- `Trip` has `destinations: [Destination]` (optional inverse, no `.unique`, no `.deny`).
- `Destination` has `trip: Trip?` inverse (CloudKit rule: inverse must be optional).
- Order persisted via an explicit `sortIndex: Int` on Destination (SwiftData relationships are set-semantic — ordering is NOT preserved by array position across fetches).
- Cascade: Trip delete cascades to Destinations (`.cascade` rule at Trip level).
- Identity: every model has `var id: UUID = UUID()` (natural ID; CloudKit-safe).

### D2 — Cascade relationships for Phase 2+ content declared now (optional, empty arrays)

Declaring `documents: [Document]?`, `packingItems: [PackingItem]?`, `activities: [Activity]?` as optional empty collections in Phase 1's Trip model avoids a SwiftData migration when Phase 2+ lands. Empty collections cost nothing at runtime and keep the `VersionedSchema` stable longer.

**Implication:** Phase 1 must also introduce placeholder `@Model` types for `Document`, `PackingItem`, `Activity` — minimal shape (just `id`, `trip` inverse), deferred fields added in their own phases via `MigrationPlan`.

**Alternative considered:** add relationships lazily per phase. Rejected because every phase would then ship a schema migration just to register a new relationship, inflating migration count from 0 → 4.

### D3 — Trip list uses two sections: **Upcoming** (end ≥ today, asc by start) + **Past** (end < today, desc by start)

Matches on-trip companion value — the trip you need is always near the top. SwiftUI `Section` headers (SF-Symbol-less, .headline weight). Sections hidden when empty (no "No upcoming trips" header over a present Past list).

Implementation note: two separate `@Query` predicates or one query + in-memory partition. Researcher to decide — `@Query` with computed predicate has worked since iOS 17 but in-memory split is simpler for small N (<~200 trips realistic).

### D4 — Trip dates are calendar days (no time component, timezone-independent)

Trip start/end are conceptually dates, not moments: "Rome, May 10–18" doesn't change because the user flew through a timezone. Activity times (Phase 4) are full `Date` values where timezone matters.

- Stored as `Date` but normalized to start-of-day in the user's **current** calendar at the time of save.
- `DatePicker` uses `.date` (not `.dateAndHourAndMinute`) mode — already locked in UI-SPEC.
- Validation: `endDate >= startDate` (equality allowed — single-day trips).

### D5 — Validation: inline disabled Save button (no alerts)

- Save button in Create/Edit sheet disabled until: name non-empty (trimmed), endDate ≥ startDate, at least one destination added.
- No error alerts for validation — just a dimmed button. Matches "Clean & native" vibe.
- Duplicate destination names allowed within one trip (user may intentionally re-visit a city).

### D6 — `PreviewContainer` helper in a DEBUG-gated file

A single `PreviewContainer.swift` (wrapped in `#if DEBUG`) exposes an in-memory `ModelContainer` seeded with 2–3 sample trips + destinations. All `#Preview` macros consume it. Avoids per-view ad-hoc preview setup and keeps seed data out of the release binary.

### D7 — Xcode project scaffolded via command-line during Phase 1 execution

User chose command-line scaffolding. Plan:
- Use a minimal hand-written `project.pbxproj` + `Travellify.xcodeproj` tree, not `xcodegen` (no extra tool dependency). Template from a vanilla `File > New > iOS App` reference then strip to essentials.
- First task in Phase 1: "Scaffold Xcode project" — creates `Travellify.xcodeproj`, `Travellify/TravellifyApp.swift`, `Travellify/Assets.xcassets/`, `Travellify/Info.plist`-equivalent build settings.
- Deployment target: iOS 17.0. Bundle ID: `com.kespeee.travellify` (user can rename later in Signing & Capabilities).
- Swift language mode: 6. Swift Testing target added from day 1.
- **Fallback:** if `xcodebuild -list` can't open the generated project cleanly, planner/executor should pivot to "user creates project in Xcode, then I fill files" — flag in the plan as a checkpoint.

### D8 — Architecture: SwiftUI views + `@Observable` view-local state, no MVVM layer in v1

Stock SwiftUI + SwiftData. No separate ViewModel classes — `@Query` + `@Bindable` directly in views is the Apple-endorsed pattern and matches the clean/native vibe. If a view grows >150 lines or a non-trivial state machine appears, extract an `@Observable` into the same file. No protocol-oriented repository wrapping SwiftData.

### D9 — Navigation: single `NavigationStack` with typed `AppDestination` enum, sheets for create/edit

Already locked in UI-SPEC; restated here for planner reference.

```swift
enum AppDestination: Hashable {
    case tripDetail(Trip.ID)
}
```

- Root: `TripListView` inside `NavigationStack(path:)`.
- Row tap: push `.tripDetail(id)`.
- "+" toolbar: presents `TripEditSheet` (`.sheet`) — sheet inside NavigationStack pattern.
- Detail "Edit" pencil: presents same `TripEditSheet` in edit mode.

## Non-Decisions (locked by upstream, restated for planner)

- Swift 6 strict concurrency mode.
- SwiftData with `VersionedSchema` from commit 1 (`SchemaV1` enum + `Trip.self`, `Destination.self` inside it).
- No `@Attribute(.unique)`, no `.deny` delete rules, no `Data` blobs on models.
- Swift Testing for unit tests; XCTest reserved for UI tests (none in Phase 1).
- `ModelContainer` injected at `App` entry point via `.modelContainer(for: [Trip.self, Destination.self, Document.self, PackingItem.self, Activity.self])`.

## Open Questions for Researcher

1. Should Phase 1's placeholder `Document` / `PackingItem` / `Activity` models live in separate files under `Models/` now, or one `SchemaV1.swift` file? Recommend file-per-model; confirm.
2. `@Query` filtered by computed date predicate on iOS 17 vs 18 — any gotchas for the Upcoming/Past partitioning?
3. Ordered destinations: `sortIndex: Int` maintained manually on insert/reorder vs SwiftData's (private) ordered-relationship support — verify current best practice.
4. Minimal `project.pbxproj` template that `xcodebuild build` accepts cleanly on Xcode 16 — any known-good reference repos?

## Out of Scope for Phase 1

- Any Document / Packing / Activity UI or CRUD (phases 2–7 own those).
- iCloud/CloudKit wiring (v2 milestone). Schema is CloudKit-safe; container is local-only.
- Face ID lock (DOC-08 in Phase 6).
- Settings screen (no settings needed yet).
- Empty-state polish per phase 6 — a minimal empty state is in UI-SPEC but broader polish waits.
- Localization / i18n.

## Downstream Handoff

**To researcher:** resolve the four Open Questions above; produce RESEARCH.md covering (a) SwiftData VersionedSchema bootstrap for a multi-model app, (b) ordered-relationship patterns, (c) computed `@Query` predicate for date-based partitioning, (d) a working minimal `project.pbxproj` template or clear command-line scaffolding path.

**To planner:** use decisions D1–D9 as locked constraints. Task breakdown should start with D7 (scaffold project) before any Swift file is written.
