import Foundation

/// Pure helper. Absolute-time arithmetic: `start - leadMinutes*60`.
/// DST correctness is handled downstream by UNCalendarNotificationTrigger
/// (per RESEARCH §4). Returns nil when the user hasn't opted in.
enum ReminderFireDate {
    /// Primitive fire-date computation — pure Date math, no @Model access.
    static func fireDate(start: Date, leadMinutes: Int) -> Date {
        start.addingTimeInterval(-TimeInterval(leadMinutes * 60))
    }

    static func fireDate(for activity: Activity) -> Date? {
        guard activity.isReminderEnabled,
              let minutes = activity.reminderLeadMinutes else { return nil }
        return fireDate(start: activity.startAt, leadMinutes: minutes)
    }

    static func fireDate(for trip: Trip) -> Date? {
        guard trip.isReminderEnabled,
              let minutes = trip.reminderLeadMinutes else { return nil }
        return fireDate(start: trip.startDate, leadMinutes: minutes)
    }
}
