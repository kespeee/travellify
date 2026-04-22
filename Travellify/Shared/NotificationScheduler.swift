import Foundation
import SwiftData
import UserNotifications

/// Single mutation entry for the notification subsystem. Reconciles user
/// intent (SwiftData `Activity.isReminderEnabled` + `reminderLeadMinutes`)
/// against system truth (`UNUserNotificationCenter.pendingNotificationRequests`),
/// capped at the soonest 64 globally by `fireDate`.
///
/// All construction of `UNMutableNotificationContent` / `UNNotificationRequest`
/// happens on `@MainActor`; these types are NOT Sendable under Swift 6, so they
/// never cross actor boundaries (RESEARCH §6).
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center: NotificationCenterProtocol

    init(center: NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Idempotent. Brings iOS's pending requests into alignment with SwiftData
    /// user intent, capped at the soonest-64 globally by fireDate.
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
        let pendingByID = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })

        // 3) Diff. ACT-08 requires reschedule-on-edit: if a request already exists
        // under the same identifier but its trigger's fireDate no longer matches
        // our desired fireDate (e.g. user edited startAt or leadMinutes), cancel
        // and re-add it.
        let toCancelMissing = existingIDs.subtracting(desiredIDs)
        var toCancelStale: Set<String> = []
        var toSchedule: [(Activity, Date)] = []

        for (activity, desiredFireDate) in candidates {
            let id = activity.id.uuidString
            if let existing = pendingByID[id] {
                if Self.triggerFireDate(existing.trigger) != Self.normalizedComponents(from: desiredFireDate) {
                    toCancelStale.insert(id)
                    toSchedule.append((activity, desiredFireDate))
                }
            } else {
                toSchedule.append((activity, desiredFireDate))
            }
        }

        let toCancel = toCancelMissing.union(toCancelStale)
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(toCancel))
        }

        for (activity, fireDate) in toSchedule {
            await schedule(activity: activity, fireDate: fireDate)
        }
    }

    /// Normalized components for equality comparison across reconcile() calls.
    private static func normalizedComponents(from date: Date) -> DateComponents {
        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        components.timeZone = .current
        // Strip calendar/timezone identity for pure component comparison.
        var plain = DateComponents()
        plain.year = components.year
        plain.month = components.month
        plain.day = components.day
        plain.hour = components.hour
        plain.minute = components.minute
        return plain
    }

    private static func triggerFireDate(_ trigger: UNNotificationTrigger?) -> DateComponents? {
        guard let cal = trigger as? UNCalendarNotificationTrigger else { return nil }
        var plain = DateComponents()
        plain.year = cal.dateComponents.year
        plain.month = cal.dateComponents.month
        plain.day = cal.dateComponents.day
        plain.hour = cal.dateComponents.hour
        plain.minute = cal.dateComponents.minute
        return plain
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
        components.timeZone = .current    // CRITICAL — else GMT interpretation (RESEARCH §4)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: activity.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
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
