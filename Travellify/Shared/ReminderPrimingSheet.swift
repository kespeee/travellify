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

    /// D53 + D55: the priming sheet appears on the first-ever toggle-on when
    /// the system status is still `.notDetermined` AND we have not yet shown
    /// the priming sheet. Subsequent toggle-ons go straight to the system
    /// dialog (or skip it entirely once resolved).
    static func shouldShowPrimingOnToggleOn(
        authStatus: UNAuthorizationStatus,
        hasSeenPriming: Bool
    ) -> Bool {
        authStatus == .notDetermined && !hasSeenPriming
    }
}

/// One-shot priming sheet presented from ActivityEditSheet on the first
/// toggle-on when UNAuthorizationStatus == .notDetermined (D53). Dismissing
/// flips UserDefaults["hasSeenReminderPriming"] = true regardless of outcome (D55).
struct ReminderPrimingSheet: View {
    let onEnable: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 40)

            VStack(spacing: 8) {
                Text("Travellify wants to send reminders")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Get a heads-up before each activity so you're never late.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 8)

            VStack(spacing: 12) {
                Button(action: onEnable) {
                    Text("Enable reminders")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Not now", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
    }
}

#if DEBUG
#Preview {
    ReminderPrimingSheet(onEnable: {}, onCancel: {})
}
#endif
