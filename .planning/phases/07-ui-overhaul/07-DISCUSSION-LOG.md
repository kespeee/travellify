# Phase 7: UI Overhaul - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 07-ui-overhaul
**Areas discussed:** Cadence, Tab bar, Illustration, Glass rendering, Foundation, Create CTA, Asset pipeline

---

## Cadence (phase structure)

| Option | Description | Selected |
|--------|-------------|----------|
| Scratchpad + one big plan | Running UI-DELTAS.md; single multi-wave PLAN once most designs arrive | |
| Decimal sub-phases per screen area | 7.1 Trips, 7.2 Documents, ... each with its own discuss/plan/execute | ✓ |
| Single plan, start now | Plan Phase 7 with TripListView Wave 1, add waves as designs arrive | |

**User's choice:** Decimal sub-phases per screen area.
**Notes:** Later refined to: 7.1 = Design Foundation (shared primitives), 7.2 = Trips, 7.3 = Documents, 7.4 = Packing, 7.5 = Activities, 7.6 = Notifications UI + shared sheets.

---

## Tab bar / Settings placeholder

| Option | Description | Selected |
|--------|-------------|----------|
| Shell with disabled Settings tab (Recommended) | Tab bar + both tabs; Settings routes to "Coming in v1.x" stub | ✓ |
| Trips tab only | Only Trips tab until v1.x Settings lands | |
| No tab bar yet | Keep NavigationStack root; defer tab bar to v1.x | |

**User's choice:** Shell with disabled Settings tab.
**Notes:** Settings tab is visually active (not dimmed) — tap switches tabs but lands on a stub view with centered placeholder copy. Deep-link routing must survive the tab-bar refactor.

---

## Illustration strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Native SwiftUI composition (Recommended) | ZStack of RoundedRectangle cards, SF Symbols, rotations | |
| Exported PNG/SVG assets from Figma | Raster assets at 1x/2x/3x in Assets.xcassets | ✓ |
| Hybrid (PNG backdrop + SwiftUI text/symbols) | PNG texture + SwiftUI-drawn date text and pin | |

**User's choice:** Exported PNG/SVG assets from Figma.
**Notes:** Paired with asset-pipeline decision below — assets pulled via Figma MCP on demand, not designer-delivered ZIPs. Exception: SF Symbols stay as SF Symbols.

---

## Liquid Glass rendering strategy

| Option | Description | Selected |
|--------|-------------|----------|
| iOS 26+ only, fall back to materials (Recommended) | Native `.glassEffect()` on iOS 26+; `.ultraThinMaterial` + overlays on iOS 17–25 | ✓ |
| Hand-rolled approximation on iOS 17+ | Uniform custom look across all supported iOS | |
| Raise minimum deployment target to iOS 26 | Cleanest look; cuts off older-iOS users | |

**User's choice:** iOS 26+ only, fall back to materials.
**Notes:** Deployment target stays iOS 17. Single `.liquidGlass()` view modifier abstracts the branch so feature code doesn't sprinkle `#available` checks.

---

## Foundation scope (first sub-phase)

| Option | Description | Selected |
|--------|-------------|----------|
| 7.1 = Design Foundation (Recommended) | Tokens, tab bar shell, button, asset pipeline — no screens yet | ✓ |
| 7.1 = Trips | Jump directly into Trips; extract primitives inline | |
| Hybrid: 7.1 scopes tokens + tab bar only; 7.2 starts Trips | Tiny first sub-phase | |

**User's choice:** 7.1 = Design Foundation.
**Notes:** Prevents style forking. 7.1 ships Color/Typography/Spacing/CornerRadius tokens, `TabBarRoot`, `LiquidGlassButton`, `.liquidGlass()` modifier, and asset-pipeline conventions — plus a smoke-test preview. Zero screens migrated in 7.1.

---

## Create-trip affordance in populated state

| Option | Description | Selected |
|--------|-------------|----------|
| Wait for designer to show populated state | Park the decision | |
| Floating liquid-glass CTA above tab bar | Persistent pill above tab bar | |
| Nav bar gear + compose icon | Nav bar keeps top-right gear + compose icon | |
| **Other (user freeform)** | Remove "+" in empty state, show "+" in populated state | ✓ |

**User's choice:** "Remove '+' in empty state, show '+' in populated state."
**Notes:** Toolbar is conditional: empty → no "+" (centered liquid-glass CTA is the only path); populated → nav-bar "+" stays (existing Phase 1 behavior). Same NewTrip sheet fires from either entry point.

---

## Asset pipeline

| Option | Description | Selected |
|--------|-------------|----------|
| Figma MCP export on demand (Recommended) | Engineer pulls assets via `get_design_context` per delivery | ✓ |
| Designer exports a ZIP, I import it | Designer hands off bundles | |
| Single SF Symbol + custom shapes where possible | Minimize raster assets | |

**User's choice:** Figma MCP export on demand.
**Notes:** Designer does not hand-export. Assets land in `Travellify/Assets.xcassets/EmptyStates.xcassets/<screen>/` as 1x/2x/3x PNGs.

---

## Claude's Discretion

- Exact material thickness / overlay opacity for iOS 17–25 glass fallback (match Figma screenshot visually)
- File layout under `Travellify/DesignSystem/`
- Animation/transition choices (default: iOS-native)
- Stub Settings placeholder content (icon + exact copy)

## Deferred Ideas

- Populated TripListView design (awaits designer)
- Settings screen content (v1.x)
- Accessibility pass (Phase 8 or 9)
- Illustration-component primitive (only if enough illustrations accumulate)
- Light-mode support (dark-only until designer delivers light variant)
- Haptics / motion (not specified in Figma)
- Tab-bar deep-link grammar for future Settings tab (v1.x)
