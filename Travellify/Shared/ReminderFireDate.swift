import Foundation

/// Pure helper. Absolute-time arithmetic: `startAt - leadMinutes*60`.
/// DST correctness is handled downstream by UNCalendarNotificationTrigger
/// (per RESEARCH §4). Returns nil when the user hasn't opted in.
enum ReminderFireDate {
    static func fireDate(for activity: Activity) -> Date? {
        guard activity.isReminderEnabled,
              let minutes = activity.reminderLeadMinutes else { return nil }
        return activity.startAt.addingTimeInterval(-TimeInterval(minutes * 60))
    }
}
