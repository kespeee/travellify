import Testing
import SwiftData
import Foundation
@preconcurrency import UserNotifications
@testable import Travellify

@MainActor
struct NotificationSchedulerTests {

    // MARK: - Fixtures

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            configurations: config
        )
    }

    private func makeTrip(name: String = "Rome 2026",
                          in context: ModelContext) -> Trip {
        let trip = Trip()
        trip.name = name
        trip.startDate = Date().addingTimeInterval(-86_400)
        trip.endDate = Date().addingTimeInterval(86_400 * 365)
        context.insert(trip)
        return trip
    }

    @discardableResult
    private func insertActivity(title: String,
                                startAt: Date,
                                leadMinutes: Int? = 60,
                                enabled: Bool = true,
                                location: String? = nil,
                                trip: Trip,
                                in context: ModelContext) -> Activity {
        let a = Activity()
        a.title = title
        a.startAt = startAt
        a.location = location
        a.trip = trip
        a.isReminderEnabled = enabled
        a.reminderLeadMinutes = leadMinutes
        context.insert(a)
        return a
    }

    @discardableResult
    private func insertTripReminder(name: String,
                                    startDate: Date,
                                    leadMinutes: Int = 4320,
                                    in context: ModelContext) -> Trip {
        let t = Trip()
        t.name = name
        t.startDate = startDate
        t.endDate = startDate.addingTimeInterval(86_400 * 7)
        t.isReminderEnabled = true
        t.reminderLeadMinutes = leadMinutes
        context.insert(t)
        return t
    }

    // MARK: - Tests

    @Test func soonestSixtyFour() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        // Seed 100 future activities at staggered times.
        // lead = 60 min, so fireDate = startAt - 1h. Spread startAt 2..101 hours out.
        var uuids: [(UUID, Date)] = []
        for i in 0..<100 {
            let startAt = Date().addingTimeInterval(Double(i + 2) * 3600) // 2h..101h ahead
            let a = insertActivity(title: "A\(i)", startAt: startAt, leadMinutes: 60, trip: trip, in: ctx)
            uuids.append((a.id, startAt.addingTimeInterval(-3600)))
        }
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)

        #expect(mock.pending.count == 64)

        // The 64 soonest by fireDate are the first 64 we inserted (i=0..63).
        let expectedIDs = Set(uuids.prefix(64).map { $0.0.uuidString })
        let actualIDs = Set(mock.pending.map(\.identifier))
        #expect(actualIDs == expectedIDs)
    }

    @Test func diffIdempotent() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        for i in 0..<5 {
            let startAt = Date().addingTimeInterval(Double(i + 2) * 3600)
            insertActivity(title: "A\(i)", startAt: startAt, leadMinutes: 60, trip: trip, in: ctx)
        }
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)
        let firstIDs = Set(mock.pending.map(\.identifier))
        let firstCount = mock.pending.count

        await scheduler.reconcile(modelContext: ctx)
        let secondIDs = Set(mock.pending.map(\.identifier))

        #expect(firstCount == 5)
        #expect(mock.pending.count == 5)
        #expect(firstIDs == secondIDs)
    }

    @Test func pastDatesIgnored() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        // 10 in the past (startAt < now → fireDate < now), 5 in the future.
        for i in 0..<10 {
            let startAt = Date().addingTimeInterval(-Double(i + 2) * 3600)
            insertActivity(title: "Past\(i)", startAt: startAt, leadMinutes: 60, trip: trip, in: ctx)
        }
        for i in 0..<5 {
            let startAt = Date().addingTimeInterval(Double(i + 2) * 3600)
            insertActivity(title: "Future\(i)", startAt: startAt, leadMinutes: 60, trip: trip, in: ctx)
        }
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)

        #expect(mock.pending.count == 5)
    }

    @Test func identifierMatchesUUID() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let a = insertActivity(title: "Louvre tour",
                               startAt: Date().addingTimeInterval(4 * 3600),
                               leadMinutes: 60,
                               trip: trip,
                               in: ctx)
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)

        #expect(mock.pending.count == 1)
        let req = mock.pending[0]
        #expect(req.identifier == a.id.uuidString)
        // Also assert userInfo carries the same stringified UUID.
        let userInfoID = req.content.userInfo["activityID"] as? String
        #expect(userInfoID == a.id.uuidString)
    }

    @Test func contentBodyFormat() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(name: "Paris trip", in: ctx)

        // With location
        let withLoc = insertActivity(title: "Louvre tour",
                                     startAt: Date().addingTimeInterval(3 * 3600),
                                     leadMinutes: 60,
                                     location: "Rue de Rivoli",
                                     trip: trip,
                                     in: ctx)
        // Without location (nil)
        let noLoc = insertActivity(title: "Seine cruise",
                                   startAt: Date().addingTimeInterval(4 * 3600),
                                   leadMinutes: 60,
                                   location: nil,
                                   trip: trip,
                                   in: ctx)
        // Empty-string location (should omit segment, no trailing " · ")
        let emptyLoc = insertActivity(title: "Gelato",
                                      startAt: Date().addingTimeInterval(5 * 3600),
                                      leadMinutes: 60,
                                      location: "",
                                      trip: trip,
                                      in: ctx)
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)

        func body(forID id: UUID) -> String? {
            mock.pending.first { $0.identifier == id.uuidString }?.content.body
        }

        let withLocBody = try #require(body(forID: withLoc.id))
        #expect(withLocBody.hasPrefix("Paris trip · "))
        #expect(withLocBody.hasSuffix(" · Rue de Rivoli"))
        // Exactly two " · " separators
        #expect(withLocBody.components(separatedBy: " · ").count == 3)

        let noLocBody = try #require(body(forID: noLoc.id))
        #expect(noLocBody.hasPrefix("Paris trip · "))
        #expect(!noLocBody.hasSuffix(" · "))
        #expect(noLocBody.components(separatedBy: " · ").count == 2)

        let emptyLocBody = try #require(body(forID: emptyLoc.id))
        #expect(!emptyLocBody.hasSuffix(" · "))
        #expect(emptyLocBody.components(separatedBy: " · ").count == 2)
    }

    @Test func rescheduleDiff() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let a = insertActivity(title: "Louvre tour",
                               startAt: Date().addingTimeInterval(3 * 3600),
                               leadMinutes: 60,
                               trip: trip,
                               in: ctx)
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)
        #expect(mock.pending.contains { $0.identifier == a.id.uuidString })

        // Flip off + reconcile.
        a.isReminderEnabled = false
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)

        // Pump the Task { @MainActor in ... } inside removePending on the mock.
        await Task.yield()
        await Task.yield()

        #expect(!mock.pending.contains { $0.identifier == a.id.uuidString })
    }

    @Test func unionSoonest64() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        let base = Date().addingTimeInterval(60 * 60 * 24)   // 1d in future, avoids now-filter

        // 40 activities scheduled 1..40 days out
        for i in 0..<40 {
            let trip = makeTrip(name: "ActTrip\(i)", in: ctx)
            _ = insertActivity(
                title: "Act \(i)",
                startAt: base.addingTimeInterval(TimeInterval(i) * 86_400),
                leadMinutes: 60, enabled: true, trip: trip, in: ctx
            )
        }
        // 40 trips scheduled at offsets that interleave with activities
        for i in 0..<40 {
            _ = insertTripReminder(
                name: "Trip \(i)",
                startDate: base.addingTimeInterval(TimeInterval(i) * 86_400 + 43_200),
                leadMinutes: 1440, in: ctx
            )
        }
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        await Task.yield()

        #expect(mock.pending.count == 64)
        let hasTrip = mock.pending.contains { $0.identifier.hasPrefix("trip-") }
        let hasActivity = mock.pending.contains { !$0.identifier.hasPrefix("trip-") }
        #expect(hasTrip && hasActivity)
    }

    @Test func tripIdentifierPrefix() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        let trip = insertTripReminder(
            name: "Paris",
            startDate: Date().addingTimeInterval(86_400 * 10),
            leadMinutes: 1440, in: ctx
        )
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        await Task.yield()

        #expect(mock.pending.count == 1)
        let req = try #require(mock.pending.first)
        #expect(req.identifier.hasPrefix("trip-"))
        #expect(UUID(uuidString: String(req.identifier.dropFirst(5))) != nil)
        #expect(req.content.userInfo["tripID"] as? String == trip.id.uuidString)
        // BARE uuid — not prefixed (research landmine, Pitfall 8)
        #expect((req.content.userInfo["tripID"] as? String)?.hasPrefix("trip-") == false)
    }
}
