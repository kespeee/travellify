---
phase: 04-activities-core
plan: 02
subsystem: Features/Activities (sheet surface)
tags: [swiftui, swiftdata, sheet, form, activities]
requires:
  - TravellifySchemaV1.Activity (04-01)
  - ActivityDateLabels.defaultStartAt (04-01)
  - Trip model
provides:
  - ActivityEditSheet (SwiftUI view) — init(activity: Activity?, trip: Trip)
  - Features/Activities PBXGroup (first file registered; Wave 3 will append list-view files)
affects:
  - Travellify.xcodeproj/project.pbxproj (new group + 1 file registered in app target)
tech-stack:
  added: []
  patterns:
    - "Single add+edit sheet (TripEditSheet precedent)"
    - "didLoadInitialValues guard to protect user edits across re-mounts"
    - "Compact DatePicker with [.date, .hourAndMinute] inside Form"
    - "Inline soft-warn row (D41) as a secondary Form row sibling to DatePicker"
key-files:
  created:
    - Travellify/Features/Activities/ActivityEditSheet.swift
  modified:
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - D43 init signature honored verbatim — `init(activity: Activity?, trip: Trip)`; no Mode enum used (branch directly on `activity == nil`)
  - Soft-warn threshold computed at day resolution (startOfDay comparison) to match D41 intent — picking a time on trip.startDate never triggers the warning
  - confirmButtonTitle = "Add" in create, "Save" in edit (small UX nuance vs TripEditSheet's "Create Trip"/"Save Changes")
metrics:
  duration: ~6min
  completed: 2026-04-21
---

# Phase 4 Plan 2: ActivityEditSheet Summary

Ship `ActivityEditSheet` — a single SwiftUI sheet powering both create and edit for activities. Wave 3 will present it from two sites (toolbar +, row tap). The sheet is self-contained: it depends on `Trip`, an optional `Activity`, and the ambient `modelContext`, plus the Wave 1 `ActivityDateLabels.defaultStartAt(for:)` helper.

## Tasks Completed

| Task | Name                                                                    | Commit  |
| ---- | ----------------------------------------------------------------------- | ------- |
| 1    | ActivityEditSheet.swift + Features/Activities PBXGroup registration     | 77617ce |

## Implementation Notes

### Sheet structure

The body is a `NavigationStack { Form { ... } }` with four sections in D43 order:

1. **Activity** — `TextField("Title", text: $title)` with `.textInputAutocapitalization(.sentences)`
2. **When** — `DatePicker("Starts", selection: $startAt, displayedComponents: [.date, .hourAndMinute]).datePickerStyle(.compact)` followed by a conditional HStack warning row (orange `exclamationmark.triangle.fill` + caption "Outside trip dates")
3. **Location** — optional `TextField` with `.textInputAutocapitalization(.words)`
4. **Notes** — multi-line `TextField(..., axis: .vertical).lineLimit(3...8)`

Toolbar: leading Cancel (dismiss), trailing `confirmButtonTitle` ("Add" in create, "Save" in edit) disabled when trimmed title is empty.

### State properties (for Wave 3 reference)

All five `@State` locals live on the view:

- `title: String` — seeded from `activity?.title ?? ""`
- `startAt: Date` — seeded from `activity?.startAt ?? ActivityDateLabels.defaultStartAt(for: trip)`
- `location: String` — seeded from `activity?.location ?? ""`
- `notes: String` — seeded from `activity?.notes ?? ""`
- `didLoadInitialValues: Bool` — flipped on first `onAppear` and guards subsequent re-mounts from re-overwriting user edits (TripEditSheet lines 98-110 precedent)

### Save semantics (D40 / D43)

`save()` trims `location` and `notes`; empty trimmed values persist as `nil` (not `""`) to honor the `String?` optional-scalar semantics on the model.

- **Create mode:** `let newActivity = Activity(); /* assign 4 fields + trip */; modelContext.insert(newActivity); try modelContext.save()`.
- **Edit mode:** mutates the bound `Activity`'s 4 fields in place, then `try modelContext.save()`.

`dismiss()` is called unconditionally after `save()` in the toolbar closure; `modelContext.save` errors are swallowed into `assertionFailure` (matches TripEditSheet line 145) — real error surfacing is deferred to Phase 6 Polish.

### Soft-warn (D41)

The warning row renders iff `Calendar.current.startOfDay(for: startAt) < Calendar.current.startOfDay(for: trip.startDate)` or `> Calendar.current.startOfDay(for: trip.endDate)`. Day-level comparison (rather than raw Date) prevents false positives when a user picks, say, 07:00 on the trip's start date while `trip.startDate` itself is persisted as 00:00 startOfDay.

Save remains enabled while the warning is visible — D41 soft-warn is informational, not blocking.

### pbxproj — Activities PBXGroup birth

This plan introduces the `Features/Activities` PBXGroup. UUID scheme for this plan's additions is deliberately clustered to `AD0402030405060708090A0X` so Wave 3 can pick the next free block (`AD0403...`) without collisions:

- BuildFile: `AD0402030405060708090A01` → `ActivityEditSheet.swift in Sources`
- FileReference: `AD0402030405060708090A02` → `ActivityEditSheet.swift`
- PBXGroup: `AD0402030405060708090A03` → `Activities`

The group is inserted as the 4th child of the existing `Features` group (after Trips/Documents/Packing). Only one child for now; Wave 3 appends `ActivityListView.swift`, `ActivityRow.swift`, `ActivityDayHeader.swift`, `EmptyActivitiesView.swift` to this same group.

Grep gates:

- `grep -c ActivityEditSheet.swift Travellify.xcodeproj/project.pbxproj` → 4 (BuildFile + FileReference + Group children + Sources)
- Activities PBXGroup entry present as a child of `Features`.

## Swift 6 / SourceKit observations

None — the `DatePicker(.compact)` inside `Form` compiled cleanly with no strict-concurrency warnings on Xcode 26.2 (Swift 6 language mode). RESEARCH Pitfall 4 flagged it as a historical hazard but no warning surfaced on this target. `.scrollDismissesKeyboard(.immediately)` and `TextField(axis: .vertical)` also built without issue.

## Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e' build` → **BUILD SUCCEEDED**
- `grep -n "struct ActivityEditSheet" Travellify/Features/Activities/ActivityEditSheet.swift` → hit
- `grep -n "let activity: Activity?" Travellify/Features/Activities/ActivityEditSheet.swift` → hit
- `grep -n "let trip: Trip$" Travellify/Features/Activities/ActivityEditSheet.swift` → hit
- `grep -n "ActivityDateLabels.defaultStartAt" Travellify/Features/Activities/ActivityEditSheet.swift` → hit
- `grep -n 'displayedComponents: \[.date, .hourAndMinute\]' Travellify/Features/Activities/ActivityEditSheet.swift` → hit
- `grep -c didLoadInitialValues Travellify/Features/Activities/ActivityEditSheet.swift` → 3 (declaration + guard + set)
- `grep -n "Outside trip dates" Travellify/Features/Activities/ActivityEditSheet.swift` → hit
- `grep -nE "(role:\s*\.destructive|\"Delete\")" Travellify/Features/Activities/ActivityEditSheet.swift` → empty (D43 — no in-sheet delete)
- `grep -n "!isValid" Travellify/Features/Activities/ActivityEditSheet.swift` → hit
- Two `#Preview` blocks defined (Create mode + Edit mode). Both use an in-memory `ModelContainer` with the full 6-model list and insert a trip (+ seeded activity for Edit) before returning the sheet.

## Deviations from Plan

None structural. Minor notes:

- The plan's action block referenced the plan-supplied verbatim implementation; it was used as-is with two cosmetic adaptations: the `#Preview` blocks are wrapped in `#if DEBUG` to match the TripEditSheet convention, and the confirm button title is "Add" (create) / "Save" (edit) per the plan's own `confirmButtonTitle` computed. No behavioral drift from the D43 contract.

## Self-Check: PASSED

- FOUND: Travellify/Features/Activities/ActivityEditSheet.swift
- FOUND: pbxproj Activities PBXGroup + 4 ActivityEditSheet.swift references
- FOUND commit 77617ce
- Build: BUILD SUCCEEDED on iPhone 16e simulator
