import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct TripReminderFireDateTests {

    private var fixedStart: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            configurations: config
        )
    }

    @Test func enumRawValuesMatchMinutes() {
        #expect(TripReminderLeadTime.allCases.map(\.rawValue) == [1440, 4320, 10080, 20160])
    }

    @Test func defaultIsThreeDays() {
        #expect(TripReminderLeadTime.default == .threeDays)
        #expect(TripReminderLeadTime.default.rawValue == 4320)
    }

    @Test func fireDateIsStartMinusLeadWhenEnabled() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let t = Trip()
        t.name = "Paris"
        t.startDate = fixedStart
        t.endDate = fixedStart.addingTimeInterval(86_400 * 7)
        t.isReminderEnabled = true
        t.reminderLeadMinutes = 1440
        ctx.insert(t)
        let expected = fixedStart.addingTimeInterval(-TimeInterval(1440 * 60))
        #expect(ReminderFireDate.fireDate(for: t) == expected)
    }

    @Test func fireDateIsNilWhenDisabled() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let t = Trip()
        t.startDate = fixedStart
        t.endDate = fixedStart.addingTimeInterval(86_400)
        t.isReminderEnabled = false
        t.reminderLeadMinutes = 1440
        ctx.insert(t)
        #expect(ReminderFireDate.fireDate(for: t) == nil)
    }

    @Test func fireDateIsNilWhenLeadMinutesMissing() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let t = Trip()
        t.startDate = fixedStart
        t.endDate = fixedStart.addingTimeInterval(86_400)
        t.isReminderEnabled = true
        t.reminderLeadMinutes = nil
        ctx.insert(t)
        #expect(ReminderFireDate.fireDate(for: t) == nil)
    }
}
