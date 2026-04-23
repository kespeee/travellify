---
phase: 06-polish-testflight
plan: 04
subsystem: testflight-submission-minimums
tags: [testflight, app-icon, privacy-manifest, pbxproj, metadata]
requires: [phase-05, 06-01, 06-02, 06-03]
provides:
  - "D85: 1024x1024 opaque RGB placeholder app icon wired into Assets.xcassets/AppIcon.appiconset (single-size iOS 17+ manifest)"
  - "D86: PrivacyInfo.xcprivacy at Travellify/ root (TN3183-conformant) + 4 pbxproj entries registering it as a bundle Resource"
  - "D87: MARKETING_VERSION=1.0 / CURRENT_PROJECT_VERSION=1 / PRODUCT_BUNDLE_IDENTIFIER=com.kespeee.travellify verified on main target"
  - "D88: No Info.plist additions — NSUserNotificationsUsageDescription not required on iOS (macOS-only key)"
affects:
  - "Travellify/Assets.xcassets/AppIcon.appiconset/Contents.json (filename wired)"
  - "Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png (new binary)"
  - "Travellify/PrivacyInfo.xcprivacy (new plist)"
  - "Travellify.xcodeproj/project.pbxproj (4 new entries for PrivacyInfo.xcprivacy)"
tech_stack:
  added: []
  patterns:
    - "Single-size (1024x1024) iOS 17+ asset catalog manifest (Xcode 16 generates per-size assets at build time)"
    - "Hand-crafted opaque RGB PNG via Python stdlib zlib (color type 2 — no alpha channel)"
    - "pbxproj 4-entry hand-edit for new Resource file (PBXBuildFile + PBXFileReference text.plist.xml + top-level PBXGroup child + PBXResourcesBuildPhase)"
key_files:
  created:
    - Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png
    - Travellify/PrivacyInfo.xcprivacy
  modified:
    - Travellify/Assets.xcassets/AppIcon.appiconset/Contents.json
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "[06-04] Placeholder icon generated via Python stdlib zlib (Pillow unavailable) — solid #FFDD2D (project yellow) RGB PNG, 4555 bytes, no alpha"
  - "[06-04] PrivacyInfo.xcprivacy landed at Travellify/ root alongside ContentView.swift (NOT inside App/ or Shared/) — ensures it ships at app-bundle root per TN3183 validation"
  - "[06-04] Privacy manifest registered as Resource (NOT Source) with lastKnownFileType=text.plist.xml"
  - "[06-04] D87 verification-only: no pbxproj writes needed — MARKETING_VERSION/CURRENT_PROJECT_VERSION/PRODUCT_BUNDLE_IDENTIFIER already at target values"
  - "[06-04] D88 no-op confirmed: zero NSUserNotificationsUsageDescription occurrences; INFOPLIST_KEY_NSCameraUsageDescription preserved from Phase 2"
metrics:
  duration: ~6min
  completed: 2026-04-24
  tasks: 3
  files_created: 2
  files_modified: 2
---

# Phase 6 Plan 4: TestFlight Submission Minimums Summary

TestFlight submission preflight closed out: 1024×1024 placeholder app icon wired, Apple TN3183-conformant PrivacyInfo.xcprivacy committed at bundle root and registered in Resources build phase, version/build/bundle-ID verified at D87 targets with zero corrective writes, and D88 confirmed no-op (NSUserNotificationsUsageDescription is macOS-only and not required on iOS).

## What Shipped

- **D85 (Placeholder app icon)** — `Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png`:
  - Generation tool: Python stdlib `zlib` + manual PNG chunk assembly (Pillow unavailable on this machine — fallback path per plan).
  - Content: solid `#FFDD2D` (project yellow per design-system MEMORY.md) with no glyph overlay. RGB color type 2 (3 bytes/pixel, no alpha channel).
  - File size: 4555 bytes.
  - `sips` verification: `pixelWidth: 1024`, `pixelHeight: 1024`, `hasAlpha: no`.
  - Contents.json wired with `"filename" : "icon-1024.png"` inside the existing single-size image object; no other schema changes.
  - **No pbxproj writes** — Assets.xcassets is already a registered Resource (landmine #5 honored).

- **D86 (PrivacyInfo.xcprivacy)** — `Travellify/PrivacyInfo.xcprivacy`:
  - Verbatim TN3183 plist from RESEARCH §D86 lines 534–565.
  - `NSPrivacyTracking` = false, `NSPrivacyTrackingDomains` = empty array, `NSPrivacyCollectedDataTypes` = empty array.
  - `NSPrivacyAccessedAPITypes`:
    - `NSPrivacyAccessedAPICategoryUserDefaults` / reason `CA92.1` (covers `hasSeenReminderPriming` UserDefaults access).
    - `NSPrivacyAccessedAPICategoryFileTimestamp` / reason `C617.1` (covers FileStorage document-attribute inspection).
  - `plutil -lint` → `OK`.
  - **4 pbxproj entries registered** (Resources variant, not Sources):
    1. `PBXBuildFile` UUID_A = `AD0604010203040506070801` — `PrivacyInfo.xcprivacy in Resources`, fileRef = UUID_B.
    2. `PBXFileReference` UUID_B = `AD0604010203040506070802` — `lastKnownFileType = text.plist.xml`, `path = PrivacyInfo.xcprivacy`, `sourceTree = "<group>"`.
    3. Top-level `Travellify/` PBXGroup child — UUID_B added alongside `ContentView.swift` + `Assets.xcassets` (NOT inside App/ or Shared/ — Pitfall 7).
    4. Main target `328E6A41664442069075386D /* Resources */` PBXResourcesBuildPhase `files = ( ... )` — UUID_A added alongside the existing `Assets.xcassets in Resources` entry.
  - Build-product verification: `PrivacyInfo.xcprivacy` lands at `Travellify.app/PrivacyInfo.xcprivacy` (bundle root — required for App Store validation).

- **D87 (Version / build / bundle-ID — verification-only)**:
  - `MARKETING_VERSION = 1.0` — 4 occurrences in pbxproj (main target Debug+Release + test target Debug+Release). Pre-edit count: 4. Post-edit count: 4. **No writes.**
  - `CURRENT_PROJECT_VERSION = 1;` — 4 occurrences. Pre-edit: 4. Post-edit: 4. **No writes.**
  - `PRODUCT_BUNDLE_IDENTIFIER = com.kespeee.travellify;` — 3 occurrences (main app target references; test target configs inherit without explicit `PRODUCT_BUNDLE_IDENTIFIER` override). Pre-edit: 3. Post-edit: 3. **No writes.**
  - TravellifyTests target configs deliberately leave `PRODUCT_BUNDLE_IDENTIFIER` unset (count = 0 of `.TravellifyTests;`) — pre-existing state from Phase 1, not this plan's concern.
  - Code signing remains "Automatic"; user must select Apple Developer team in Xcode before Archive (manual user-run step per D87).

- **D88 (Info.plist / INFOPLIST_KEY — no-op)**:
  - `grep -c "NSUserNotificationsUsageDescription" project.pbxproj` → 0 (macOS-only key; not needed for `UNUserNotificationCenter` on iOS).
  - `grep -c "INFOPLIST_KEY_NSCameraUsageDescription" project.pbxproj` → 2 (preserved from Phase 2 — Debug + Release of main target).
  - `NSPhotoLibraryUsageDescription` correctly absent (PhotosPicker runs out-of-process).
  - **Zero pbxproj writes.**

## Tests

Full regression test suite run on iPhone 16e: **ALL TESTS PASSED** (`** TEST SUCCEEDED **`, 97.5s). No tests added this plan (shell smoke checks substitute per 06-VALIDATION.md Wave 4 gate).

Shell smoke checks (from plan `<verification>`):
- `plutil -lint Travellify/PrivacyInfo.xcprivacy` → `OK`.
- `sips -g hasAlpha ...icon-1024.png` → `hasAlpha: no`.
- `sips -g pixelWidth -g pixelHeight ...icon-1024.png` → `pixelWidth: 1024`, `pixelHeight: 1024`.

Build on iPhone 16e: `** BUILD SUCCEEDED **` with no "AppIcon missing variant" or "missing privacy manifest" warnings.

## Landmine Verification

- **Landmine #5 (Assets.xcassets already registered)** — confirmed no new PBXBuildFile/PBXFileReference for `icon-1024.png`; it is bundled transparently through the existing asset-catalog entry.
- **Pitfall 6 (icon must be opaque + exactly 1024×1024)** — confirmed via `sips` (hasAlpha: no, 1024×1024).
- **Pitfall 7 (PrivacyInfo.xcprivacy must be top-level, not nested subgroup)** — confirmed: added as sibling of `ContentView.swift` in the top-level `Travellify/` PBXGroup; build-product places it at `Travellify.app/PrivacyInfo.xcprivacy` (bundle root).
- **Resources vs. Sources** — confirmed entry landed in `328E6A41664442069075386D /* Resources */` PBXResourcesBuildPhase, not the Sources phase.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Pillow unavailable → fell back to Python stdlib zlib PNG assembly**
- **Found during:** Task 1 Step A (icon generation).
- **Issue:** `import PIL` raised `ModuleNotFoundError` — Pillow is not installed on this machine.
- **Fix:** Followed the plan's stated fallback ("If Pillow is unavailable, fall back to a solid color via `sips` ... or commit a pre-existing solid-color PNG") by using a pure-stdlib approach: hand-assembled a minimal RGB PNG via `zlib.compress` + IHDR/IDAT/IEND chunk framing (color type 2 guarantees no alpha channel — cleaner than an RGBA→sips flatten path). Result: solid `#FFDD2D` 1024×1024 opaque PNG, 4555 bytes.
- **Impact:** Placeholder is a flat solid color (no 'T' glyph overlay, which Pillow would have drawn). Visual brand is still the project's yellow accent; glyph overlay is a nice-to-have not a requirement.
- **Files modified:** `Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png` (created).
- **Commit:** `ac4d084`.

### Placeholder Flag for User

The committed `icon-1024.png` is a **flat solid-color placeholder** — not a real branded app icon. Before actual TestFlight submission, the user should swap in a properly designed branded icon (the design-system "T" mark on yellow was the original intent but was not drawable without a font-rendering library in-session). Real branded icon is already tracked in CONTEXT.md as a v1.1 task. The current placeholder satisfies App Store validation (exactly 1024×1024, no alpha) — it's purely an aesthetic follow-up.

## Commits

| Task | Hash | Message |
|------|------|---------|
| 1 | ac4d084 | feat(06-04): add 1024x1024 placeholder app icon (D85) |
| 2 | 1aad922 | feat(06-04): add PrivacyInfo.xcprivacy manifest (D86) |
| 3 | — | (verification-only — no pbxproj writes; D87/D88 already at targets) |

## User-Run Manual Steps (Post-Phase)

Not GSD tasks — manual steps for the user before TestFlight:
1. Open the project in Xcode; under Signing & Capabilities, select your Apple Developer team.
2. Product → Archive.
3. Xcode Organizer → Distribute App → App Store Connect → Upload.
4. App Store Connect → TestFlight → add internal testers and start testing.
5. (Recommended v1.1) Replace the flat-yellow `icon-1024.png` with a properly designed branded icon.

## Archive-Preflight Observations

Not actually archived (per plan scope — user-run step). The debug build produced no Xcode warnings related to:
- Missing privacy manifest
- AppIcon missing variant
- Info.plist missing usage descriptions

The `Sign to Run Locally` debug signing path validated cleanly.

## Self-Check: PASSED

- FOUND: Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png
- FOUND: Travellify/PrivacyInfo.xcprivacy
- FOUND commits: ac4d084, 1aad922
- `plutil -lint` → OK
- `sips` hasAlpha: no, pixelWidth: 1024, pixelHeight: 1024
- `grep -c "PrivacyInfo.xcprivacy" project.pbxproj` → 4
- `grep -c "text.plist.xml.*PrivacyInfo.xcprivacy"` → 1
- `grep -c "PrivacyInfo.xcprivacy in Resources"` → 2 (PBXBuildFile decl + Resources-phase usage)
- Build: SUCCEEDED on iPhone 16e
- Full test suite: PASSED on iPhone 16e
- PrivacyInfo.xcprivacy lands at Travellify.app bundle root (verified via `find` in DerivedData)
