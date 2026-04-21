import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct ActivityGroupingTests {

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
        trip.startDate = Date()
        trip.endDate = Date().addingTimeInterval(86_400 * 10)
        context.insert(trip)
        return trip
    }

    /// Mirror the view's grouping logic so changes stay test-covered.
    private func group(_ activities: [Activity],
                       calendar: Calendar = Calendar(identifier: .gregorian))
        -> (keys: [Date], byDay: [Date: [Activity]]) {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "UTC")!
        let byDay = Dictionary(grouping: activities) { a in
            cal.startOfDay(for: a.startAt)
        }
        return (byDay.keys.sorted(), byDay)
    }

    @Test func emptyInputProducesNoSections() throws {
        let (keys, byDay) = group([])
        #expect(keys.isEmpty)
        #expect(byDay.isEmpty)
    }

    @Test func threeNonContiguousDaysProduceExactlyThreeSections() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        // 2026-04-22 09:00 UTC, 2026-04-24 10:00 UTC, 2026-04-27 14:00 UTC
        let base = ISO8601DateFormatter().date(from: "2026-04-22T09:00:00Z")!
        let offsets: [TimeInterval] = [0, 2 * 86_400 + 3600, 5 * 86_400 + 5 * 3600]
        for o in offsets {
            let a = Activity()
            a.title = "A@\(o)"
            a.startAt = base.addingTimeInterval(o)
            a.trip = trip
            ctx.insert(a)
        }
        try ctx.save()

        let activities = try ctx.fetch(FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\Activity.startAt), SortDescriptor(\Activity.createdAt)]
        ))
        let (keys, byDay) = group(activities)
        #expect(keys.count == 3)
        // Ascending
        #expect(keys == keys.sorted())
        for k in keys {
            #expect((byDay[k] ?? []).count == 1)
        }
    }

    @Test func withinDaySortIsAscendingByStartAt() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let base = ISO8601DateFormatter().date(from: "2026-04-22T09:00:00Z")!
        let times: [TimeInterval] = [5 * 3600, 1 * 3600, 3 * 3600]  // 14:00, 10:00, 12:00
        for (i, t) in times.enumerated() {
            let a = Activity()
            a.title = "A\(i)"
            a.startAt = base.addingTimeInterval(t)
            a.trip = trip
            ctx.insert(a)
        }
        try ctx.save()

        let activities = try ctx.fetch(FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\Activity.startAt), SortDescriptor(\Activity.createdAt)]
        ))
        let (keys, byDay) = group(activities)
        #expect(keys.count == 1)
        let rows = byDay[keys[0]] ?? []
        let extracted = rows.map { $0.startAt.timeIntervalSince(base) }
        #expect(extracted == [TimeInterval(1 * 3600), TimeInterval(3 * 3600), TimeInterval(5 * 3600)])
    }

    @Test func createdAtTiebreakOrdersEqualStartAt() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let start = ISO8601DateFormatter().date(from: "2026-04-22T09:00:00Z")!
        let firstCreatedAt = Date().addingTimeInterval(-100)
        let secondCreatedAt = Date().addingTimeInterval(-50)

        let a = Activity()
        a.title = "First"
        a.startAt = start
        a.createdAt = firstCreatedAt
        a.trip = trip
        ctx.insert(a)

        let b = Activity()
        b.title = "Second"
        b.startAt = start
        b.createdAt = secondCreatedAt
        b.trip = trip
        ctx.insert(b)

        try ctx.save()

        let activities = try ctx.fetch(FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\Activity.startAt), SortDescriptor(\Activity.createdAt)]
        ))
        let titles = activities.map(\.title)
        #expect(titles == ["First", "Second"])
    }

    @Test func dayBoundaryPlacesActivitiesInCorrectSections() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let beforeMidnight = ISO8601DateFormatter().date(from: "2026-04-22T23:59:00Z")!
        let afterMidnight  = ISO8601DateFormatter().date(from: "2026-04-23T00:01:00Z")!

        for (i, d) in [beforeMidnight, afterMidnight].enumerated() {
            let a = Activity()
            a.title = "A\(i)"
            a.startAt = d
            a.trip = trip
            ctx.insert(a)
        }
        try ctx.save()

        let activities = try ctx.fetch(FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\Activity.startAt), SortDescriptor(\Activity.createdAt)]
        ))
        let (keys, byDay) = group(activities)
        #expect(keys.count == 2)
        for k in keys { #expect((byDay[k] ?? []).count == 1) }
    }
}
