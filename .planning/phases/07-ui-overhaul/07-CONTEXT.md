# Phase 7: UI Overhaul - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning (sub-phase 7.1 Design Foundation first)

<domain>
## Phase Boundary

Phase 7 delivers a full visual redesign of every shipped screen in v1.0 (Trips, Documents, Packing, Activities, Notifications UI, edit sheets, empty/denied states) against designer-provided Figma mocks. No new functional requirements — visual/structural only; all Phase 1–6 requirements must continue to pass.

**In scope:** Typography, color, spacing, iconography, illustration system, tab bar introduction, liquid-glass button style, empty/populated state differentiation, asset pipeline from Figma.

**Out of scope:** New features, Settings screen content (v1.x), Activity Photos (v1.x), Face ID lock (removed), accessibility audit (can ride later), app icon replacement (user-owned).

**Figma file:** `https://www.figma.com/design/jLfc8jUHe465DkmibqqSjo/Travellify` (fileKey `jLfc8jUHe465DkmibqqSjo`)
</domain>

<decisions>
## Implementation Decisions

### Phase Structure & Cadence

- **D7-01: Decimal sub-phases per screen area.** Phase 7 is split into 7.1, 7.2, … sub-phases rather than one monolithic plan. Each sub-phase gets its own PLAN.md and SUMMARY.md under `.planning/phases/07-ui-overhaul/`. Sub-phases consume this shared `07-CONTEXT.md` instead of duplicating context.

- **D7-02: First sub-phase is Design Foundation (7.1), not a screen.** 7.1 ships shared primitives before any screen redesign touches the codebase:
  - Design tokens (Color, Typography, Spacing, CornerRadius) as a centralized token layer under `Travellify/DesignSystem/`
  - `TabBarRoot` view — a new root below `ContentView` introducing the 2-tab shell (Trips, Settings)
  - `LiquidGlassButton` component with variant(s) matching the Figma "Button - Liquid Glass - Text" spec (blue tint, pill shape, 40pt height, 17pt Medium text)
  - Asset-pipeline conventions: where illustrations live in `Assets.xcassets`, naming (e.g. `empty-state-trips`, `empty-state-documents`), how 1x/2x/3x are ingested
  - A `GlassEffect` view modifier abstraction that switches between native iOS 26 `.glassEffect()` and the iOS 17–25 material fallback (see D7-05)
  - No screen is migrated in 7.1 — only the shared plumbing and one smoke-test preview

- **D7-03: Sub-phase ordering (tentative, adjusted as designs land).**
  - 7.1 Design Foundation (tokens, tab bar shell, button, asset pipeline) — **can start now**
  - 7.2 Trips (empty state → populated list → edit sheet → detail) — **partially designed** (empty state delivered)
  - 7.3 Documents
  - 7.4 Packing
  - 7.5 Activities
  - 7.6 Notifications UI + shared sheets (priming, denied-state, reminder sections)

  Only 7.1 and 7.2 are actionable today. Later sub-phases unblock as Figma deliveries land.

### Tab Bar & Settings Placeholder

- **D7-04: Tab bar shell lands in 7.1 with disabled Settings tab.** The design shows a liquid-glass bottom tab bar with Trips (airplane) + Settings (gear) tabs. Since Settings content is deferred to v1.x, the Settings tab is rendered but tapping it shows a placeholder view: a centered illustration + title "Settings" + subtitle "Coming in a future update" (no CTA). The tab is visually **active** (not dimmed) — tap still switches tabs, just lands on a stub. This matches the design visually without shipping partial Settings work.
  - Routing refactor: current `ContentView` becomes the body of the Trips tab. A new `TabBarRoot` owns the `TabView` and hosts both tabs.
  - Deep-link routing (existing `AppState.PendingDeepLink.activity(UUID)` / `.trip(UUID)`) must continue to switch to the Trips tab before pushing onto that tab's NavigationStack.

### Liquid Glass Rendering

- **D7-05: Native iOS 26 APIs with iOS 17–25 material fallback.** Use `@available(iOS 26.0, *)` branches to call native `.glassEffect()` / related APIs. For iOS 17–25, fall back to `.ultraThinMaterial` + custom `mix-blend` overlays + subtle gradient to approximate the look. The abstraction lives in a single view modifier (`.liquidGlass()` or similar) so screens don't sprinkle `#available` checks.
  - Deployment target stays at iOS 17 (no bump). Older-iOS users get a slightly flatter glass look; newer-iOS users get the full effect.

### Illustration & Asset Strategy

- **D7-06: Exported PNG/SVG assets from Figma, pulled via Figma MCP on demand.** The three-card tilted illustration (notes + map-pin + calendar) and any future illustrations ship as raster assets in `Travellify/Assets.xcassets/EmptyStates.xcassets/<screen>/`. Pixel-perfect to Figma; no SwiftUI recomposition.
  - Designer does NOT hand-export ZIPs. When each screen design lands, the engineer (me) pulls assets through Figma MCP `get_design_context` and saves them as `Contents.json` + 1x/2x/3x PNGs following Apple's Image Set format.
  - Exception: simple icons that already exist as SF Symbols stay as SF Symbols (not raster).

### Create-Trip Affordance

- **D7-07: Nav-bar "+" kept for populated state, removed only for empty state.** The `+` toolbar button remains on `TripListView` when the trip list is non-empty (existing Phase 1 behavior). When the list is empty, the toolbar omits the `+`, and the centered "Create a trip" liquid-glass button from the empty-state design is the only create affordance. Same NewTrip sheet fires from either entry point.
  - This is a conditional toolbar: `if trips.isEmpty { /* no + */ } else { /* + */ }`.

### Claude's Discretion

- Exact material thickness / overlay opacity values for the iOS 17–25 glass fallback — match the Figma screenshot visually; no spec was provided.
- Internal file/folder layout under `Travellify/DesignSystem/` (e.g. `Tokens/`, `Components/`, `Modifiers/`) — pick what fits Swift conventions.
- Animation/transition choices between tabs, pushes, and sheets — default to iOS-native unless Figma specifies otherwise.
- Stub Settings placeholder content (icon choice, exact copy) — keep tone consistent with the rest of the app.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Figma Designs (live)
- `https://www.figma.com/design/jLfc8jUHe465DkmibqqSjo/Travellify` — full Travellify Figma file (fileKey `jLfc8jUHe465DkmibqqSjo`)
- Node `93:132` — TripListView empty state (first delivery, 2026-04-25). Fetch via `get_design_context(fileKey="jLfc8jUHe465DkmibqqSjo", nodeId="93:132")` or `get_screenshot` with same args.

### Apple HIG (per Figma component documentation fields)
- Tab Bar: https://developer.apple.com/design/human-interface-guidelines/tab-bars
- Navigation Bars: https://developer.apple.com/design/human-interface-guidelines/navigation-bars
- Buttons: https://developer.apple.com/design/human-interface-guidelines/buttons
- Home Indicator / full-screen: https://developer.apple.com/design/human-interface-guidelines/going-full-screen

### Project-Internal
- `.planning/ROADMAP.md` — Phase 7/8/9 re-scope (2026-04-24)
- `.planning/REQUIREMENTS.md` — v1.0 requirement set (no new requirements in Phase 7)
- `.planning/PROJECT.md` — stack constraints (SwiftUI + SwiftData, iOS 17+, Swift 6, local-first)
- `Travellify/ContentView.swift` — current root that becomes Trips-tab body
- `Travellify/App/AppDestination.swift`, `Travellify/App/AppState.swift` — deep-link routing that must survive the tab-bar refactor

### UI Deltas Running Log (created in 7.1)
- `.planning/phases/07-ui-overhaul/UI-DELTAS.md` — append an entry per Figma delivery; scoped to the sub-phase that consumes it.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Shared/ReminderFireDate.swift, Shared/NotificationScheduler.swift** — already actor/@MainActor structured, no UI coupling. Phase 7 does not touch these except potentially their surface in edit-sheet sections.
- **Features/Trips/TripListView.swift, TripDetailView.swift, TripEditSheet.swift** — Phase 7.2 targets; current SF-Symbol + system-color styling gets replaced with design-system tokens.
- **Features/Documents/EmptyDocumentsView.swift, Features/Packing/EmptyPackingListView.swift** — existing empty-state patterns that will be refactored to use a shared `EmptyStateView` primitive after 7.1 lands.

### Established Patterns
- `@Query`-driven lists with SwiftData-native `@Model` types — preserved. Only presentation changes.
- `AppDestination` enum + `NavigationStack(path:)` — still the push-target model; tab-bar refactor wraps this, does not replace it.
- `fullScreenCover` / `.sheet` usage — kept; sheet presentation patterns remain.

### Integration Points
- Root hand-off: `TravellifyApp.swift` → currently `ContentView`. 7.1 changes this to `TabBarRoot` which hosts two `NavigationStack`s (one per tab) and forwards deep-link `PendingDeepLink` to the Trips tab.
- Design tokens referenced from every feature view — requires a global import convention (or a `DesignTokens` namespace type).

</code_context>

<specifics>
## Specific Ideas

- First delivered design (Figma node 93:132, 2026-04-25) is the TripListView empty state. It contains the reference spec for: liquid-glass tab bar, liquid-glass pill button ("Create a trip"), large-title nav bar style, 144×144 3-card illustration, "No trips yet" / "Create your first trip to get started" copy, font styles (SF Pro Bold 22/26, SF Pro Regular 15/20, SF Pro Bold 34/41 for large titles).
- Liquid-glass tab bar spec from the same node: 2 tabs (Trips airplane icon + Settings gear icon), selected tab gets a `mix-blend-plus-lighter` tint pill, semi-transparent dark background with inner white gradient overlay.
- "Create a trip" CTA: blue #0091FF base, 40pt height, 6pt vertical / 20pt horizontal padding, 1000pt corner radius (fully rounded pill), 17pt SF Pro Medium white text, shadow `0px 8px 40px rgba(0,0,0,0.12)`.
- Empty-state copy locked: "No trips yet" (title) + "Create your first trip to get started" (subtitle).

</specifics>

<deferred>
## Deferred Ideas

- **Populated TripListView design** — designer delivers later; D7-07 locks the create-trip pattern but the overall populated-list row style is still open.
- **Settings screen content** — v1.x (Settings first, then Activity Photos per ROADMAP v1.0 re-scope).
- **Accessibility pass on the redesigned UI** — rides in Phase 8 UI Fixes or Phase 9 Testing as a separate track; not a Phase 7 deliverable.
- **Illustration/icon design system** — no reusable "illustration component" primitive in 7.1; each illustration is just a raster asset. If enough illustrations accumulate to justify a shared wrapper, add later.
- **Dark-mode-only vs light-mode support** — Figma delivery is dark mode. The app today is already dark-dominant per Phase 1 styling. Revisit once we see a light-mode Figma variant, otherwise Phase 7 ships dark-only.
- **Haptics / motion** — not specified in Figma yet; defer until designer calls it out.
- **Tab-bar deep-link grammar for future Settings tab** — stub route only; real deep-link surface lands with v1.x Settings.

</deferred>

---

*Phase: 07-ui-overhaul*
*Context gathered: 2026-04-25*
