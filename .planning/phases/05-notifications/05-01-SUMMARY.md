---
phase: 05-notifications
plan: 01
subsystem: notifications-schema
tags: [schema, reminder, helpers, swift-testing]
requires:
  - Activity @Model (Phase 1/4)
  - TravellifySchemaV1, TravellifyMigrationPlan
provides:
  - "Activity.isReminderEnabled: Bool = false (D52)"
  - "Activity.reminderLeadMinutes: Int? = nil (D52)"
  - "ReminderLeadTime enum with 4 raw values (15/60/180/1440), default .oneHour (D51)"
  - "ReminderFireDate.fireDate(for:) pure helper"
affects:
  - Wave 2 (NotificationScheduler) — consumes all three artifacts
tech-stack:
  added: []
  patterns:
    - Additive @Model field changes with defaults (stay in SchemaV1, no V2 migration)
    - Pure-value enum + pure-function helper (no SwiftUI, no @MainActor)
    - Swift Testing @Test / #expect
    - Grep-gated schema invariants (mirrors SchemaTests.activitySchemaIsCloudKitSafe)
key-files:
  created:
    - Travellify/Shared/ReminderLeadTime.swift
    - Travellify/Shared/ReminderFireDate.swift
    - TravellifyTests/ReminderSchemaTests.swift
    - TravellifyTests/ReminderFireDateTests.swift
  modified:
    - Travellify/Models/Activity.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "[05-01] D52 reminder fields are additive — stay in SchemaV1, no SchemaV2 migration (pattern confirmed in Phases 2 and 4 for additive @Model changes)"
  - "[05-01] reminderLeadMinutes typed as Int? (not ReminderLeadTime?) — raw minutes stored, enum provides presets; allows future custom values without schema change"
  - "[05-01] ReminderFireDate is absolute-time math (startAt.addingTimeInterval(-TimeInterval(minutes*60))); DST correctness handled downstream by UNCalendarNotificationTrigger per RESEARCH §4"
  - "[05-01] ReminderLeadTime default .oneHour (= 60) locked per D51"
metrics:
  duration: 12min
  tasks_completed: 2
  files_touched: 6
  completed_date: 2026-04-22
---

# Phase 5 Plan 1: Reminder Schema + Helpers Summary

Land additive D52 schema fields on `Activity`, ship pure-value/pure-function helpers (`ReminderLeadTime`, `ReminderFireDate`), and gate them with grep-based schema tests + unit tests — all without leaving SchemaV1.

## D52 Fields Added to Activity

```swift
// Phase 5 additions (D52) — additive, defaults ensure SwiftData lightweight
// migration stays inside SchemaV1. CloudKit-safe (no @Attribute, no .unique).
var isReminderEnabled: Bool = false
var reminderLeadMinutes: Int? = nil
```

- `isReminderEnabled: Bool` with default `false` — off by default, opt-in per D50.
- `reminderLeadMinutes: Int?` with default `nil` — stores raw minutes; enum supplies presets.
- No `@Attribute` annotations — CloudKit-safe per CONVENTIONS.
- SchemaV1.models.count still 6; TravellifyMigrationPlan.stages still empty.

## ReminderLeadTime (D51)

```swift
enum ReminderLeadTime: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case oneHour = 60       // default per D51
    case threeHours = 180
    case oneDay = 1440
}
```

Exposes `allCases`, `id = rawValue`, `static let default = .oneHour`, and a `label` computed property ready for the picker row in Wave 3.

## ReminderFireDate

Pure helper — absolute-time subtraction:

```swift
static func fireDate(for activity: Activity) -> Date? {
    guard activity.isReminderEnabled,
          let minutes = activity.reminderLeadMinutes else { return nil }
    return activity.startAt.addingTimeInterval(-TimeInterval(minutes * 60))
}
```

DST handling is NOT this helper's responsibility. Wave 2's `UNCalendarNotificationTrigger` consumes calendar components and handles DST rollovers automatically (RESEARCH §4).

## Test Coverage (10 new @Tests, all green)

**ReminderSchemaTests (4):**
1. `activityHasReminderFieldsWithDefaults` — grep-gate on Activity.swift source
2. `schemaV1StillHasSixModels` — SchemaV1 model count invariant
3. `migrationPlanStillHasNoStages` — migration plan invariant
4. `newActivityDefaultsAreReminderOff` — in-memory ModelContainer save + assert defaults

**ReminderFireDateTests (6):**
1. `leadTimeRawValuesMatchPresets` — `[15, 60, 180, 1440]`
2. `leadTimeDefaultIsOneHour` — D51
3. `fireDateIsStartAtMinusLeadWhenEnabled` — happy path
4. `fireDateIsNilWhenReminderDisabled` — gate
5. `fireDateIsNilWhenLeadMinutesNil` — gate
6. `fireDateAcrossDSTIsAbsoluteTimeMath` — spring-forward boundary, 1-day lead

## pbxproj UUIDs Registered (for downstream reference)

| File                              | BuildFile                  | FileRef                    |
| --------------------------------- | -------------------------- | -------------------------- |
| TravellifyTests/ReminderSchemaTests.swift | `AD0501010203040506070801` | `AD0501010203040506070802` |
| Travellify/Shared/ReminderLeadTime.swift  | `AD050102030405060708090A` | `AD050102030405060708090B` |
| Travellify/Shared/ReminderFireDate.swift  | `AD050102030405060708090C` | `AD050102030405060708090D` |
| TravellifyTests/ReminderFireDateTests.swift | `AD050102030405060708090E` | `AD050102030405060708090F` |

16 total pbxproj insertions: 4 entries × 4 files (schema tests got 4; each of the three others also got 4).

## Commits

| Task | Commit  | Summary                                                               |
| ---- | ------- | --------------------------------------------------------------------- |
| 1 RED | `f9bb20c` | test(05-01): add failing ReminderSchemaTests for D52 fields           |
| 1 GREEN | `2ad4b8c` | feat(05-01): add D52 reminder fields to Activity model                 |
| 2    | `7d0efcc` | feat(05-01): add ReminderLeadTime + ReminderFireDate helpers with tests |

## Verification

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Travellify.xcodeproj -scheme Travellify \
  -destination 'platform=iOS Simulator,name=iPhone 16e'
```

Result: `** TEST SUCCEEDED **` — full suite green, no regressions on pre-existing
SchemaTests / ActivityTests / PartitionTests / DayLabelTests / NextUpcomingTests /
PackingTests / TripTests / DocumentTests / ImportTests / ViewerTests / FileStorageTests.

## Deviations from Plan

None — plan executed exactly as written. The only minor adjustment: during pbxproj
UUID generation, an initial typo introduced a stray space inside one UUID. Caught
and corrected before any build ran, so no build artifacts were affected.

## SourceKit Stale Diagnostics

None observed on these new files. Trust-xcodebuild rule from CONVENTIONS held — all
new types resolved cleanly in-editor once the pbxproj entries landed.

## Requirements Completed

- **ACT-07** — Schema surface for per-activity reminder preference is now landed
  (the field is queryable and defaulted off); Wave 2 will wire the scheduler and
  Wave 3 the UI. Leaving ACT-07 open until Wave 3 closes the user-visible loop.

## Self-Check: PASSED

- `Travellify/Models/Activity.swift` — FOUND (modified)
- `Travellify/Shared/ReminderLeadTime.swift` — FOUND
- `Travellify/Shared/ReminderFireDate.swift` — FOUND
- `TravellifyTests/ReminderSchemaTests.swift` — FOUND
- `TravellifyTests/ReminderFireDateTests.swift` — FOUND
- `Travellify.xcodeproj/project.pbxproj` — 16 new entries confirmed via grep
- Commits `f9bb20c`, `2ad4b8c`, `7d0efcc` — all FOUND in `git log`
