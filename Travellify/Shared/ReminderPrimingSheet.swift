import SwiftUI
import UserNotifications

/// VM-level helper for deriving Reminder Section UI state from a
/// `UNAuthorizationStatus` + the `hasSeenReminderPriming` one-shot flag.
///
/// Kept as a pure-function enum so `PermissionStateTests` can exercise it
/// directly without touching the real `UNUserNotificationCenter`.
enum ReminderPermissionState {
    /// D54: the `Toggle` is disabled only when the user has explicitly denied.
    static func isToggleDisabled(authStatus: UNAuthorizationStatus) -> Bool {
        authStatus == .denied
    }

    /// D54: the "Notifications disabled." row + "Open Settings" button appear
    /// only in the denied state.
    static func shouldShowOpenSettingsRow(authStatus: UNAuthorizationStatus) -> Bool {
        authStatus == .denied
    }

}
