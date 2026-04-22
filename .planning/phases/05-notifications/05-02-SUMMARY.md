---
phase: 05-notifications
plan: 02
subsystem: notifications-scheduler
tags: [scheduler, usernotifications, mainactor, swift-testing, mock-fixture]
requires:
  - Activity.isReminderEnabled / reminderLeadMinutes (Wave 1, 05-01)
  - ReminderFireDate.fireDate(for:) (Wave 1, 05-01)
  - ActivityDateLabels.timeLabel(for:) (Phase 4)
provides:
  - "NotificationCenterProtocol: Sendable — abstraction over the 5 UNUserNotificationCenter methods we use"
  - "UNUserNotificationCenter: NotificationCenterProtocol conformance (extension)"
  - "@MainActor NotificationScheduler.shared with reconcile(modelContext:) async"
  - "MockNotificationCenter test fixture for downstream ReminderLifecycleTests reuse"
affects:
  - Wave 3 (UI + app wiring, 05-03) — will call NotificationScheduler.shared.reconcile from save/delete + ScenePhase hooks
  - Wave 4 (AppDelegate + ReminderLifecycleTests, 05-04) — will reuse MockNotificationCenter in integration tests
tech-stack:
  added: []
  patterns:
    - "@MainActor service class + injectable NotificationCenterProtocol (testability without subclassing UNUserNotificationCenter)"
    - "@preconcurrency import UserNotifications at the protocol boundary (mock + tests) to tolerate non-Sendable UNNotificationRequest in async signatures"
    - "components.timeZone = .current pinned on DateComponents before UNCalendarNotificationTrigger (RESEARCH §4)"
    - "Soonest-64 globally via compactMap → sorted → prefix(64) → Set-diff against pendingNotificationRequests"
key-files:
  created:
    - Travellify/Shared/NotificationCenterProtocol.swift
    - Travellify/Shared/NotificationScheduler.swift
    - TravellifyTests/Support/MockNotificationCenter.swift
    - TravellifyTests/NotificationSchedulerTests.swift
  modified:
    - Travellify.xcodeproj/project.pbxproj
decisions:
  - "[05-02] Used @preconcurrency import UserNotifications in MockNotificationCenter + NotificationSchedulerTests. UNNotificationRequest is not Sendable and NotificationCenterProtocol has async methods returning [UNNotificationRequest]; without @preconcurrency, Swift 6 errors on the mock's nonisolated async methods. The real NotificationScheduler.swift imports UserNotifications normally (no @preconcurrency) because it stays fully @MainActor-isolated and never crosses an actor boundary with UN* types."
  - "[05-02] New Support/ PBXGroup under TravellifyTests to host test-only fixtures (MockNotificationCenter). Future mocks can join this group."
  - "[05-02] reconcile()'s cancel path uses Task { @MainActor in ... } inside the mock's removePendingNotificationRequests (protocol is synchronous). rescheduleDiff test uses await Task.yield() twice to pump that pending mutation before asserting."
metrics:
  duration: ~25min
  tasks_completed: 2
  files_touched: 5
  completed_date: 2026-04-23
---

# Phase 5 Plan 2: NotificationScheduler + NotificationCenterProtocol Summary

Wave 2 delivers the core notification scheduler: a `@MainActor` class that reconciles SwiftData user intent (`Activity.isReminderEnabled`) against iOS pending requests, capped at the soonest-64 globally, fully testable via an injected `NotificationCenterProtocol`.

## Public Shape (for Wave 3 consumers)

```swift
// Travellify/Shared/NotificationCenterProtocol.swift
protocol NotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func notificationSettings() async -> UNNotificationSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}
extension UNUserNotificationCenter: NotificationCenterProtocol {}

// Travellify/Shared/NotificationScheduler.swift
@MainActor
final class NotificationScheduler {
    static let shared: NotificationScheduler
    init(center: NotificationCenterProtocol = UNUserNotificationCenter.current())
    func reconcile(modelContext: ModelContext) async
}
```

**Call site contract (for Wave 3):**
```swift
Task { await NotificationScheduler.shared.reconcile(modelContext: modelContext) }
```
- Idempotent: safe to over-call from any mutation path or `ScenePhase == .active`.
- Never throws: swallows per-request `add()` failures with a `#if DEBUG print`.
- Guarded: returns silently if `FetchDescriptor<Activity>` fetch fails.

## Reconcile Algorithm

1. Fetch `Activity` where `isReminderEnabled == true` via `FetchDescriptor` + `#Predicate`.
2. Compute `(activity, fireDate)` via `ReminderFireDate.fireDate(for:)`; drop nil, drop `fireDate <= now`.
3. Sort ascending by fireDate; `.prefix(64)`.
4. `desiredIDs = Set(candidates.map { $0.0.id.uuidString })`.
5. `pending = await center.pendingNotificationRequests()`; `existingIDs = Set(pending.map(\.identifier))`.
6. `toCancel = existingIDs.subtracting(desiredIDs)` → `removePendingNotificationRequests(withIdentifiers:)` if non-empty.
7. For each candidate NOT in `existingIDs`: schedule.

## Notification Content Format (D61)

- `content.title = activity.title`
- `content.body = "<trip.name> · <timeLabel> · <location>"` with location segment OMITTED when `location == nil || location.isEmpty` (no trailing separator).
- `content.sound = .default`
- `content.userInfo["activityID"] = activity.id.uuidString`
- `UNCalendarNotificationTrigger(dateMatching: components, repeats: false)` with `components.timeZone = .current` pinned (RESEARCH §4 — DST correctness).
- Identifier: `activity.id.uuidString` (no prefix).

## MockNotificationCenter wiring (for Wave 4)

```swift
@MainActor
let mock = MockNotificationCenter()
mock.authStatus = .authorized                      // or .denied / .notDetermined
mock.shouldThrowOnAdd = false                      // flip to simulate center.add failure
let scheduler = NotificationScheduler(center: mock)
await scheduler.reconcile(modelContext: container.mainContext)
// Assert on mock.pending snapshot
```

**Note for Wave 4 ReminderLifecycleTests:** the mock's `removePendingNotificationRequests` is synchronous at the protocol level but dispatches its mutation via `Task { @MainActor in ... }` because the mock itself is `@MainActor` and the method must stay nonisolated to match the `Sendable` protocol. Tests that depend on the cancel effect being visible should `await Task.yield()` once or twice after calling `reconcile()` — see `rescheduleDiff` in `NotificationSchedulerTests.swift`.

## pbxproj UUIDs Registered (for downstream reference)

| File                                                   | BuildFile                  | FileRef                    |
| ------------------------------------------------------ | -------------------------- | -------------------------- |
| Travellify/Shared/NotificationCenterProtocol.swift     | `AD0502010203040506070801` | `AD0502010203040506070802` |
| TravellifyTests/Support/MockNotificationCenter.swift   | `AD0502010203040506070803` | `AD0502010203040506070804` |
| Travellify/Shared/NotificationScheduler.swift          | `AD0502010203040506070805` | `AD0502010203040506070806` |
| TravellifyTests/NotificationSchedulerTests.swift       | `AD0502010203040506070807` | `AD0502010203040506070808` |
| TravellifyTests/Support (new PBXGroup)                 | —                          | `AD05020102030405060708FF` |

16 total pbxproj insertions (4 entries × 4 files) + 1 new PBXGroup (Support).

## Test Coverage (6 new @Tests, all green)

**NotificationSchedulerTests (injected MockNotificationCenter, in-memory ModelContainer):**
1. `soonestSixtyFour` — 100 future activities → exactly 64 pending, all with the 64 earliest fireDates.
2. `diffIdempotent` — two back-to-back `reconcile()` calls on unchanged state → same pending set, same count.
3. `pastDatesIgnored` — 10 past + 5 future → exactly 5 scheduled.
4. `identifierMatchesUUID` — `request.identifier == activity.id.uuidString`, and `userInfo["activityID"]` matches.
5. `contentBodyFormat` — location non-empty yields `"<trip> · <time> · <loc>"`; nil/empty location omits segment, no trailing separator.
6. `rescheduleDiff` — flipping `isReminderEnabled = false` + reconcile cancels the identifier.

## Commits

| Task | Commit    | Summary                                                         |
| ---- | --------- | --------------------------------------------------------------- |
| 1    | `229c294` | feat(05-02): add NotificationCenterProtocol + MockNotificationCenter |
| 2    | `1444222` | feat(05-02): add NotificationScheduler with reconcile() and 6 unit tests |

## Verification

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Travellify.xcodeproj -scheme Travellify \
  -destination 'platform=iOS Simulator,name=iPhone 16e'
```

Result: `** TEST SUCCEEDED **` — full suite green.
- All 6 NotificationSchedulerTests pass (`identifierMatchesUUID`, `rescheduleDiff`, `contentBodyFormat`, `pastDatesIgnored`, `diffIdempotent`, `soonestSixtyFour`).
- No regressions on any pre-existing test (Schema / Trip / Activity / Packing / Document / Import / Viewer / FileStorage / Partition / DayLabel / NextUpcoming / ReminderSchema / ReminderFireDate / ActivityGrouping / Smoke).

## Deviations from Plan

### Rule 1 — Auto-fix: `@preconcurrency import UserNotifications` in mock + tests

- **Found during:** Task 1 `xcodebuild build-for-testing`.
- **Issue:** `MockNotificationCenter.pendingNotificationRequests()` is `nonisolated async -> [UNNotificationRequest]`. Because `NotificationCenterProtocol: Sendable`, the async method signature crosses an implicit actor boundary, and `UNNotificationRequest` is NOT Sendable under Swift 6. Compiler error: `type 'UNNotificationRequest' does not conform to the 'Sendable' protocol`.
- **Fix:** Changed `import UserNotifications` to `@preconcurrency import UserNotifications` in `MockNotificationCenter.swift` and `NotificationSchedulerTests.swift`. The real `NotificationScheduler.swift` does NOT need this — it stays fully `@MainActor`-isolated and never crosses actor boundaries with UN* types, so the compiler accepts it as-is.
- **Files modified:** `TravellifyTests/Support/MockNotificationCenter.swift`, `TravellifyTests/NotificationSchedulerTests.swift`.
- **Rationale:** RESEARCH §10 anticipated this exact issue ("MockNotificationCenter MUST be `@MainActor` or `@unchecked Sendable`-wrap its mutable state"). `@preconcurrency import` is the least invasive option — keeps the nonisolated bridge shape the plan specified, defers the Sendable warning back to UserNotifications' own (pre-Swift-6) module boundary where it belongs.
- **Tech debt:** When Travellify upgrades to Swift 6.2, revisit to see if isolated conformance (`@MainActor NotificationCenterProtocol`) makes `@preconcurrency` unnecessary.

### Rule 1 — Auto-fix: `await Task.yield()` in `rescheduleDiff` test

- **Found during:** Task 2 initial test run.
- **Issue:** `MockNotificationCenter.removePendingNotificationRequests(withIdentifiers:)` is declared synchronous on the protocol (matches `UNUserNotificationCenter`'s signature), but the mock is `@MainActor` so it must dispatch the mutation via `Task { @MainActor in ... }`. Without yielding, the assertion in `rescheduleDiff` can run before the Task body executes.
- **Fix:** `await Task.yield()` twice between `reconcile()` and the post-cancel assertion, giving the dispatched task a chance to run.
- **Files modified:** `TravellifyTests/NotificationSchedulerTests.swift` (test body only; no production change).
- **Forward impact:** Wave 4 ReminderLifecycleTests using the same mock should follow the same pattern — already documented in this SUMMARY under "MockNotificationCenter wiring."

No other deviations.

## Threat Flags

None. This plan introduces no new network endpoints, auth paths, or file access patterns. All additions stay within the app's existing local-notification scope defined in Phase 5 CONTEXT/RESEARCH.

## SourceKit Stale Diagnostics

None required investigation. Trust-xcodebuild rule held — once the pbxproj entries landed, both source files and tests resolved cleanly in the editor.

## Requirements Progress

- **ACT-07** — Scheduler half is now landed (reconcile pipeline + mock testability). User-visible UI and permission priming are Wave 3; deep-link is Wave 4.
- **ACT-09** — Soonest-64 cap + foreground-re-evaluate entry point (`reconcile()`) is landed. Wave 3 wires the `ScenePhase` hook; Wave 4 finishes the last percent (delegate + deep-link).

Neither requirement is fully closed yet; both require Wave 3+ follow-through before check-off in REQUIREMENTS.md.

## Self-Check: PASSED

- `Travellify/Shared/NotificationCenterProtocol.swift` — FOUND
- `Travellify/Shared/NotificationScheduler.swift` — FOUND
- `TravellifyTests/Support/MockNotificationCenter.swift` — FOUND
- `TravellifyTests/NotificationSchedulerTests.swift` — FOUND
- `Travellify.xcodeproj/project.pbxproj` — 16 new entries (4 per file × 4 files) + 1 new Support PBXGroup confirmed via grep
- Commits `229c294`, `1444222` — both FOUND in `git log`
- All 6 NotificationSchedulerTests green via `xcodebuild test -only-testing:TravellifyTests/NotificationSchedulerTests`
- Full-suite `** TEST SUCCEEDED **` confirmed (no regressions)
