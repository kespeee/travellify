import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct NextUpcomingTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            configurations: config
        )
    }

    private func makeTrip(in context: ModelContext) -> Trip {
        let trip = Trip()
        trip.name = "Rome 2026"
        trip.startDate = Date().addingTimeInterval(-86_400)
        trip.endDate = Date().addingTimeInterval(86_400 * 10)
        context.insert(trip)
        return trip
    }

    /// Anchors `now` to 09:00 of today so calendar-day-relative offsets
    /// (`+3h`, `+25h`, `+5d`) stay within the asserted bucket regardless of
    /// when the suite runs. Avoids a midnight-rollover flake.
    private func stableNow() -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func insertActivity(title: String,
                                startAt: Date,
                                createdAt: Date? = nil,
                                trip: Trip,
                                in context: ModelContext) {
        let a = Activity()
        a.title = title
        a.startAt = startAt
        if let createdAt { a.createdAt = createdAt }
        a.trip = trip
        context.insert(a)
    }

    @Test func emptyTripReturnsNoActivitiesYet() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)
        try ctx.save()

        let msg = ActivityDateLabels.activitiesMessage(for: trip, now: Date())
        #expect(msg == "No activities yet")
    }

    @Test func oneUpcomingTodayProducesTodayNextMessage() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let now = stableNow()
        let later = now.addingTimeInterval(3 * 3600)
        insertActivity(title: "Louvre tour", startAt: later, trip: trip, in: ctx)
        try ctx.save()

        let msg = ActivityDateLabels.activitiesMessage(for: trip, now: now)
        #expect(msg.hasPrefix("Next: "), "got \(msg)")
        #expect(msg.contains("Louvre tour"), "got \(msg)")
        #expect(msg.contains(" · Today at "), "got \(msg)")
    }

    @Test func oneUpcomingTomorrowProducesTomorrowNextMessage() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let now = stableNow()
        let tomorrow = now.addingTimeInterval(86_400 + 3600)
        insertActivity(title: "Seine cruise", startAt: tomorrow, trip: trip, in: ctx)
        try ctx.save()

        let msg = ActivityDateLabels.activitiesMessage(for: trip, now: now)
        #expect(msg.contains("Seine cruise"))
        #expect(msg.contains(" · Tomorrow at "), "got \(msg)")
    }

    @Test func oneUpcomingFiveDaysOutUsesDistantRelative() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let now = stableNow()
        let future = now.addingTimeInterval(5 * 86_400)
        insertActivity(title: "Colosseum", startAt: future, trip: trip, in: ctx)
        try ctx.save()

        let msg = ActivityDateLabels.activitiesMessage(for: trip, now: now)
        #expect(msg.hasPrefix("Next: "))
        #expect(msg.contains("Colosseum"))
        #expect(!msg.contains("Today"), "got \(msg)")
        #expect(!msg.contains("Tomorrow"), "got \(msg)")
        #expect(msg.contains(" at "), "got \(msg)")
    }

    @Test func allPastActivitiesProduceCountMessage() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let now = stableNow()
        insertActivity(title: "Arrival", startAt: now.addingTimeInterval(-3 * 3600), trip: trip, in: ctx)
        try ctx.save()

        let msg1 = ActivityDateLabels.activitiesMessage(for: trip, now: now)
        #expect(msg1 == "1 activity", "got \(msg1)")

        insertActivity(title: "Lunch",  startAt: now.addingTimeInterval(-2 * 3600), trip: trip, in: ctx)
        insertActivity(title: "Walk",   startAt: now.addingTimeInterval(-1 * 3600), trip: trip, in: ctx)
        try ctx.save()

        let msg3 = ActivityDateLabels.activitiesMessage(for: trip, now: now)
        #expect(msg3 == "3 activities", "got \(msg3)")
    }

    @Test func equalStartAtTiebreakByCreatedAtChoosesEarlierCreated() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let now = stableNow()
        let shared = now.addingTimeInterval(2 * 3600)

        insertActivity(title: "Later created",
                       startAt: shared,
                       createdAt: now.addingTimeInterval(-10),
                       trip: trip,
                       in: ctx)
        insertActivity(title: "Earlier created",
                       startAt: shared,
                       createdAt: now.addingTimeInterval(-1000),
                       trip: trip,
                       in: ctx)
        try ctx.save()

        let msg = ActivityDateLabels.activitiesMessage(for: trip, now: now)
        #expect(msg.contains("Earlier created"), "got \(msg)")
        #expect(!msg.contains("Later created"), "got \(msg)")
    }

    @Test func mixOfPastAndFutureChoosesFutureAsNext() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let now = stableNow()
        insertActivity(title: "Past item",   startAt: now.addingTimeInterval(-3600), trip: trip, in: ctx)
        insertActivity(title: "Future item", startAt: now.addingTimeInterval( 3600), trip: trip, in: ctx)
        try ctx.save()

        let msg = ActivityDateLabels.activitiesMessage(for: trip, now: now)
        #expect(msg.hasPrefix("Next: "))
        #expect(msg.contains("Future item"), "got \(msg)")
        #expect(!msg.contains("Past item"), "got \(msg)")
    }
}
