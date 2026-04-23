import Foundation
import SwiftData
import UserNotifications

/// Single mutation entry for the notification subsystem. Reconciles user
/// intent (SwiftData `Activity.isReminderEnabled` / `Trip.isReminderEnabled`)
/// against system truth (`UNUserNotificationCenter.pendingNotificationRequests`),
/// capped at the soonest 64 globally by `fireDate` ACROSS the union of both.
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

    /// Union element for Trip + Activity reminder scheduling.
    /// All @Model access happens once during gather; pipeline then operates on pure values.
    private struct ScheduledReminder {
        enum Kind { case activity, trip }
        let kind: Kind
        let identifier: String         // "trip-<uuid>" or "<activity-uuid>"
        let fireDate: Date
        let title: String
        let body: String
        let userInfoKey: String        // "tripID" or "activityID"
        let userInfoValue: String      // BARE uuid string (never prefixed)
    }

    /// Idempotent. Brings iOS's pending requests into alignment with SwiftData
    /// user intent, capped at the soonest-64 globally by fireDate across the
    /// Trip+Activity union (D79 / TRIP-09).
    func reconcile(modelContext: ModelContext) async {
        // 1) Gather user-intent across BOTH models
        let activityDescriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.isReminderEnabled == true }
        )
        let tripDescriptor = FetchDescriptor<Trip>(
            predicate: #Predicate { $0.isReminderEnabled == true }
        )
        let activities = (try? modelContext.fetch(activityDescriptor)) ?? []
        let trips = (try? modelContext.fetch(tripDescriptor)) ?? []
        let now = Date()

        let activityReminders: [ScheduledReminder] = activities.compactMap { a in
            guard let fire = ReminderFireDate.fireDate(for: a), fire > now,
                  let trip = a.trip else { return nil }
            return ScheduledReminder(
                kind: .activity,
                identifier: a.id.uuidString,
                fireDate: fire,
                title: a.title,
                body: Self.activityBody(activity: a, trip: trip),
                userInfoKey: "activityID",
                userInfoValue: a.id.uuidString
            )
        }

        let tripReminders: [ScheduledReminder] = trips.compactMap { t in
            guard let fire = ReminderFireDate.fireDate(for: t), fire > now,
                  let minutes = t.reminderLeadMinutes,
                  let preset = TripReminderLeadTime(rawValue: minutes) else { return nil }
            return ScheduledReminder(
                kind: .trip,
                identifier: "trip-\(t.id.uuidString)",
                fireDate: fire,
                title: "Trip starting soon",
                body: "\(t.name) · \(preset.bodyPhrase)",
                userInfoKey: "tripID",
                userInfoValue: t.id.uuidString
            )
        }

        // SINGLE sort + cap across the union (research landmine #1 — never bucket-then-cap)
        let candidates = Array(
            (activityReminders + tripReminders)
                .sorted { $0.fireDate < $1.fireDate }
                .prefix(64)
        )

        let desiredIDs = Set(candidates.map { $0.identifier })

        // 2) Fetch system truth
        let pending = await center.pendingNotificationRequests()
        let existingIDs = Set(pending.map(\.identifier))
        let pendingByID = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })

        // 3) Diff. Preserves Phase 5 Rule 1 fire-date drift detection — identifier
        // already distinguishes `trip-<uuid>` vs bare `<activity-uuid>`.
        let toCancelMissing = existingIDs.subtracting(desiredIDs)
        var toCancelStale: Set<String> = []
        var toSchedule: [ScheduledReminder] = []

        for reminder in candidates {
            let id = reminder.identifier
            if let existing = pendingByID[id] {
                if Self.triggerFireDate(existing.trigger) != Self.normalizedComponents(from: reminder.fireDate) {
                    toCancelStale.insert(id)
                    toSchedule.append(reminder)
                }
            } else {
                toSchedule.append(reminder)
            }
        }

        let toCancel = toCancelMissing.union(toCancelStale)
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(toCancel))
        }

        for reminder in toSchedule {
            await schedule(reminder: reminder)
        }
    }

    /// Normalized components for equality comparison across reconcile() calls.
    private static func normalizedComponents(from date: Date) -> DateComponents {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
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

    private func schedule(reminder: ScheduledReminder) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.userInfo = [reminder.userInfoKey: reminder.userInfoValue]

        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.fireDate
        )
        components.timeZone = .current    // CRITICAL — else GMT interpretation (RESEARCH §4)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: reminder.identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            #if DEBUG
            print("NotificationScheduler: failed to add \(reminder.identifier): \(error)")
            #endif
        }
    }

    private static func activityBody(activity: Activity, trip: Trip) -> String {
        var parts: [String] = [trip.name, ActivityDateLabels.timeLabel(for: activity.startAt)]
        if let location = activity.location, !location.isEmpty {
            parts.append(location)
        }
        return parts.joined(separator: " · ")
    }
}
