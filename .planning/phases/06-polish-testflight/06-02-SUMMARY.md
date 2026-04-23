---
phase: 06-polish-testflight
plan: 02
subsystem: trip-reminders-foundation
tags: [trips, reminders, schema, swiftdata, swift-testing]
requires: [phase-01, phase-05, 06-01]
provides:
  - "D76: additive Trip reminder fields (isReminderEnabled, reminderLeadMinutes)"
  - "D77: TripReminderLeadTime enum (1d/3d/1w/2w, default=.threeDays) + bodyPhrase"
  - "D78: ReminderFireDate.fireDate(start:leadMinutes:) primitive + Trip overload; Activity overload delegates"
affects:
  - "Phase 5 ReminderFireDate (Activity overload now delegates to primitive; signature preserved)"
  - "Wave 3 (06-03) — TripEditSheet Reminder Section + scheduler union"
tech_stack:
  added: []
  patterns:
    - "Primitive-delegation pattern for shared Date math across two @Model overloads"
    - "CloudKit-safe additive SwiftData schema inside SchemaV1 (no V2 migration)"
    - "pbxproj 4-entry hand-edit: PBXBuildFile + PBXFileReference + PBXGroup child + Sources build-phase"
key_files:
  created:
    - Travellify/Shared/TripReminderLeadTime.swift
    - TravellifyTests/TripReminderFireDateTests.swift
  modified:
    - Travellify/Models/Trip.swift
    - Travellify/Shared/ReminderFireDate.swift
    - TravellifyTests/ReminderSchemaTests.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "[06-02] Fresh pbxproj UUID family AD06020102030405060708XX for Phase 6 Wave 2 source files; Wave 3 should continue the AD0603... family"
  - "[06-02] ReminderFireDate Activity overload keeps its existing signature — NotificationScheduler.swift call site and ReminderFireDateTests continue to compile with no edits"
  - "[06-02] SchemaV1 model count stays at 6; TravellifyMigrationPlan.stages stays empty (additive-only)"
metrics:
  duration: ~10min
  completed: 2026-04-24
  tasks: 2
  files_created: 2
  files_modified: 4
---

# Phase 6 Plan 2: Trip Reminders Foundation Summary

Additive Trip schema + `TripReminderLeadTime` preset enum + refactored `ReminderFireDate` exposing a shared primitive with both Activity and Trip overloads. Wave 2 lays the foundation Wave 3's `TripEditSheet` Reminder Section + scheduler union will consume.

## What Shipped

- **D76 — Trip schema (additive, CloudKit-safe):**
  - `Trip.swift` lines 14–16: `var isReminderEnabled: Bool = false` + `var reminderLeadMinutes: Int? = nil`.
  - No `@Attribute(.unique)`, no `@Attribute(.externalStorage)`, no delete-rule change.
  - `SchemaV1.swift` **unchanged** — still 6 models; `TravellifyMigrationPlan.stages` still empty.

- **D77 — TripReminderLeadTime enum** (`Travellify/Shared/TripReminderLeadTime.swift`):
  - 4 cases: `.oneDay=1440`, `.threeDays=4320`, `.oneWeek=10080`, `.twoWeeks=20160`.
  - `static let default = .threeDays` per the trip-horizon rationale.
  - `label` (sheet UI) + `bodyPhrase` (notification body per D80) both implemented now so Wave 3 doesn't need to modify this file.

- **D78 — ReminderFireDate refactor** (`Travellify/Shared/ReminderFireDate.swift`):
  - New primitive `static func fireDate(start: Date, leadMinutes: Int) -> Date`.
  - Existing `fireDate(for: Activity) -> Date?` now delegates to the primitive (signature unchanged — `NotificationScheduler` and `ReminderFireDateTests` continue to compile and pass).
  - New `fireDate(for: Trip) -> Date?` mirrors the Activity overload, anchoring on `trip.startDate`.
  - No parallel `TripReminderFireDate.swift` created (landmine #3 avoided).

## Tests

All suites green on iPhone 16e (iOS 26 simulator, Xcode 26.2):

**New file — `TripReminderFireDateTests.swift` (5 tests):**
- `enumRawValuesMatchMinutes` — `[1440, 4320, 10080, 20160]`
- `defaultIsThreeDays` — `.default == .threeDays` && rawValue 4320
- `fireDateIsStartMinusLeadWhenEnabled` — inserts Trip, expects `startDate − 1440 min`
- `fireDateIsNilWhenDisabled`
- `fireDateIsNilWhenLeadMinutesMissing`

**Extended — `ReminderSchemaTests.swift` (2 new tests, prior 4 preserved):**
- `tripReminderDefaults` — grep-gates Trip.swift source for D76 invariants
- `newTripDefaultsAreReminderOff` — inserts fresh Trip into in-memory container, asserts defaults

**Regression-check — existing `ReminderFireDateTests.swift`:** all 6 tests still pass (Activity overload signature preserved through delegation refactor).

## pbxproj UUIDs

| File | PBXBuildFile | PBXFileReference |
|------|--------------|------------------|
| `TripReminderLeadTime.swift` | `AD0602010203040506070801` | `AD0602010203040506070802` |
| `TripReminderFireDateTests.swift` | `AD0602010203040506070803` | `AD0602010203040506070804` |

8 total new pbxproj entries (2 files × 4 each). Group membership: `Shared/` PBXGroup (92B685F2294C44158A8F2A84) for TripReminderLeadTime; `TravellifyTests/` PBXGroup for TripReminderFireDateTests.

## NotificationScheduler Compatibility

`NotificationScheduler.swift` was **not modified** in this plan. The Activity-reminder call site continues to compile because `ReminderFireDate.fireDate(for: Activity) -> Date?` preserves its exact signature — only the implementation changed to delegate to the new primitive.

Wave 3 (06-03) will extend `NotificationScheduler.reconcile()` to union `Trip` rows with `Activity` rows (per D79 — `"trip-" + trip.uuid.uuidString` identifier) and fetch Trip fire dates via `ReminderFireDate.fireDate(for: trip)`.

## Swift 6 Strict Concurrency

No warnings observed under Swift 6.0 strict concurrency on the new enum or the refactored helper. Both files are pure value-semantic code (enum + nominal static funcs, no captured state, no actor isolation needed).

## Commits

| Task | Hash | Message |
|------|------|---------|
| 1    | bcfff01 | feat(06-02): add Trip reminder fields + TripReminderLeadTime + ReminderFireDate primitive |
| 2    | 5a1fe54 | test(06-02): add TripReminderFireDateTests + extend ReminderSchemaTests for Trip |

## Deviations from Plan

None — plan executed exactly as written. No Rule 1–4 invocations.

## Self-Check: PASSED

- FOUND: Travellify/Models/Trip.swift
- FOUND: Travellify/Shared/TripReminderLeadTime.swift
- FOUND: Travellify/Shared/ReminderFireDate.swift
- FOUND: TravellifyTests/TripReminderFireDateTests.swift
- FOUND: TravellifyTests/ReminderSchemaTests.swift
- FOUND commits: bcfff01, 5a1fe54
- Build: SUCCEEDED on iPhone 16e (Xcode 26.2).
- Tests: ALL PASSED (TripReminderFireDateTests×5 + ReminderSchemaTests×6 + ReminderFireDateTests×6).
- No parallel TripReminderFireDate.swift file exists (landmine #3 verified).
- pbxproj: 4 `TripReminderLeadTime.swift` refs + 4 `TripReminderFireDateTests.swift` refs confirmed.
