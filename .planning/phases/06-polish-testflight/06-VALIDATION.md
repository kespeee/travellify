---
phase: 6
slug: polish-testflight
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Full content is authored in `06-RESEARCH.md` § "Validation Architecture" — this file is the executor-facing entry point and tracks Wave 0 gap status.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (XCTest for UI tests — not used this phase) |
| **Config file** | none — Xcode target-level config |
| **Quick run command** | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:TravellifyTests/<suite>` |
| **Full suite command** | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e'` |
| **Estimated runtime** | ~90–120 s cold, ~20–40 s warm |

---

## Sampling Rate

- **After every task commit:** `xcodebuild test -only-testing:TravellifyTests/<specific-suite>`
- **After every wave merge:** full `TravellifyTests` suite
- **Post-Wave-4:** shell smoke checks — `plutil -lint Travellify/PrivacyInfo.xcprivacy` and `sips -g hasAlpha Travellify/Assets.xcassets/AppIcon.appiconset/icon-1024.png` (expect `no`)
- **Before `/gsd-verify-work`:** full suite green + manual iPhone 16e smoke of each D70–D74 UI polish change

---

## Per-Task Verification Map

See `06-RESEARCH.md` § "Validation Architecture" → "Phase Requirements → Test Map" for the complete, executor-ready table.

Summary (one row per req / decision):

| Req ID / Dec | Behavior | Test Command Fragment | File |
|--------------|----------|-----------------------|------|
| TRIP-07 | `ReminderFireDate.fireDate(for: Trip)` offset math | `-only-testing:TravellifyTests/TripReminderFireDateTests/firesAtCorrectOffset` | new: `TripReminderFireDateTests.swift` |
| TRIP-07 | `TripReminderLeadTime` rawValues match D77 | `-only-testing:TravellifyTests/TripReminderLeadTimeTests` | same file |
| TRIP-07 | Trip schema additive fields default | `-only-testing:TravellifyTests/ReminderSchemaTests/tripReminderDefaults` | extend existing |
| TRIP-08 | Reconcile cancels on toggle-off | `-only-testing:TravellifyTests/ReminderLifecycleTests/tripToggleOffCancels` | extend existing |
| TRIP-08 | Reconcile reschedules on date change | `-only-testing:TravellifyTests/ReminderLifecycleTests/tripDateEditReschedules` | extend existing |
| TRIP-08 | Reconcile cancels on trip delete | `-only-testing:TravellifyTests/ReminderLifecycleTests/tripDeleteCancels` | extend existing |
| TRIP-09 | Union fetch + soonest-64 (mixed Trip+Activity) | `-only-testing:TravellifyTests/NotificationSchedulerTests/unionSoonest64` | extend existing |
| TRIP-09 | Identifier prefix disambiguation | `-only-testing:TravellifyTests/NotificationSchedulerTests/tripIdentifierPrefix` | extend existing |
| D72 | `DocumentImporter.nextDefaultName(in:)` | `-only-testing:TravellifyTests/ImportTests/defaultNameSequence` | extend existing |
| D75 | `isOutsideTripRange` preserved | `-only-testing:TravellifyTests/ActivityTests/outsideRangeDayLevel` | extend existing |
| D86 | `PrivacyInfo.xcprivacy` valid + required codes | shell: `plutil -lint` + `grep -c 'CA92.1' + 'C617.1'` | new file |
| D85 | AppIcon 1024² PNG opaque (no alpha) | shell: `sips -g hasAlpha` | new file |
| D70–D74 | UI polish (view-layer only) | manual iPhone 16e smoke — justified | n/a |

---

## Wave 0 Gaps (must exist before execution starts)

- [ ] new file `TravellifyTests/TripReminderFireDateTests.swift` — covers TRIP-07 (fire-date math + enum rawValues). Mirror `ReminderFireDateTests.swift`.
- [ ] extend `TravellifyTests/ReminderSchemaTests.swift` with `tripReminderDefaults` test.
- [ ] extend `TravellifyTests/ReminderLifecycleTests.swift` with three trip lifecycle tests.
- [ ] extend `TravellifyTests/NotificationSchedulerTests.swift` with `unionSoonest64` + `tripIdentifierPrefix` tests.
- [ ] extend `TravellifyTests/ImportTests.swift` with `defaultNameSequence`.
- [ ] extend `TravellifyTests/ActivityTests.swift` with `outsideRangeDayLevel` preservation assertion.
- [ ] no Swift test for D85/D86 — shell-level checks are sufficient and documented above.

**Framework install:** none — Swift Testing ships with Xcode 16.
