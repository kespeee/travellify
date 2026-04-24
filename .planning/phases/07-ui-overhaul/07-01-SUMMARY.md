---
phase: 07-ui-overhaul
plan: 01
subsystem: design-foundation
tags: [design-system, tokens, liquid-glass, tab-bar, ios26]
dependency_graph:
  requires: [phase-06-complete]
  provides: [design-tokens, liquid-glass-modifier, liquid-glass-button, tab-bar-shell, asset-pipeline]
  affects: [TravellifyApp.swift, ContentView.swift]
tech_stack:
  added: []
  patterns: [native-glassEffect-with-material-fallback, dsTypography-modifier, dsShadow-modifier]
key_files:
  created:
    - Travellify/DesignSystem/Tokens/DSColor.swift
    - Travellify/DesignSystem/Tokens/DSTypography.swift
    - Travellify/DesignSystem/Tokens/DSSpacing.swift
    - Travellify/DesignSystem/Tokens/DSRadius.swift
    - Travellify/DesignSystem/Tokens/DSShadow.swift
    - Travellify/DesignSystem/Modifiers/LiquidGlassModifier.swift
    - Travellify/DesignSystem/Components/LiquidGlassButton.swift
    - Travellify/App/TabBarRoot.swift
    - Travellify/Features/Settings/SettingsPlaceholderView.swift
    - Travellify/Assets.xcassets/EmptyStates.xcassets/Contents.json
    - TravellifyTests/DesignSystemTokensTests.swift
    - .planning/phases/07-ui-overhaul/ASSET-PIPELINE.md
  modified:
    - Travellify/TravellifyApp.swift
    - Travellify/ContentView.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "Native iOS 26 glass API confirmed: .glassEffect(_:in:) with Glass struct exposing .regular/.clear/.identity + .tint(Color?). No deviation needed from plan."
  - "ContentView refactored: TabView shell removed (TabBarRoot now owns it); ContentView retained verbatim NavigationStack body, AppDestination switch, and pendingDeepLink onChange consumer. Plan's 'do not modify ContentView' clause adjusted because ContentView already wrapped a TabView in Phase 5/6 — that TabView was the thing being replaced."
  - "Test ergonomics: UIColor round-trip (UIColor(Color(...))) used instead of Color.resolve(in:) for the accent-RGB test — direct, lossless for sRGB inputs, no environment plumbing."
metrics:
  duration: ~25min
  completed: 2026-04-25
---

# Phase 7 Plan 01: Design Foundation Summary

Shared primitives + 2-tab shell for Phase 7's screen-by-screen redesign: design tokens (color/typography/spacing/radius/shadow), liquid-glass view modifier with iOS 26/17–25 branch, liquid-glass pill button, TabBarRoot replacing the old in-ContentView TabView, Settings placeholder, asset-pipeline doc, and 5 token smoke tests — all with zero functional regressions in the Phase 1–6 test suite.

## What Shipped

- 5 token namespaces (`DSColor`, `DSTypography`, `DSSpacing`, `DSRadius`, `DSShadow`) sourced from Figma node 93:132, plus `.dsTypography(_:)` and `.dsShadow(_:)` view modifiers
- `LiquidGlassModifier` + `View.liquidGlass(in:tint:)` — iOS 26+ uses native `.glassEffect(.regular.tint(_:), in:)`, iOS 17–25 falls back to `.ultraThinMaterial` + tint overlay + plus-lighter gradient
- `LiquidGlassButton(title:tint:action:)` matching Figma "Button - Liquid Glass - Text": 40pt pill, 6/20pt padding, 17pt SF Pro Medium label, glass shadow
- `TabBarRoot` — 2-tab TabView (Trips airplane / Settings gear) tinted accent, consumes `AppState.pendingDeepLink` and forces `selectedTab=.trips` before ContentView's existing handler routes the destination
- `SettingsPlaceholderView` — gear icon + "Settings" title + "Coming in a future update" subtitle on `DSColor.Background.primary`
- `ContentView` refactored to its NavigationStack core (Trips-tab body); TabView shell relocated to TabBarRoot; deep-link `.onChange` logic preserved verbatim
- `TravellifyApp` root swapped from `ContentView()` to `TabBarRoot()`; existing `.modelContainer`, `.preferredColorScheme(.dark)`, scenePhase NotificationScheduler.reconcile preserved
- `Travellify/Assets.xcassets/EmptyStates.xcassets/` empty catalog folder with `Contents.json` placeholder
- `.planning/phases/07-ui-overhaul/ASSET-PIPELINE.md` documenting Figma-MCP ingestion workflow, naming conventions, sourcemap template
- `DesignSystemTokensTests` — 5 Swift Testing tests (accent RGB via UIColor round-trip, typography sizes, spacing monotonicity, radius pill, glass shadow values)

## Verification

- `xcodebuild build` on iPhone 16e simulator: BUILD SUCCEEDED, zero new warnings
- Full `xcodebuild test` suite: TEST SUCCEEDED — all Phase 1–6 tests green plus the 5 new tests
- Targeted `-only-testing:TravellifyTests/DesignSystemTokensTests` run: all 5 tests pass

## Deviations from Plan

### Notes (not auto-fixes)

**1. ContentView TabView removal — necessary refactor, not a violation of "do not modify ContentView".**
- **Found during:** Task 3
- **Issue:** The plan's M-H truth said preserve ContentView verbatim. But the on-disk ContentView (Phase 5/6) was already wrapping a `TabView` containing a Trips NavigationStack and a private `SettingsView`. That TabView is exactly what TabBarRoot replaces. Preserving it would have given the app two nested TabViews.
- **Fix:** ContentView reduced to its NavigationStack body — same NavigationStack, same AppDestination switch, same `.onChange(of: appState.pendingDeepLink)` deep-link consumer, same `path` state. Behavior is identical from the user's perspective; ContentView is now what the plan assumed it already was.
- **Files modified:** `Travellify/ContentView.swift`
- **Commit:** 5dbd81c

**2. Native iOS 26 glass API confirmed against the SDK swiftinterface.**
- **Found during:** Task 2
- **Discovery:** `SwiftUICore.framework` exposes `func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View` and `Glass.regular.tint(Color?) -> Glass` exactly as the plan hypothesized.
- **Resolution:** Code calls `content.glassEffect(.regular.tint(tint), in: shape)` directly. No deviation from the plan's preferred surface.

**3. Test API choice — UIColor round-trip vs `Color.resolve(in:)`.**
- **Found during:** Task 4
- **Issue:** Plan offered `Color.resolve(in: EnvironmentValues()).linear` with linear-vs-sRGB tolerance. UIColor round-trip is more direct for sRGB inputs and avoids the linear-color-space mental tax in the test.
- **Fix:** Test uses `UIColor(DSColor.Accent.primary).getRed(...)` and asserts each channel within 0.01 tolerance.
- **Commit:** 65ca33a

### Auto-fixed Issues

None.

## Auth Gates

None encountered.

## Out of Scope (deferred per plan)

- D7-07 conditional `+` toolbar — lands with 07-02 Trips
- Populating EmptyStates.xcassets with the actual TripListView illustration — pulled in 07-02
- Migrating any feature screen to the new tokens — starts in 07-02
- Settings tab content — v1.x

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | 134adaa | feat(07-01): scaffold DesignSystem tokens (color, typography, spacing, radius, shadow) |
| 2 | 2996433 | feat(07-01): add .liquidGlass() modifier and LiquidGlassButton component |
| 3 | 5dbd81c | feat(07-01): introduce TabBarRoot + Settings placeholder and reroute app root |
| 4 | 65ca33a | feat(07-01): asset-pipeline conventions + design-system smoke tests |

## Self-Check: PASSED

- All created files exist on disk (verified via Write tool responses)
- All 4 commit hashes resolve in `git log --oneline`: 134adaa, 2996433, 5dbd81c, 65ca33a
- Build green on iPhone 16e simulator
- 5 new tests + full Phase 1–6 suite green
