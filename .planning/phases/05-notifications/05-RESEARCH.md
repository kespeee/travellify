# Phase 5: Notifications — Research

**Researched:** 2026-04-22
**Domain:** iOS local notifications (UserNotifications framework) under SwiftUI + SwiftData + Swift 6 strict concurrency
**Confidence:** HIGH for decisions D50–D64 implementation; MEDIUM on unresolved iOS quirk around `add()` behavior at the 64-cap (Apple's own docs decline to specify the eviction rule).

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D50–D52** Schema + UX: four preset lead-times (15/60/180/1440 min), default 1 hour on first enable, two additive fields on `Activity` (`isReminderEnabled: Bool = false`, `reminderLeadMinutes: Int? = nil`), stays in `SchemaV1`.
- **D53–D55** Permission priming: lazy on-first-toggle-ON custom priming sheet → system dialog; denied-state disabled toggle + "Open Settings" row; `UserDefaults` `hasSeenReminderPriming` is one-shot.
- **D56–D60** Scheduler policy: soonest-64 globally via `reconcile()`; triggers = foreground + mutation; identifier = `activity.id.uuidString`; user-intent lives in SwiftData, system state lives in `pendingNotificationRequests`, diff + reconcile. Silent eviction in v1.
- **D61–D64** Content + placement: `title = activity.title`, `body = "trip · time · location"` with optional-location fallback, `.default` sound, `userInfo["activityID"] = uuidString`; `UNCalendarNotificationTrigger(dateMatching: components, repeats: false)`; Reminder Section after Notes.

### Claude's Discretion
- `NotificationScheduler` internal shape (class vs actor vs struct with static methods) — must be `@MainActor`-safe entry with heavy work on a background `Task`.
- Priming sheet visual design and copy.
- Sheet vs full-screen modal for priming.
- Per-request error handling inside `reconcile()` (log + continue).
- Debouncing `reconcile()` under rapid consecutive mutations.

### Deferred Ideas (OUT OF SCOPE)
- Tap actions (Mark done / Snooze), global/per-trip mute, snooze/repeat, `BGTaskScheduler`, "at time of event" preset, remembered last-lead-time, badge on evicted rows.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ACT-07 | Per-activity opt-in; scheduled `UNNotificationRequest` fires before `startAt` | D52 schema, D63 trigger type, §1 trigger construction, §7 priming sheet, §11 identifier stability |
| ACT-08 | Reschedule on date change, cancel on delete | D58 diff-based reconcile, §5 persistence, §9 pending snapshot |
| ACT-09 | 64-cap scheduler, foreground re-evaluate | D56/D57 soonest-64 reconcile, §1 cap behavior, §9 `pendingNotificationRequests` |

## Summary

1. **The 64-cap is per-app, documented by Apple engineers but Apple's public docs do not specify what happens at the 65th `add(_:)`.** Community consensus is "silent drop of excess without an error." **Therefore the only safe correctness strategy is `reconcile()` with explicit pre-selection of the soonest 64 — which D56 already prescribes.** Never rely on the system to evict for you.
2. **For Swift 6 strict concurrency, the cleanest `UNUserNotificationCenterDelegate` pattern on iOS 17 (Swift 6.0, Xcode 26.2) is `@preconcurrency UNUserNotificationCenterDelegate` conformance on an `@UIApplicationDelegateAdaptor`-registered `AppDelegate`.** The Swift 6.2 isolated-conformance pattern (`NSObject, @MainActor UNUserNotificationCenterDelegate`) is cleaner but requires Swift 6.2 — Travellify is on Swift 6.0, so `@preconcurrency` is the current best option.
3. **Use `async` delegate methods, not completion-handler forms.** Apple engineers have warned that the completion-handler variants can crash with `__dispatch_queue_assert` on strict concurrency. `async` forms are idiomatic and integrate naturally with a `@MainActor` body.
4. **`UNCalendarNotificationTrigger` with `repeats: false`, built from `DateComponents` with explicit `timeZone = .current`, is correct.** DST correctness requires either the calendar trigger (as D63 chose) or explicit timezone attachment — `UNTimeIntervalNotificationTrigger` would have the opposite problem.
5. **Pending requests DO survive force-quit and device reboot** (the system's `usernotificationsd` daemon retains them). They do NOT survive app uninstall-then-reinstall (the app sandbox is purged). Force-quit-while-app-is-backgrounded has historical quirks — running `reconcile()` on `ScenePhase == .active` (D57) defensively handles every case.
6. **`UNNotificationRequest` / `UNMutableNotificationContent` are NOT `Sendable` under Swift 6.** Construct them inside the actor that consumes them (typically `@MainActor` or a single `nonisolated` helper) and do not pass them across actor boundaries. This keeps the scheduler simple.
7. **`getPendingNotificationRequests(completionHandler:)` has an async variant** — `await UNUserNotificationCenter.current().pendingNotificationRequests()`. It returns a snapshot, not a live observer. Safe from `@MainActor`.
8. **Using `activity.id.uuidString` directly as the request identifier is safe.** No length cap issues in practice, hex+hyphens is a valid identifier charset. No need to prefix.

**Primary recommendation:** Wire the app via `@UIApplicationDelegateAdaptor(AppDelegate.self)` with `@preconcurrency UNUserNotificationCenterDelegate`. Build `NotificationScheduler` as a `@MainActor` class that owns all scheduling logic, uses `await` APIs throughout, builds `UNMutableNotificationContent` and `UNNotificationRequest` on the main actor (they're `@MainActor`-constructable and not `Sendable`, so don't ship them across actors). Use an injected `NotificationCenterProtocol` for testability.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Reminder user-intent storage | SwiftData (`@Model Activity`) | — | Model is the single source of truth for what user wants. |
| Reminder UI toggle / picker / denied row | SwiftUI View (`ActivityEditSheet`) | — | Form-embedded; no service call in view body. |
| Permission priming + request | App-level service + sheet | SwiftUI `.sheet` presentation | Priming lives in a small `PermissionGateway` (or `NotificationScheduler.authorize()`); the sheet is presentation only. |
| 64-cap reconcile + diff | `NotificationScheduler` (@MainActor class) | Background Task for `pendingNotificationRequests` fetch | Main-actor safe entry; heavy fetch/add off the main thread via `Task`. |
| Notification delivery + foreground presentation | `AppDelegate : UNUserNotificationCenterDelegate` | App-level @Observable for deep-link state | Apple-owned lifecycle; app observes user-visible deep-link intent. |
| Deep-link routing on tap | `ContentView` + `NavigationPath` + `AppDestination` | AppDelegate setter | Delegate sets a `pendingDeepLink` value; `ContentView` observes and appends to path. |

## Open Questions Resolved

### 1. 64-cap behavior at `add(_:)` for the 65th request

**Answer (MEDIUM confidence — Apple's public docs decline to specify):**

- The 64-cap is confirmed by Apple Engineer on the developer forums: *"Yes, there is a limit of 64 for how many simultaneous notification requests can be active/pending at one time per app. This is a system limit and there is no way around it."* [CITED: Apple Developer Forums thread 811171]
- Apple does NOT publicly document WHAT happens at the 65th add. Community observation ranges from "silent drop of newest" to "eviction of furthest-future." There is no guarantee.
- **Practical consequence:** Your code MUST never rely on the system's eviction rule. `reconcile()` must explicitly select the soonest-64 by `fireDate` and issue only those 64 requests. D56 is correct.
- **Implementation note:** When `pendingNotificationRequests().count` returns <64, you can `add(_:)`. When == 64, you must first `removePendingNotificationRequests(withIdentifiers:)` to make room. D58's diff already handles this naturally.

### 2. `UNUserNotificationCenterDelegate` lifecycle under iOS 17+ / SwiftUI `@main`

**Answer (HIGH confidence):**

Use `@UIApplicationDelegateAdaptor(AppDelegate.self)`. This is the current Apple-documented best practice for bridging UIKit-era delegates into SwiftUI `@main App`. Assigning the delegate from a view's `.onAppear` is unreliable: if the user taps a notification while the app is cold-launching, `willFinishLaunchingWithOptions` runs before any view mounts, and without a delegate set at that moment iOS may lose the tap-routing signal. Running the assignment in `App.init()` also works but is less canonical and fights the SwiftUI lifecycle [CITED: swiftwithmajid.com/2024/04/09/deep-linking-for-local-notifications-in-swiftui/].

```swift
@main
struct TravellifyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    ...
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions:
                       [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}
```

### 3. Swift 6 annotations for `willPresent` / `didReceive`

**Answer (HIGH confidence):**

Under Swift 6.0 (Travellify's mode), the idiomatic pattern is **`@preconcurrency UNUserNotificationCenterDelegate`** on an `NSObject`-based `AppDelegate`, using the `async` variants of the delegate methods. This silences the "nonisolated protocol method cannot satisfy main-actor requirement" diagnostics that strict concurrency surfaces [CITED: Apple Developer Forums thread 762217].

```swift
extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {

    // Runs on MainActor by virtue of AppDelegate being MainActor-isolated under
    // @preconcurrency. Don't use the completion-handler variant — Apple engineers
    // flagged __dispatch_queue_assert crashes on that form under Swift 6.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let uuidString = info["activityID"] as? String,
              let uuid = UUID(uuidString: uuidString) else { return }
        AppState.shared.pendingDeepLink = .activity(uuid)
    }
}
```

**Why not Swift 6.2 isolated conformances?** The cleaner `NSObject, @MainActor UNUserNotificationCenterDelegate` syntax requires Swift 6.2 [CITED: twocentstudios.com/2025/08/12]; Travellify is on Swift 6.0 (Xcode 26.2). Re-evaluate when upgrading to Swift 6.2.

**Key rule:** *Always prefer the `async` delegate methods over the completion-handler variants under Swift 6* — completion-handler forms can crash with `__dispatch_queue_assert` [CITED: Apple Forum thread 762217].

### 4. `UNCalendarNotificationTrigger` from absolute `Date`

**Answer (HIGH confidence):**

The correct idiom, with the one critical subtlety — **set `timeZone` explicitly on the `DateComponents`**, else they default to GMT in some paths and the notification fires at the wrong wall-clock time [CITED: donnywals.com/scheduling-daily-notifications].

```swift
func calendarTrigger(for fireDate: Date) -> UNCalendarNotificationTrigger {
    var calendar = Calendar.current
    calendar.timeZone = .current
    var components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute],
        from: fireDate
    )
    components.timeZone = .current    // CRITICAL
    return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
}
```

**DST pitfalls:** `UNCalendarNotificationTrigger` (D63) is the correct choice. `UNTimeIntervalNotificationTrigger` locks to absolute seconds-from-now, so after a DST transition a reminder scheduled "before" a transition fires at the wrong wall-clock time (10:00 instead of 11:00) [CITED: donnywals.com]. Calendar triggers respect the user's current locale calendar and DST rules.

**Precision:** Include `.year, .month, .day, .hour, .minute` only. Omitting `.second` means the trigger may fire up to 59 seconds late but avoids sub-minute races. Since reminder granularity is ≥15 min (D50), second-precision is unnecessary.

**Past-date guard:** If `fireDate <= Date()` when `reconcile()` runs, the trigger is skipped in the soonest-64 selection (D56 already says "past fireDates ignored"). iOS does NOT deliver a calendar trigger whose components are fully in the past, so there's no accidental "fires immediately" risk.

### 5. Persistence of pending requests across lifecycle events

**Answer (HIGH confidence, verified against Apple forums and official docs):**

| Lifecycle event | Pending requests preserved? | Action needed? |
|-----------------|------------------------------|----------------|
| App backgrounded | ✅ Yes | None |
| App force-quit by user | ✅ Yes (iOS holds the schedule in `usernotificationsd`) | None — notifications still fire on schedule |
| Device reboot | ✅ Yes | Historical forum reports mixed, but Apple's archived `SchedulingandHandlingLocalNotifications` guide states: "Scheduled local notifications remain active until they are unscheduled by the system or until you cancel them explicitly." [CITED: Apple Local and Remote Notification Programming Guide] |
| App binary update | ✅ Yes (sandbox preserved, `usernotificationsd` schedule preserved) | None |
| App uninstall → reinstall | ❌ No (sandbox purged; all pending requests gone) | `reconcile()` on next launch rebuilds from SwiftData |

**Consequence for Travellify:** Because D57 already runs `reconcile()` on `ScenePhase == .active`, every lifecycle case is covered:
- Normal launch → reconcile fetches (possibly stale) pending + current SwiftData activities, diffs, brings in line.
- Post-reinstall cold launch → pending is empty, SwiftData activities loaded from iCloud/local store (if any), reconcile schedules fresh.
- Post-reboot launch → pending already correct; reconcile is a no-op diff.

`pendingNotificationRequests` can therefore be trusted as system truth at every foreground entry.

### 6. Swift 6 `Sendable` warnings on `UNNotificationRequest` / `UNMutableNotificationContent`

**Answer (HIGH confidence):**

These types are **not** marked `Sendable` under Swift 6 [CITED: Apple Forums thread 718565 non-sendable warning discussion]. The ergonomic way around this: **do not cross actor boundaries with them.** Construct and consume on the same actor (`@MainActor` is easiest).

```swift
@MainActor
final class NotificationScheduler {
    private let center: NotificationCenterProtocol
    init(center: NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func reconcile(activities: [Activity]) async {
        // Everything runs on @MainActor. No cross-actor passing of UN* types.
        let pending = await center.pendingNotificationRequests()
        // ... diff and add/remove ...
    }
}
```

**Do NOT do this:**
```swift
Task.detached {
    let request = UNNotificationRequest(...)   // ❌ crosses actor boundary
    await center.add(request)
}
```

If you need to release the main thread during the diff computation, pass only `Sendable` primitives (`UUID`, `Date`, `String`) into the `Task`, and construct `UNNotificationRequest` values inside the task's isolation. The simpler default — run the whole reconcile on `@MainActor` — is fine for N ≤ 64 activities; the fetch is async-await, so the UI never actually blocks.

### 7. Custom priming sheet in SwiftUI (nested under an already-presented sheet)

**Answer (HIGH confidence for base pattern; MEDIUM for nested-sheet caveat):**

Base pattern:
```swift
struct ReminderSection: View {
    @Bindable var activity: Activity
    @State private var isPrimingShown = false
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Section("Reminder") {
            Toggle("Reminder", isOn: Binding(
                get: { activity.isReminderEnabled },
                set: { newValue in
                    if newValue, authStatus == .notDetermined {
                        if UserDefaults.standard.bool(forKey: "hasSeenReminderPriming") {
                            // Skip priming — go straight to system dialog
                            Task { await requestAuth() }
                        } else {
                            isPrimingShown = true
                        }
                    } else {
                        activity.isReminderEnabled = newValue
                    }
                }
            ))
            .disabled(authStatus == .denied)
            // ... picker, denied row, etc
        }
        .task { await refreshAuthStatus() }
        .sheet(isPresented: $isPrimingShown) {
            PrimingSheet(onEnable: {
                UserDefaults.standard.set(true, forKey: "hasSeenReminderPriming")
                Task {
                    await requestAuth()
                    isPrimingShown = false
                }
            })
        }
    }

    func requestAuth() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthStatus()
        if granted { activity.isReminderEnabled = true }
    }

    func refreshAuthStatus() async {
        authStatus = await UNUserNotificationCenter.current()
            .notificationSettings().authorizationStatus
    }
}
```

**Nested-sheet caveat:** SwiftUI supports nested sheets on iOS 17+ without the pre-iOS-14 restriction. Presenting a priming sheet from inside an already-presented `ActivityEditSheet` works correctly — iOS stacks them. If any visual quirk arises (rare, usually an animation hiccup), fall back to `.alert` or `.fullScreenCover` for the priming presentation. [ASSUMED: personal testing experience — confirm during implementation]

### 8. Authorization status refresh on sheet reappear

**Answer (HIGH confidence):**

`.task {}` on the containing view refreshes authorization status every time the view appears. When the user leaves for Settings.app and returns, SwiftUI re-runs `.task` because the view tree re-attaches. No additional observer needed.

Caveat: `.task` runs on every `onAppear` AND when identity-affecting state changes. For a sheet that stays mounted but the user goes to Settings and back, the app transitions through `ScenePhase.inactive` → `.background` → `.active`. Observe `@Environment(\.scenePhase)` and re-call `refreshAuthStatus()` on `.active`:

```swift
@Environment(\.scenePhase) private var scenePhase
// ...
.onChange(of: scenePhase) { _, new in
    if new == .active {
        Task { await refreshAuthStatus() }
    }
}
```

### 9. `pendingNotificationRequests()` async + snapshot semantics

**Answer (HIGH confidence):**

- iOS 17+ provides an `async` variant: `let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()`. Safe to call from `@MainActor`.
- It returns a **snapshot**, not a live observer. Call it at the start of each `reconcile()` pass. Between calls, notifications may fire and self-remove (one-shot triggers auto-unschedule on delivery); there is no KVO or Combine publisher on this collection.
- Implication: `reconcile()` must treat `pendingNotificationRequests()` as "what iOS has RIGHT NOW" and re-fetch on each run. D58 already prescribes this.

### 10. Testability: `NotificationCenterProtocol` pattern

**Answer (HIGH confidence):**

`UNUserNotificationCenter` is a `final` class. Extract only the methods we actually call and make `UNUserNotificationCenter` conform to the protocol via an extension:

```swift
protocol NotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func notificationSettings() async -> UNNotificationSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNUserNotificationCenter: NotificationCenterProtocol {}

@MainActor
final class MockNotificationCenter: NotificationCenterProtocol {
    var pending: [UNNotificationRequest] = []
    var authStatus: UNAuthorizationStatus = .authorized

    nonisolated func add(_ request: UNNotificationRequest) async throws {
        await MainActor.run { self.pending.append(request) }
    }
    // ... etc
}
```

**Sendable gotchas:**
- Declaring the protocol `: Sendable` lets it cross actor boundaries; the real `UNUserNotificationCenter` is `Sendable` so this is safe.
- The MockNotificationCenter MUST be `@MainActor` or `@unchecked Sendable`-wrap its mutable state — same dance you already do elsewhere.
- `UNNotificationSettings` is a UIKit-era reference type; treat it as read-only across actors (it effectively is).

### 11. Identifier stability: `activity.id.uuidString`

**Answer (HIGH confidence):**

Safe. `UUID.uuidString` produces a 36-character string of `[0-9A-F-]` — no illegal characters, well under any practical length limit. Apple's documentation does not publish an identifier length cap, but UUID strings are the de-facto industry choice for `UNNotificationRequest.identifier` [CITED: appsdeveloperblog.com on reading/cancelling local notifications].

**Prefix or not?** D60 says no prefix. This is fine for v1 since reminders are the only notification type. If a future phase adds, say, packing-deadline reminders, a `"activity-"` prefix would be worth introducing at that time — but not pre-emptively.

### 12. Deep-link routing on notification tap

**Answer (HIGH confidence):**

Recommended pattern: observable app-state, delegate sets an intent, root view observes and appends to `NavigationPath`.

```swift
// App/AppState.swift
@Observable
@MainActor
final class AppState {
    static let shared = AppState()
    var pendingDeepLink: PendingDeepLink?
    enum PendingDeepLink: Equatable {
        case activity(UUID)
    }
}

// AppDelegate.didReceive sets AppState.shared.pendingDeepLink = .activity(uuid)

// ContentView observes + consumes
struct ContentView: View {
    @State private var path = NavigationPath()
    @Environment(\.modelContext) private var modelContext
    private let appState = AppState.shared

    var body: some View {
        NavigationStack(path: $path) {
            TripListView()
                .navigationDestination(for: AppDestination.self) { ... }
        }
        .onChange(of: appState.pendingDeepLink) { _, deepLink in
            guard case .activity(let uuid) = deepLink else { return }
            // Lookup Activity by UUID -> find its Trip -> append route
            if let trip = findTrip(for: uuid) {
                path.append(AppDestination.activityList(trip.persistentModelID))
                // Optional: set a separate @State to trigger edit-sheet presentation
            }
            appState.pendingDeepLink = nil   // consume the intent
        }
    }
}
```

**Why `UUID` in userInfo, not `PersistentIdentifier`?** `PersistentIdentifier` is not URL-/dictionary-safely encodable across launches — it's a SwiftData opaque type. UUID is stable across re-launches and survives the SwiftData-to-userInfo-to-SwiftData round-trip. Resolve UUID → Activity via `FetchDescriptor<Activity>(predicate: #Predicate { $0.id == uuid })`.

**Observability:** Using `@Observable` with `NavigationPath` requires `@Bindable` to get a binding (this is the documented gotcha [CITED: Apple Developer Forums thread 733238]). Keep `NavigationPath` as `@State` on `ContentView` (already the pattern) and `appState.pendingDeepLink` as the signal — this sidesteps the `@Observable`+`NavigationPath` binding issue cleanly.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (Xcode 26.2) |
| Config file | none (Swift Testing is zero-config) |
| Quick run command | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:TravellifyTests/NotificationSchedulerTests` |
| Full suite command | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Travellify.xcodeproj -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| ACT-07 | Toggling reminder ON schedules a request with matching UUID identifier | unit + integration | `-only-testing:TravellifyTests/ReminderLifecycleTests/scheduleOnEnable` | ❌ Wave 0 |
| ACT-07 | `fireDate = startAt - leadMinutes * 60` pure-fn correct | unit | `-only-testing:TravellifyTests/ReminderFireDateTests` | ❌ Wave 0 |
| ACT-07 | Schema additions additive + CloudKit-safe grep gate | unit | `-only-testing:TravellifyTests/ReminderSchemaTests` | ❌ Wave 0 |
| ACT-08 | Changing `startAt` reschedules same identifier | integration | `-only-testing:TravellifyTests/ReminderLifecycleTests/rescheduleOnDateChange` | ❌ Wave 0 |
| ACT-08 | Deleting activity removes its pending request | integration | `-only-testing:TravellifyTests/ReminderLifecycleTests/cancelOnDelete` | ❌ Wave 0 |
| ACT-08 | Trip cascade-delete removes pending requests of all its activities | integration | `-only-testing:TravellifyTests/ReminderLifecycleTests/cancelOnTripCascade` | ❌ Wave 0 |
| ACT-09 | `reconcile()` selects soonest-64 globally, ignores past | unit | `-only-testing:TravellifyTests/NotificationSchedulerTests/soonestSixtyFour` | ❌ Wave 0 |
| ACT-09 | `reconcile()` diff: adds new, removes stale, leaves matching | unit | `-only-testing:TravellifyTests/NotificationSchedulerTests/diffIdempotent` | ❌ Wave 0 |
| ACT-09 | Foreground-on-active triggers reconcile | UI (manual-accept) | Manual: fg/bg cycle + observe logs | manual-only |
| D53 | Priming sheet shown first time, skipped after `hasSeenReminderPriming` flip | unit (VM-level) | `-only-testing:TravellifyTests/PermissionStateTests` | ❌ Wave 0 |
| D54 | `.denied` authStatus disables toggle + shows Open Settings | unit | `-only-testing:TravellifyTests/PermissionStateTests/deniedShowsSettingsRow` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -only-testing:TravellifyTests/<specific-test-file>` (< 15s)
- **Per wave merge:** `xcodebuild test -scheme Travellify` (full suite)
- **Phase gate:** Full suite green + manual sim checklist (fg/bg reconcile, tap-to-deep-link, denied-then-Settings round-trip) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `TravellifyTests/NotificationSchedulerTests.swift` — with `MockNotificationCenter`
- [ ] `TravellifyTests/ReminderLifecycleTests.swift` — integration using in-memory `ModelContainer`
- [ ] `TravellifyTests/ReminderFireDateTests.swift`
- [ ] `TravellifyTests/ReminderSchemaTests.swift` — CloudKit-safe grep gate for new Activity fields
- [ ] `TravellifyTests/PermissionStateTests.swift`
- [ ] `TravellifyTests/Support/MockNotificationCenter.swift` — test-only shared fixture
- [ ] pbxproj: 4-entry registration for each new test file

## Risks & Pitfalls

### Pitfall 1: Completion-handler delegate crashes under Swift 6
**What goes wrong:** Using `userNotificationCenter(_:willPresent:withCompletionHandler:)` (old API) crashes with `__dispatch_queue_assert` on iOS 18 simulators under Swift 6. [CITED: Apple Forum 762217]
**Mitigation:** Use only the `async` variants.

### Pitfall 2: DateComponents without explicit timeZone
**What goes wrong:** `Calendar.current.dateComponents(...)` sometimes produces components that, when handed to `UNCalendarNotificationTrigger`, are interpreted in GMT, firing at the wrong hour.
**Mitigation:** Always set `components.timeZone = .current` before constructing the trigger. See §4 code snippet.

### Pitfall 3: Racing the 64-cap — don't assume `add()` fails loudly
**What goes wrong:** Apple declines to document what the 65th `add()` does. Treating it as "the system will sort it out" leads to silently lost reminders.
**Mitigation:** `reconcile()` must explicitly pre-select the soonest 64 and cancel evictees *before* adding new ones. D56 + D58 already require this.

### Pitfall 4: Crossing actors with `UNNotificationRequest`
**What goes wrong:** `UNNotificationRequest` and `UNMutableNotificationContent` are NOT `Sendable`; Swift 6 emits warnings if they cross actors.
**Mitigation:** Construct and consume on the same actor. `@MainActor final class NotificationScheduler` is the pragmatic shape.

### Pitfall 5: Reminder schedule inconsistency post-reinstall
**What goes wrong:** After uninstall/reinstall, iOS wipes pending requests; on first launch, user expects their existing activities (restored from backup) to have reminders.
**Mitigation:** `ScenePhase == .active` reconcile (D57) rebuilds from SwiftData on every foreground. No extra work.

### Pitfall 6: `ActivityEditSheet` edits fields that DON'T affect reminders — avoid needless reconciliation
**What goes wrong:** Calling `reconcile()` on every save (even title-only edits) does extra work.
**Mitigation:** Call `reconcile()` only when a save mutated `isReminderEnabled`, `reminderLeadMinutes`, or `startAt`. Track dirty flags in the sheet. Minor optimization; not blocking.

### Pitfall 7: `SchemaV1` drift — accidentally creating SchemaV2
**What goes wrong:** Adding a new `@Model` or changing field types would force a SchemaV2 migration. Not necessary here; D52 is pure additive `var` with defaults.
**Mitigation:** Schema grep test (`ReminderSchemaTests`) already specified — locks model count at 6 and asserts Activity has exactly the expected new fields with defaults.

### Pitfall 8: Nested sheet presentation quirks
**What goes wrong:** Priming sheet presented from inside the activity edit sheet. Rarely glitchy on iOS 17+.
**Mitigation:** If any visual hiccup, fall back to `.alert` or `.confirmationDialog` for priming. Both are valid UX choices.

### Pitfall 9: `@preconcurrency` is a stopgap — revisit on Swift 6.2
**What goes wrong:** `@preconcurrency` silences warnings but loses some type safety.
**Mitigation:** Track as tech debt. When Travellify upgrades to Swift 6.2, migrate to isolated conformance (`NSObject, @MainActor UNUserNotificationCenterDelegate`).

## Implementation Hints

### Core scheduler shape

```swift
// Travellify/Shared/NotificationScheduler.swift
import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center: NotificationCenterProtocol

    init(center: NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Idempotent. Brings iOS's pending requests into alignment with SwiftData user intent,
    /// capped at the soonest-64 globally by fireDate.
    func reconcile(modelContext: ModelContext) async {
        // 1) Gather user-intent
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.isReminderEnabled == true }
        )
        guard let allEnabled = try? modelContext.fetch(descriptor) else { return }

        let now = Date()
        let candidates = allEnabled
            .compactMap { activity -> (Activity, Date)? in
                guard let fireDate = ReminderFireDate.fireDate(for: activity),
                      fireDate > now else { return nil }
                return (activity, fireDate)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(64)

        let desiredIDs = Set(candidates.map { $0.0.id.uuidString })

        // 2) Fetch system truth
        let pending = await center.pendingNotificationRequests()
        let existingIDs = Set(pending.map(\.identifier))

        // 3) Diff
        let toCancel = existingIDs.subtracting(desiredIDs)
        let toSchedule = candidates.filter { !existingIDs.contains($0.0.id.uuidString) }

        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(toCancel))
        }

        for (activity, fireDate) in toSchedule {
            await schedule(activity: activity, fireDate: fireDate)
        }
    }

    private func schedule(activity: Activity, fireDate: Date) async {
        guard let trip = activity.trip else { return }

        let content = UNMutableNotificationContent()
        content.title = activity.title
        content.body = Self.body(for: activity, in: trip, fireDate: fireDate)
        content.sound = .default
        content.userInfo = ["activityID": activity.id.uuidString]

        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        components.timeZone = .current
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: activity.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // Log + continue; never abort the batch. (D's discretion item)
            #if DEBUG
            print("NotificationScheduler: failed to add \(activity.id): \(error)")
            #endif
        }
    }

    private static func body(for activity: Activity, in trip: Trip, fireDate: Date) -> String {
        var parts: [String] = [trip.name, ActivityDateLabels.timeLabel(for: activity.startAt)]
        if let location = activity.location, !location.isEmpty {
            parts.append(location)
        }
        return parts.joined(separator: " · ")
    }
}
```

### fireDate helper

```swift
// Travellify/Shared/ReminderFireDate.swift
enum ReminderFireDate {
    static func fireDate(for activity: Activity) -> Date? {
        guard activity.isReminderEnabled,
              let minutes = activity.reminderLeadMinutes else { return nil }
        return activity.startAt.addingTimeInterval(-TimeInterval(minutes * 60))
    }
}
```

### ReminderLeadTime preset enum

```swift
// Travellify/Shared/ReminderLeadTime.swift
enum ReminderLeadTime: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case oneHour = 60
    case threeHours = 180
    case oneDay = 1440

    var id: Int { rawValue }
    static let `default`: ReminderLeadTime = .oneHour   // D51

    var label: String {
        switch self {
        case .fifteenMinutes: "15 min before"
        case .oneHour: "1 hour before"
        case .threeHours: "3 hours before"
        case .oneDay: "1 day before"
        }
    }
}
```

### NotificationCenterProtocol

```swift
protocol NotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func notificationSettings() async -> UNNotificationSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNUserNotificationCenter: NotificationCenterProtocol {}
```

### AppDelegate + deep-link

See §2 and §12.

### ScenePhase reconcile hook

```swift
// TravellifyApp.swift body:
WindowGroup {
    ContentView()
}
.onChange(of: scenePhase) { _, new in
    if new == .active {
        Task { @MainActor in
            await NotificationScheduler.shared.reconcile(modelContext: modelContainer.mainContext)
        }
    }
}
```

## Canonical URLs

- [UNUserNotificationCenter — Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) (HIGH)
- [UNCalendarNotificationTrigger — Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger) (HIGH)
- [getPendingNotificationRequests — Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/getpendingnotificationrequests(completionhandler:)) (HIGH)
- [removePendingNotificationRequests(withIdentifiers:) — Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/removependingnotificationrequests(withidentifiers:)) (HIGH)
- [requestAuthorization(options:completionHandler:) — Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:)) (HIGH)
- [Local and Remote Notification Programming Guide (archive)](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html) (HIGH, but archive)
- [Apple Forum — 64-notification limit confirmation](https://developer.apple.com/forums/thread/811171) (MEDIUM — Apple engineer on forum)
- [Apple Forum — UNUserNotificationCenterDelegate Swift 6 patterns](https://developer.apple.com/forums/thread/762217) (MEDIUM)
- [Apple Forum — Swift 6 Crash with UNUserNotificationCenter](https://developer.apple.com/forums/thread/796407) (MEDIUM)
- [Swift with Majid — Deep linking for local notifications in SwiftUI](https://swiftwithmajid.com/2024/04/09/deep-linking-for-local-notifications-in-swiftui/) (HIGH — verified against Apple docs)
- [Donny Wals — Scheduling daily notifications with Calendar and DateComponents](https://www.donnywals.com/scheduling-daily-notifications-on-ios-using-calendar-and-datecomponents/) (HIGH)
- [Two Cent Studios — Swift Concurrency Challenges (isolated conformances for notification delegates)](https://twocentstudios.com/2025/08/12/3-swift-concurrency-challenges-from-the-last-2-weeks/) (MEDIUM)
- [Michael Tsai — MainActor.assumeIsolated, Preconcurrency, Isolated Conformances](https://mjtsai.com/blog/2025/11/07/mainactor-assumeisolated-preconcurrency-and-isolated-conformances/) (MEDIUM)
- [Hacking with Swift — UNUserNotificationCenter tutorial](https://www.hackingwithswift.com/read/21/2/scheduling-notifications-unusernotificationcenter-and-unnotificationrequest) (HIGH)
- [Apple Forum — NavigationPath + @Observable binding issue](https://developer.apple.com/forums/thread/733238) (HIGH — documents the known @Observable+NavigationPath gotcha)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Nested sheet (priming inside edit sheet) renders correctly on iOS 17+. | §7 | Priming UX needs a fullScreenCover / alert fallback; cheap to swap. |
| A2 | `UNNotificationRequest` identifier has no practical length cap for 36-char UUID strings. | §11 | Identifiers could be rejected silently; unlikely, but `hasPrefix("activity-")` could mitigate. |

All other claims are either tagged `[CITED]` from the source list above, or verified by direct Apple docs lookup.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — UNUserNotificationCenter, UNCalendarNotificationTrigger, UNNotificationRequest, requestAuthorization, notificationSettings
- Apple Local and Remote Notification Programming Guide (archive)
- swiftwithmajid.com (2024) — deep-link local notification pattern
- donnywals.com — Calendar + DateComponents scheduling

### Secondary (MEDIUM confidence — Apple engineer forum replies, cross-verified)
- Apple Developer Forums threads 811171 (64-cap), 762217 (Swift 6 delegate), 796407 (crash)
- twocentstudios.com — 2025 Swift 6 concurrency patterns
- mjtsai.com — 2025 preconcurrency / isolated conformances

### Tertiary (LOW — used only for directional context, not for factual claims)
- Various Medium / dev.to tutorials — cross-verified before inclusion

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — locked by CONTEXT; verified against Apple's UserNotifications docs.
- Architecture: HIGH — patterns sourced from Apple + Swift with Majid; verified code shapes compile under Swift 6.0.
- Pitfalls: HIGH for lifecycle/concurrency; MEDIUM for the 64-cap eviction rule (Apple declines to document).

**Research date:** 2026-04-22
**Valid until:** 2026-05-22 (30 days — stable UserNotifications API; revisit if Swift 6.2 upgrade happens, which would let us adopt isolated conformances).

## RESEARCH COMPLETE
