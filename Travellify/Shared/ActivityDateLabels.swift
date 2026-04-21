import Foundation

/// Pure-static date label helpers for Activities. All public functions take
/// injectable `now: Date` and `calendar: Calendar` defaults so tests can pass
/// fixed values. Formatters are allocated once per app lifetime (RESEARCH Pitfall 1).
enum ActivityDateLabels {

    // MARK: - Cached formatters

    private static let weekdayAndDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE, MMM d")   // "Mon, Apr 22"
        return f
    }()

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMM d")        // "Apr 22"
        return f
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .none
        f.timeStyle = .short                                 // "2:00 PM"
        return f
    }()

    // MARK: - Day + time labels

    /// Section-header label: "Today · Apr 22" / "Tomorrow · Apr 23" /
    /// "Yesterday · Apr 21" / "Mon, Apr 22".
    static func dayLabel(for day: Date,
                         now: Date = Date(),
                         calendar: Calendar = .current) -> String {
        var cal = calendar
        if calendar.timeZone != Calendar.current.timeZone {
            cal.timeZone = calendar.timeZone
        }
        if cal.isDateInToday(day) {
            return "Today · \(monthDayFormatter.string(from: day))"
        }
        if cal.isDateInTomorrow(day) {
            return "Tomorrow · \(monthDayFormatter.string(from: day))"
        }
        if cal.isDateInYesterday(day) {
            return "Yesterday · \(monthDayFormatter.string(from: day))"
        }
        return weekdayAndDateFormatter.string(from: day)
    }

    /// Row-level time label: "2:00 PM" (locale-aware short).
    static func timeLabel(for date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    /// TripDetail card "short" relative day: "Today" / "Tomorrow" / "Apr 23".
    /// No compound "· date" suffix — the card uses a tighter message than
    /// the list section header.
    static func shortRelativeDay(for date: Date,
                                 now: Date = Date(),
                                 calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return monthDayFormatter.string(from: date)
    }

    // MARK: - Default startAt (D44)

    /// Next top-of-hour after `date` — zeroes minutes and seconds.
    static func nextTopOfHour(after date: Date,
                              calendar: Calendar = .current) -> Date {
        let plusOneHour = calendar.date(byAdding: .hour, value: 1, to: date) ?? date
        let minutesZero = calendar.date(bySetting: .minute, value: 0, of: plusOneHour) ?? plusOneHour
        return calendar.date(bySetting: .second, value: 0, of: minutesZero) ?? minutesZero
    }

    /// D44 priority:
    /// 1. Future trip → trip.startDate at 09:00.
    /// 2. Today ∈ [trip.startDate, trip.endDate] → now rounded up to next top-of-hour.
    /// 3. Past trip → now rounded up to next top-of-hour.
    static func defaultStartAt(for trip: Trip,
                               now: Date = Date(),
                               calendar: Calendar = .current) -> Date {
        if trip.startDate > now {
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: trip.startDate)
                ?? trip.startDate
        }
        return nextTopOfHour(after: now, calendar: calendar)
    }

    // MARK: - TripDetail card message (D46)

    /// D46:
    /// - empty → "No activities yet"
    /// - upcoming present → "Next: <title> · <relativeDay> at <time>"
    /// - all past → "<count> activity" / "<count> activities"
    static func activitiesMessage(for trip: Trip,
                                  now: Date = Date(),
                                  calendar: Calendar = .current) -> String {
        let activities = trip.activities ?? []
        if activities.isEmpty { return "No activities yet" }

        let upcoming = activities
            .filter { $0.startAt >= now }
            .sorted { a, b in
                if a.startAt != b.startAt { return a.startAt < b.startAt }
                return a.createdAt < b.createdAt
            }

        if let next = upcoming.first {
            let relative = shortRelativeDay(for: next.startAt, now: now, calendar: calendar)
            let time = timeLabel(for: next.startAt)
            return "Next: \(next.title) · \(relative) at \(time)"
        }

        let count = activities.count
        return "\(count) activit\(count == 1 ? "y" : "ies")"
    }
}
