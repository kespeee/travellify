# Phase 7 Asset Pipeline

Every Figma delivery that introduces a raster illustration follows this pipeline.

## Location

`Travellify/Assets.xcassets/EmptyStates/<screen>/`

> **IMPORTANT:** `EmptyStates` is a **plain folder** (asset-catalog group), NOT a
> nested `.xcassets`. A nested `.xcassets` is treated by `actool` as a separate
> catalog that requires its own pbxproj registration — without that, the
> imagesets inside are silently dropped from the bundle and `Image(...)` lookups
> return nothing. The fix that surfaced this on 2026-04-27: rename
> `EmptyStates.xcassets` → `EmptyStates`. Don't reintroduce the nested
> extension.

## Naming

- Image Set: `empty-state-<screen>` (e.g. `empty-state-trips`, `empty-state-documents`)
- Files: `empty-state-<screen>.png` / `@2x.png` / `@3x.png`

## Ingestion (from Figma MCP)

1. Identify the illustration node in the Figma file (e.g. node `96:870` for the
   TripListView empty-state illustration).
2. Call `get_design_context(fileKey="jLfc8jUHe465DkmibqqSjo", nodeId="<nodeId>")`
   or `get_screenshot(...)` to receive the rendered illustration.
3. If the response returns a bundled PNG URL under `localhost`, download it at
   1x, 2x, and 3x resolutions.
4. Save into `Travellify/Assets.xcassets/EmptyStates/<screen>/` with the
   naming above. Generate a `Contents.json` mapping each `idiom: "universal"`
   plus scale variant.
5. Reference in code as `Image("empty-state-<screen>")`.

## Naming sourcemap

Keep an `.planning/phases/07-ui-overhaul/ASSET-SOURCEMAP.md` entry each time an
asset is added:

| Asset name | Figma node | Delivery date | Consumed by (PLAN) |
|------------|-----------|---------------|---------------------|

## When NOT to use raster assets

- Icons that exist in SF Symbols → use `Image(systemName:)`.
- Tokens / shapes / text → use SwiftUI primitives.
- Asset bitmaps are reserved for illustrations that can't be composed
  (e.g. the 3-tilted-card TripListView illustration at node 96:870).

## Figma reference

- File: `https://www.figma.com/design/jLfc8jUHe465DkmibqqSjo/Travellify`
- File key: `jLfc8jUHe465DkmibqqSjo`
- First delivery (2026-04-25): node `93:132` — TripListView empty state
