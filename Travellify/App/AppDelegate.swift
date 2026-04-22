import SwiftUI
import UserNotifications

/// UIKit bridge so we can install a `UNUserNotificationCenterDelegate`.
/// SwiftUI's `App` protocol has no delegate slot; `@UIApplicationDelegateAdaptor`
/// from `TravellifyApp` wires this class up at launch.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

// @preconcurrency required under Swift 6.0 (Travellify's mode).
// Always use the async delegate variants — completion-handler forms
// can crash with __dispatch_queue_assert per Apple Forum 762217
// (RESEARCH Pitfall 1 / 9; migrate to Swift 6.2 isolated conformance when Xcode upgrades).
extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
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
