import Testing
import Foundation
@testable import Travellify

@MainActor
struct ReminderFireDateTests {

    private var fixedStart: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    // MARK: - ReminderLeadTime invariants

    @Test func leadTimeRawValuesMatchPresets() {
        #expect(ReminderLeadTime.allCases.map(\.rawValue) == [15, 60, 180, 1440])
    }

    @Test func leadTimeDefaultIsOneHour() {
        #expect(ReminderLeadTime.default == .oneHour)
        #expect(ReminderLeadTime.default.rawValue == 60)
    }

    // MARK: - ReminderFireDate.fireDate

    @Test func fireDateIsStartAtMinusLeadWhenEnabled() {
        let a = Activity()
        a.startAt = fixedStart
        a.isReminderEnabled = true
        a.reminderLeadMinutes = 60
        let expected = fixedStart.addingTimeInterval(-TimeInterval(60 * 60))
        #expect(ReminderFireDate.fireDate(for: a) == expected)
    }

    @Test func fireDateIsNilWhenReminderDisabled() {
        let a = Activity()
        a.startAt = fixedStart
        a.isReminderEnabled = false
        a.reminderLeadMinutes = 60
        #expect(ReminderFireDate.fireDate(for: a) == nil)
    }

    @Test func fireDateIsNilWhenLeadMinutesNil() {
        let a = Activity()
        a.startAt = fixedStart
        a.isReminderEnabled = true
        a.reminderLeadMinutes = nil
        #expect(ReminderFireDate.fireDate(for: a) == nil)
    }

    @Test func fireDateAcrossDSTIsAbsoluteTimeMath() {
        // DST spring-forward at 2026-03-08 02:00 US/Pacific — schedule 1 day
        // lead-time across the boundary. Result is absolute subtraction (1440*60
        // seconds), NOT wall-clock — UNCalendarNotificationTrigger handles DST.
        let springForward = ISO8601DateFormatter().date(from: "2026-03-09T10:00:00Z")!
        let a = Activity()
        a.startAt = springForward
        a.isReminderEnabled = true
        a.reminderLeadMinutes = 1440
        let expected = springForward.addingTimeInterval(-TimeInterval(1440 * 60))
        #expect(ReminderFireDate.fireDate(for: a) == expected)
    }
}
