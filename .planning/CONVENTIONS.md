# Travellify Project Conventions

Hard-earned gotchas and non-obvious rules discovered during Phases 1–4. Read this before planning or executing any new phase.

---

## Build environment

- **Xcode path:** always prefix `xcodebuild` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Default CLT path (`xcode-select -p` → `/Library/Developer/CommandLineTools`) fails with "xcodebuild: error: SDK … cannot be located."
- **Canonical simulator:** `iPhone 16e` (iOS 26+). iPhone 16 is NOT installed on this host. All GSD plans and CI invocations must use this exact name.
- **Xcode / Swift:** 26.2 (Build 17C52), Swift 6.0 strict concurrency, **iOS 26.0 deployment target** (raised 2026-04-27 from iOS 17 to use Liquid Glass natively).

## project.pbxproj — hand-written, 4 entries per file

No XcodeGen, Tuist, or file-system-synchronized groups. Every new `.swift` file requires four manual entries:

1. `PBXBuildFile` section
2. `PBXFileReference` section
3. `PBXGroup` child reference (in the feature's group)
4. `Sources` build-phase entry on the `Travellify` target

Missing any one → silent link failure or "Cannot find type X" at build time. Use adjacent existing files as templates when generating UUIDs.

## SourceKit / editor diagnostics are frequently stale

Inline errors like `Cannot find type 'X'`, `No such module 'Testing'`, or missing member warnings often appear on files that **build and test green** via `xcodebuild`. Trust the build output, not the red squiggles in the editor. Don't chase a diagnostic until `xcodebuild` confirms it.

## SwiftData — CloudKit-safe rules (non-negotiable)

Enforced by `SchemaTests` grep gates. Breaking these makes v2 CloudKit migration impossible.

- **UUID default** on every `@Model`: `var id: UUID = UUID()`
- **Optional inverses** on every relationship: `var trip: Trip?` (not `Trip`)
- **No `@Attribute(.unique)`** anywhere — CloudKit does not support uniqueness
- **No `@Attribute(.externalStorage)`** — we manage binary files ourselves on disk (Application Support/Documents/&lt;tripUUID&gt;/&lt;docUUID&gt;.&lt;ext&gt;)
- **No `.deny` delete rules** — use `.cascade` or `.nullify`
- **Additive field changes** stay in SchemaV1 (no production data yet → no SchemaV2 needed). Confirmed for Phases 2 and 4.
- **Explicit model list** on every `ModelContainer(for:)` init site — safer than graph discovery with placeholder `@Model` types.

## Date / calendar pitfalls

- **`Calendar.isDateInToday` / `isDateInTomorrow` / `isDateInYesterday` ignore injected `now`** — they read the system clock. Tests that inject `now: Date` must compute relative-day via explicit `calendar.dateComponents([.day], from: nowStart, to: dayStart)` diff instead.
- **`RelativeDateTimeFormatter` is WRONG for day-section headers** — produces "in 2 days" / "3 days ago" instead of "Today · Apr 22" / "Mon, Apr 22". Use a cached `DateFormatter` with `setLocalizedDateFormatFromTemplate("EEE, MMM d")` or Apple's `localizedString(from:template:calendar:)` pinned to the injected calendar's timezone/locale. See `ActivityDateLabels.swift`.
- **Time-sensitive test helpers MUST accept injected `now: Date = Date()` and `calendar: Calendar = .current`.** Patterns: `TripPartition` (Phase 1), `ActivityDateLabels` (Phase 4).

## SwiftUI gotchas

- **`PhotosPicker` MUST NOT be embedded inside a `Menu`** — silently no-ops. Use a plain `Button` + `@State var isPresented` + `.photosPicker(isPresented:)` at view level. (Discovered Phase 2.)
- **`@FocusState` race** — setting focus before the `TextField` mounts fails. Fix either with an always-rendered `TextField` OR set focus inside `.onAppear { focused = true }`.
- **Cross-section drag-drop is unreliable on iOS 17.** Do NOT try to use `.onMove` inside `Section { ForEach }` if moves should cross sections. The working pattern is a flat `ForEach` over a discriminated-union entry enum (`progress | header | item | addItem`) plus a single top-level `.onMove(perform:)`. See `PackingListView.swift`.
- **Large `@ViewBuilder` bodies (>~150 lines with mixed control flow) blow up the Swift 6 type-checker.** Split into `@ViewBuilder` helper functions or extract ViewModifiers. Multi-branch message computation needs plain (non-`@ViewBuilder`) helpers because `@ViewBuilder` treats `let x; if { x = }` as void view expressions.
- **`.foregroundStyle(.tint)`** works for accent icons, but **`ProgressView` needs `Color.accentColor`** — `.accentColor` / `.accent` ShapeStyle members are unavailable in Xcode 26.2 SDK.

## Swift 6 concurrency

- **Static helpers on a `View` are inferred `@MainActor`.** If called from `Task.detached`, mark them `nonisolated`. See `DocumentThumbnail.swift` precedent.
- **`Task.detached` closures may only capture `Sendable` primitives** (String, Data, URL, UUID). A `@Model`-typed value (`Trip`, `Activity`, `Document`) must never cross an actor boundary.
- **`static var versionIdentifier` in `VersionedSchema` MUST be `static let`** — `Schema.Version` is immutable under strict concurrency.
- **`ScanView` coordinator `@MainActor` warnings under complete concurrency are EXPECTED** (UIKit overlay infers it). Do NOT add an explicit `@MainActor` annotation; leave the compiler warning.

## Routing

- `AppDestination` enum at `Travellify/App/AppDestination.swift` is the single source of truth for `NavigationStack` values. Every new feature detail view adds a case `.<featureName>(PersistentIdentifier)` and a matching branch in `ContentView.swift`'s `navigationDestination(for:)`.
- `NavigationStack` values MUST use `PersistentIdentifier` (not the `@Model`'s generated `ID` typealias — it is internal-access). Resolve the model inside the destination view via `modelContext.model(for: tripID) as? Trip`.

## Edit-sheet pattern

Single sheet handles create + edit:

```swift
init(activity: Activity?, trip: Trip)   // nil = add, non-nil = edit
```

See `TripEditSheet`, `DocumentEditSheet`, `ActivityEditSheet`. Do not split into two views.

## File storage

- Base path: `Application Support/Documents/<tripUUID>/<docUUID>.<ext>`
- Store `fileRelativePath` (NOT absolute) — survives container UUID changes after reinstall.
- Delete logic is **explicit** in the action handler — no SwiftData `willSave`/`didSave` hooks, no orphan sweep. Trip-cascade removes the whole `<tripUUID>/` folder post model save.

## GSD workflow enforcement

Per project CLAUDE.md: no direct file edits outside a GSD command. Enter via `/gsd-quick`, `/gsd-debug`, or `/gsd-plan-phase` + `/gsd-execute-phase`. Planning artifacts live under `.planning/`; state machine in `.planning/STATE.md`.

## UI implementation policy (Phase 7+, locked 2026-04-27)

The Phase 7 UI Overhaul and every later visual phase use **strict native iOS 26 only** — see `.planning/phases/07-ui-overhaul/07-CONTEXT.md` decisions D7-16 through D7-20 for the canonical rules. Headline points:

- **All cards have glass.** Outer wrappers + sub-cards + badges all use `.glassEffect(.clear, in: shape)`. No `.background(Color…)` solids on outer card surfaces, no `.regular` glass without explicit Figma direction, no `.ultraThinMaterial` overlays.
- **System fonts only.** `.font(.title)`, `.font(.title2)`, `.font(.headline)`, `.font(.body)`, `.font(.caption)` — never `.font(.system(size: N, weight: …))` with hardcoded points.
- **System semantic colors only.** `Color(.systemBackground)` / `Color(.secondarySystemBackground)` / `Color(.tertiarySystemBackground)` / `Color.accentColor` (`AccentColor` asset = `#0091FF`). One-off Figma accents inline as `Color(red: …, green: …, blue: …)` at call site, or graduate into `Assets.xcassets` if reused 3+ times.
- **Plain integer spacing.** `.padding(16)`, `VStack(spacing: 8)`, `.frame(width: 52)`. No `DSSpacing` token namespaces.
- **No custom view code.** No bespoke `ViewModifier`s / `ButtonStyle`s / `Font` extensions. If a Figma direction can't express in primitives, ask before reaching for custom code.
- **Tappable cards** = `NavigationLink { card }.buttonStyle(.plain).contextMenu { … }`. The `.contextMenu` sits on the `NavigationLink`, not inside the card body — nested contextMenu loses long-press gesture races.

Refer to `07-CONTEXT.md` for full text. Future phases either follow these rules or open them for revision before deviating.

---

_Last updated: 2026-04-27 — Phase 7 native-iOS UI policy locked._
