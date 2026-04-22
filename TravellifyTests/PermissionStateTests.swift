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

}
