import Testing
import Foundation
@testable import Travellify

@MainActor
struct DayLabelTests {

    private var utcGregorian: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }

    private var fixedNow: Date {
        ISO8601DateFormatter().date(from: "2026-04-22T12:00:00Z")!
    }

    private func startOfDay(_ iso: String) -> Date {
        let d = ISO8601DateFormatter().date(from: iso)!
        return utcGregorian.startOfDay(for: d)
    }

    @Test func todayLabelHasTodayPrefix() {
        let today = startOfDay("2026-04-22T00:00:00Z")
        let label = ActivityDateLabels.dayLabel(for: today, now: fixedNow, calendar: utcGregorian)
        #expect(label.hasPrefix("Today · "),
                "Expected 'Today · …' got \(label)")
    }

    @Test func tomorrowLabelHasTomorrowPrefix() {
        let tomorrow = startOfDay("2026-04-23T00:00:00Z")
        let label = ActivityDateLabels.dayLabel(for: tomorrow, now: fixedNow, calendar: utcGregorian)
        #expect(label.hasPrefix("Tomorrow · "),
                "Expected 'Tomorrow · …' got \(label)")
    }

    @Test func yesterdayLabelHasYesterdayPrefix() {
        let yesterday = startOfDay("2026-04-21T00:00:00Z")
        let label = ActivityDateLabels.dayLabel(for: yesterday, now: fixedNow, calendar: utcGregorian)
        #expect(label.hasPrefix("Yesterday · "),
                "Expected 'Yesterday · …' got \(label)")
    }

    @Test func distantDateUsesWeekdayDateForm() {
        let fiveOut = startOfDay("2026-04-27T00:00:00Z")
        let label = ActivityDateLabels.dayLabel(for: fiveOut, now: fixedNow, calendar: utcGregorian)
        #expect(!label.hasPrefix("Today"))
        #expect(!label.hasPrefix("Tomorrow"))
        #expect(!label.hasPrefix("Yesterday"))
        // Locale en_US_POSIX → "Mon, Apr 27" shape; verify comma presence as a cheap proxy.
        #expect(label.contains(","),
                "Expected 'EEE, MMM d' form with a comma, got \(label)")
    }

    @Test func shortRelativeDayMatchesRules() {
        let today = startOfDay("2026-04-22T00:00:00Z")
        let tomorrow = startOfDay("2026-04-23T00:00:00Z")
        let fiveOut = startOfDay("2026-04-27T00:00:00Z")
        #expect(ActivityDateLabels.shortRelativeDay(for: today, now: fixedNow, calendar: utcGregorian) == "Today")
        #expect(ActivityDateLabels.shortRelativeDay(for: tomorrow, now: fixedNow, calendar: utcGregorian) == "Tomorrow")
        let distant = ActivityDateLabels.shortRelativeDay(for: fiveOut, now: fixedNow, calendar: utcGregorian)
        #expect(distant != "Today" && distant != "Tomorrow")
    }
}
