---
phase: 04-activities-core
plan: 01
subsystem: Models + Shared utilities + Tests
tags: [schema, activities, dateformatter, tdd, cloudkit-safe]
requires:
  - TravellifySchemaV1 (pre-existing)
  - Trip model with activities cascade (Trip.swift:24, pre-existing)
provides:
  - TravellifySchemaV1.Activity with D40 fields
  - ActivityDateLabels helper enum (dayLabel, timeLabel, shortRelativeDay, nextTopOfHour, defaultStartAt, activitiesMessage)
  - ActivityTests (defaults, round-trip, mutation, cascade, nil-clear)
  - SchemaTests.activitySchemaIsCloudKitSafe assertion
affects:
  - SchemaV1 schema surface (additive-only, no V2 migration)
tech-stack:
  added: []
  patterns:
    - "Additive-within-V1 field expansion (Document.swift precedent)"
    - "Pure-static helpers with injectable now + calendar"
    - "Private static let cached DateFormatter instances"
key-files:
  created:
    - Travellify/Shared/ActivityDateLabels.swift
    - TravellifyTests/ActivityTests.swift
  modified:
    - Travellify/Models/Activity.swift
    - TravellifyTests/SchemaTests.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - D40 executed verbatim — no deviation
  - No SchemaV2 introduced; Activity additions are additive within SchemaV1 (all new stored properties have defaults, two optional scalars declared String?)
  - iPhone 16e used as canonical simulator (iPhone 16 not present on this host; matches STATE.md)
metrics:
  duration: ~8min
  completed: 2026-04-21
---

# Phase 4 Plan 1: Activity Schema + ActivityDateLabels Summary

Extend Activity @Model with D40 fields (title, startAt, location, notes, createdAt), add the reusable ActivityDateLabels helper (cached formatters + Today/Tomorrow/Yesterday day labels + defaultStartAt priority per D44 + activitiesMessage per D46), and land ActivityTests covering defaults, round-trip, mutation persistence, trip-delete cascade, and optional-to-nil clearing.

## Tasks Completed

| Task | Name                                                                                          | Commit  |
| ---- | --------------------------------------------------------------------------------------------- | ------- |
| 1    | Extend Activity @Model + add ActivityDateLabels.swift + pbxproj registration                  | 5e5320c |
| 2    | ActivityTests (5 cases) + SchemaTests.activitySchemaIsCloudKitSafe + pbxproj test-target reg  | c1930aa |

## Implementation Notes

### Activity.swift — additive field set

All new stored properties ship with defaults (`var title: String = ""`, `var startAt: Date = Date()`, `var createdAt: Date = Date()`) so SwiftData lightweight migration handles the upgrade on any already-persisted SchemaV1 store. `location` and `notes` are `String?` with no default — matches the Document.swift `trip: Trip?` precedent and how CloudKit treats missing scalars as nil. No `@Attribute(.unique)`, no `@Attribute(.externalStorage)`, optional `trip: Trip?` inverse preserved.

### ActivityDateLabels.swift — formatter caching + injection

Three `private static let` DateFormatter instances allocated once per app lifetime:

| Formatter              | Template / Style                     | Sample output |
| ---------------------- | ------------------------------------ | ------------- |
| weekdayAndDateFormatter | `setLocalizedDateFormatFromTemplate("EEE, MMM d")` | "Mon, Apr 22" |
| monthDayFormatter      | `setLocalizedDateFormatFromTemplate("MMM d")`     | "Apr 22"      |
| shortTimeFormatter     | `dateStyle=.none; timeStyle=.short`   | "2:00 PM" (locale-dependent) |

`now: Date = Date()` and `calendar: Calendar = .current` are injectable on every non-time-only helper so downstream grouping/label tests (Plan 04-03) can pass fixed dates. `nextTopOfHour` composes `byAdding:.hour value:1` then `bySetting:.minute value:0` + `bySetting:.second value:0` to zero sub-hour components deterministically.

`defaultStartAt(for:now:calendar:)` uses the D44 priority: future trip → trip.startDate at 09:00; otherwise next top-of-hour from `now`. This covers both "today within trip" and "past trip" cases identically by design.

`activitiesMessage(for:now:calendar:)` implements D46: empty → "No activities yet"; at least one upcoming → `"Next: <title> · <shortRelativeDay> at <timeLabel>"`; all past → count with `"y"/"ies"` pluralization.

### Locale / timezone observations

`DateFormatter.setLocalizedDateFormatFromTemplate` reorders tokens per locale — we rely on this rather than fixed `.dateFormat` strings. The `shortTimeFormatter` output in tests varies by simulator locale (en_US → "2:00 PM", fr_FR → "14:00"), which is why the plan's behaviour contract for `timeLabel` is locale-tolerant and only asserts string equality round-trip in the list-grouping tests (Plan 04-03), not a specific US-centric format. No fixed-locale formatters were introduced in this plan — they'll be added in Plan 04-03's DayLabelTests if deterministic en_US assertions are needed.

### pbxproj pitfalls (for Waves 2 and 3)

Four edit points per new Travellify-target file:
1. PBXBuildFile entry (top of pbxproj BuildFile section)
2. PBXFileReference entry (FileReference section)
3. Add reference to the containing PBXGroup children list (Shared/ or Features/Activities/)
4. Add the BuildFile to the app target's PBXSourcesBuildPhase files list

Test-target files follow the same 4 steps but against the **TravellifyTests** PBXGroup and the **test target's** Sources build phase (UUID 2254D2B3CA9043AFBA55EAD9) — **not** the app target's (UUID 8A4232BBCEEB498ABA81C38E). Using the wrong Sources phase either duplicates the symbol (build error) or silently drops the file from its intended target. Waves 2 (ActivityEditSheet) and 3 (ActivityListView + row/header/empty views) will each need multiple app-target registrations — mirror the existing Document/Packing blocks exactly.

Existing `Shared/` group previously only held `PreviewContainer.swift`; `ActivityDateLabels.swift` is now the second sibling.

## Test Results

Full test target green on iPhone 16e simulator (Xcode 26.2 / iOS 26.2):

- `ActivityTests/activityDefaults()` — passed
- `ActivityTests/insertActivityRoundTrip()` — passed
- `ActivityTests/mutationPersistsAfterSave()` — passed
- `ActivityTests/deleteTripCascadesToActivities()` — passed
- `ActivityTests/optionalFieldsCanBeClearedToNil()` — passed
- `SchemaTests/activitySchemaIsCloudKitSafe()` — passed
- All 40+ pre-existing tests still green (no regressions from additive schema changes)

Build: **BUILD SUCCEEDED**. Tests: **TEST SUCCEEDED**.

## Deviations from Plan

None structural. Minor notes:

- Plan text referenced `Travellify/Shared/SectionCard.swift` as a sibling in the Shared group; only `PreviewContainer.swift` actually exists there. No impact — pbxproj insertion point (the Shared PBXGroup UUID `92B685F2294C44158A8F2A84`) is unambiguous.
- Plan specified `iPhone 16e` in the action block but `iPhone 16` in the outer build-command hint. iPhone 16e is the canonical simulator per STATE.md [01-01] and is the one actually installed on this host; iPhone 16 is not available.

## Verification Gates

- `grep "var title: String" Travellify/Models/Activity.swift` → hit
- `grep "var startAt: Date" Travellify/Models/Activity.swift` → hit
- `grep "var createdAt: Date" Travellify/Models/Activity.swift` → hit
- `grep "@Attribute(.unique)" Travellify/Models/Activity.swift` → empty
- `grep "@Attribute(.externalStorage)" Travellify/Models/Activity.swift` → empty
- `grep "enum ActivityDateLabels" Travellify/Shared/ActivityDateLabels.swift` → hit
- `grep "ActivityDateLabels.swift" Travellify.xcodeproj/project.pbxproj` → 3 hits (BuildFile + FileReference + PBXGroup + Sources; 4 lines)
- `grep "ActivityTests.swift" Travellify.xcodeproj/project.pbxproj` → 4 lines

## Self-Check: PASSED

- FOUND: Travellify/Models/Activity.swift
- FOUND: Travellify/Shared/ActivityDateLabels.swift
- FOUND: TravellifyTests/ActivityTests.swift
- FOUND commit 5e5320c
- FOUND commit c1930aa
