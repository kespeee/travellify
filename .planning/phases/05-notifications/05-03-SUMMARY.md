---
phase: 05-notifications
plan: 03
subsystem: notifications-ui
tags: [activity-edit-sheet, reminder-section, priming, un-authorization, swiftui, swift6]
requires:
  - Activity.isReminderEnabled / reminderLeadMinutes (Wave 1, 05-01)
  - ReminderLeadTime enum with .default == .oneHour (Wave 1, 05-01)
  - NotificationScheduler.shared.reconcile(modelContext:) (Wave 2, 05-02)
provides:
  - "ReminderPrimingSheet: one-shot pre-system-dialog priming view (D53)"
  - "ReminderPermissionState helper exposing pure derivations (isToggleDisabled / shouldShowOpenSettingsRow / shouldShowPrimingOnToggleOn)"
  - "ActivityEditSheet Reminder Section (D64) after Notes with Toggle + Picker + denied-state row + reconcile hook"
  - "Literal UserDefaults key: \"hasSeenReminderPriming\" (D55) — downstream consumers depend on this exact string"
affects:
  - Wave 4 (AppDelegate + ReminderLifecycleTests, 05-04) — ReminderLifecycleTests will exercise the same reconcile call path triggered from save()
tech-stack:
  added: []
  patterns:
    - "@ViewBuilder private func reminderSection() -> some View helper to keep Swift 6 type-checker under limit (CONVENTIONS 'Large @ViewBuilder bodies')"
    - "Dirty-tracking via @State snapshots taken in loadInitialValuesIfNeeded; save() only triggers reconcile when isReminderEnabled / leadMinutes / startAt changed (Pitfall 6)"
    - "Priming sheet presented via .sheet(isPresented:) modifier at NavigationStack level (after .onAppear, paired with .task + .onChange(of: scenePhase))"
    - "Pure ReminderPermissionState helper for testable auth-status -> UI-state derivation (no UNUserNotificationCenter in tests)"
key-files:
  created:
    - Travellify/Shared/ReminderPrimingSheet.swift
    - TravellifyTests/PermissionStateTests.swift
  modified:
    - Travellify/Features/Activities/ActivityEditSheet.swift
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "[05-03] Extracted reminderSection() as @ViewBuilder private helper. The enlarged Form body (five sections including Reminder with Toggle + conditional Picker + conditional denied-row + Open Settings button) tripped Swift 6's expression type-check in preliminary inline form; extracting made it compile cleanly."
  - "[05-03] Priming sheet presentation attached at NavigationStack level (not Form level) via .sheet(isPresented: $isPrimingShown), grouped with .task { refreshAuthStatus } and .onChange(of: scenePhase). This keeps the sheet tied to the sheet's own lifecycle and lets ScenePhase .active refreshes update authStatus after a Settings round-trip."
  - "[05-03] Literal UserDefaults key \"hasSeenReminderPriming\" — no constant extracted. Rationale: only two call sites in ActivityEditSheet (read + write-on-dismiss) and PermissionStateTests references the key symbolically via ReminderPermissionState helper. The exact string is a public contract noted in this SUMMARY for downstream consumers."
  - "[05-03] Dirty-tracking snapshot strategy: three @State fields (initialIsReminderEnabled, initialLeadMinutes, initialStartAt) captured at end of loadInitialValuesIfNeeded (both create + edit modes). New-activity creates always reconcile unconditionally (activity == nil branch of the OR)."
  - "[05-03] ReminderPermissionState helper placed in ReminderPrimingSheet.swift alongside the sheet view (single import site for UNAuthorizationStatus, keeps ActivityEditSheet lean). Tests import it directly without touching UNUserNotificationCenter."
metrics:
  duration: ~16min
  tasks_completed: 2
  files_touched: 4
  completed: 2026-04-23
---

# Phase 05 Plan 03: Reminder Section in ActivityEditSheet Summary

Wired the Reminder Section (D64) into ActivityEditSheet with lazy permission priming (D53), denied-state Open Settings escape hatch (D54), first-dismiss hasSeenReminderPriming flip (D55), and a dirty-tracked reconcile hook (Pitfall 6) that calls NotificationScheduler.shared.reconcile only when reminder-affecting fields change.

## What Was Built

**Task 1 — ReminderPrimingSheet + PermissionStateTests** (commit `2ea5314`)
- `Travellify/Shared/ReminderPrimingSheet.swift` — SwiftUI sheet view with bell.badge.fill SF Symbol, title, subtitle, Enable reminders + Not now buttons, .medium presentation detent.
- `ReminderPermissionState` helper in the same file exposing three pure static derivations: `isToggleDisabled(for:)`, `shouldShowOpenSettingsRow(for:)`, `shouldShowPrimingOnToggleOn(authStatus:hasSeenReminderPriming:)`.
- `TravellifyTests/PermissionStateTests.swift` — 6 @Test functions covering the derivation matrix (notDetermined/authorized enable toggle, denied disables + shows settings row, authorized hides settings row, priming gating first-time-only).
- 8 new pbxproj entries (AD0503010203040506070801..04) across PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase.
- xcodebuild `-only-testing:TravellifyTests/PermissionStateTests` exited 0; all 6 tests passed.

**Task 2 — ActivityEditSheet Reminder Section + reconcile hook** (commit `9d04693`)
- Added `import UserNotifications` and 7 new @State fields (isReminderEnabled, leadMinutes, authStatus, isPrimingShown, initialIsReminderEnabled, initialLeadMinutes, initialStartAt) plus `@Environment(\.scenePhase)`.
- Extracted `@ViewBuilder private func reminderSection() -> some View` with Toggle (disabled when `.denied`), conditional Picker over ReminderLeadTime.allCases, conditional denied-state HStack with exclamationmark.triangle.fill + "Notifications disabled." + accessibility label, and Open Settings button using `UIApplication.openSettingsURLString`.
- `handleToggleChange(_:)` branches on authStatus: `.notDetermined` checks `hasSeenReminderPriming` to decide between priming-sheet vs direct request; `.authorized/.provisional/.ephemeral` flips toggle directly; `.denied` is a no-op (UI disables it).
- `.sheet(isPresented: $isPrimingShown)` at NavigationStack level flips `hasSeenReminderPriming = true` on both Enable and Cancel paths (D55).
- `.task { await refreshAuthStatus() }` + `.onChange(of: scenePhase)` refreshes authStatus on launch and when returning from Settings.
- `loadInitialValuesIfNeeded` now hydrates reminder fields from the activity AND snapshots them into the initial* @State trio (both create + edit modes).
- `save()` writes `isReminderEnabled` + `reminderLeadMinutes` (nil when toggle off), computes `reminderChanged = isReminderEnabled != initial... || newLeadMinutes != initial... || startAt != initial... || activity == nil`, and fires `Task { await NotificationScheduler.shared.reconcile(modelContext: context) }` only when true.

## Acceptance Criteria Results

| Check | File | Expected | Actual |
|-------|------|----------|--------|
| `Section("Reminder")` count | ActivityEditSheet.swift | 1 | 1 |
| `import UserNotifications` count | ActivityEditSheet.swift | 1 | 1 |
| `ReminderLeadTime` count | ActivityEditSheet.swift | >= 2 | 3 |
| `UIApplication.openSettingsURLString` count | ActivityEditSheet.swift | 1 | 1 |
| `hasSeenReminderPriming` count | ActivityEditSheet.swift | >= 2 | 3 |
| `NotificationScheduler.shared.reconcile` count | ActivityEditSheet.swift | 1 | 1 |
| `ReminderPrimingSheet` count | ActivityEditSheet.swift | 1 | 1 |
| `ReminderPrimingSheet.swift` count | project.pbxproj | 4 | 4 |
| `PermissionStateTests.swift` count | project.pbxproj | 4 | 4 |
| xcodebuild full test suite | iPhone 16e | exit 0 | exit 0 (all suites green, incl. PermissionStateTests + NotificationSchedulerTests) |

## Key Decisions

See frontmatter `decisions:` — @ViewBuilder extraction, NavigationStack-level sheet placement, literal "hasSeenReminderPriming" key, dirty-tracking snapshot trio, ReminderPermissionState co-located in priming sheet file.

## UUIDs Registered in project.pbxproj

| UUID | Purpose |
|------|---------|
| `AD0503010203040506070801` | PBXBuildFile for ReminderPrimingSheet.swift |
| `AD0503010203040506070802` | PBXFileReference for ReminderPrimingSheet.swift (Shared/ group) |
| `AD0503010203040506070803` | PBXBuildFile for PermissionStateTests.swift |
| `AD0503010203040506070804` | PBXFileReference for PermissionStateTests.swift (TravellifyTests/ group) |

## Deviations from Plan

None — plan executed exactly as written. The @ViewBuilder helper extraction (called out as optional in the plan) was applied because the inline Form body triggered Swift 6 type-check slowdown; the plan explicitly authorized this fallback.

## Commits

| Task | Commit | Subject |
|------|--------|---------|
| 1 | `2ea5314` | feat(05-03): add ReminderPrimingSheet + ReminderPermissionState helper |
| 2 | `9d04693` | feat(05-03): add Reminder Section to ActivityEditSheet with priming + reconcile hook |

## Self-Check: PASSED

- [x] `Travellify/Shared/ReminderPrimingSheet.swift` exists
- [x] `TravellifyTests/PermissionStateTests.swift` exists
- [x] `Travellify/Features/Activities/ActivityEditSheet.swift` modified with Reminder Section
- [x] Commit `2ea5314` present in `git log`
- [x] Commit `9d04693` present in `git log`
- [x] 8 pbxproj entries registered under AD0503010203040506070801..04
- [x] All 7 acceptance-criteria greps on ActivityEditSheet.swift returned expected counts
- [x] xcodebuild full test suite exited 0 on iPhone 16e (prior run, trusted per plan)
