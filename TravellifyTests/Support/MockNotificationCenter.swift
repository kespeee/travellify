import Foundation
@preconcurrency import UserNotifications
@testable import Travellify

/// @MainActor fixture. UNNotificationRequest is NOT Sendable, so we keep all
/// mutations on the main actor. `nonisolated` wrappers bridge the async
/// protocol surface into main-actor state (RESEARCH §10).
@MainActor
final class MockNotificationCenter: NotificationCenterProtocol {
    var pending: [UNNotificationRequest] = []
    var authStatus: UNAuthorizationStatus = .authorized
    var shouldThrowOnAdd: Bool = false

    nonisolated func add(_ request: UNNotificationRequest) async throws {
        if await MainActor.run(body: { self.shouldThrowOnAdd }) {
            throw NSError(domain: "MockNotificationCenter", code: 1)
        }
        await MainActor.run { self.pending.append(request) }
    }

    nonisolated func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await MainActor.run { self.pending }
    }

    nonisolated func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        let ids = Set(identifiers)
        Task { @MainActor in
            self.pending.removeAll { ids.contains($0.identifier) }
        }
    }

    nonisolated func notificationSettings() async -> UNNotificationSettings {
        // UNNotificationSettings has no public init; tests that need settings
        // shape can subclass or assert only on authStatus via a side channel.
        // Kept as a stub that calls through on current() — tests should not
        // rely on this method on the mock.
        await UNUserNotificationCenter.current().notificationSettings()
    }

    nonisolated func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        let granted = await MainActor.run { self.authStatus == .authorized }
        return granted
    }
}
