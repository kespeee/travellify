import Foundation
import UserNotifications

/// Minimal abstraction over UNUserNotificationCenter so NotificationScheduler
/// is testable with a mock. The real UNUserNotificationCenter is Sendable, so
/// declaring the protocol Sendable is safe (RESEARCH §10).
protocol NotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func notificationSettings() async -> UNNotificationSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNUserNotificationCenter: NotificationCenterProtocol {}
