import Testing
import Foundation
import UserNotifications
@testable import Travellify

@MainActor
struct PermissionStateTests {

    // MARK: Toggle enable/disable derivation (D54)

    @Test func notDeterminedEnablesToggle() {
        #expect(ReminderPermissionState.isToggleDisabled(authStatus: .notDetermined) == false)
    }

    @Test func authorizedEnablesToggle() {
        #expect(ReminderPermissionState.isToggleDisabled(authStatus: .authorized) == false)
    }

    @Test func deniedDisablesToggle() {
        #expect(ReminderPermissionState.isToggleDisabled(authStatus: .denied) == true)
    }

    // MARK: Open-Settings row visibility (D54)

    @Test func deniedShowsSettingsRow() {
        #expect(ReminderPermissionState.shouldShowOpenSettingsRow(authStatus: .denied) == true)
    }

    @Test func authorizedHidesSettingsRow() {
        #expect(ReminderPermissionState.shouldShowOpenSettingsRow(authStatus: .authorized) == false)
    }

    // MARK: Priming gating (D53 + D55)

    @Test func primingGatingFirstTimeOnly() {
        // First-ever toggle-on with .notDetermined → priming sheet appears.
        #expect(
            ReminderPermissionState.shouldShowPrimingOnToggleOn(
                authStatus: .notDetermined,
                hasSeenPriming: false
            ) == true
        )

        // Once the one-shot flag is set, even a still-.notDetermined status
        // goes straight to the system dialog.
        #expect(
            ReminderPermissionState.shouldShowPrimingOnToggleOn(
                authStatus: .notDetermined,
                hasSeenPriming: true
            ) == false
        )

        // And any resolved status skips priming regardless.
        #expect(
            ReminderPermissionState.shouldShowPrimingOnToggleOn(
                authStatus: .authorized,
                hasSeenPriming: false
            ) == false
        )
        #expect(
            ReminderPermissionState.shouldShowPrimingOnToggleOn(
                authStatus: .denied,
                hasSeenPriming: false
            ) == false
        )
    }
}
