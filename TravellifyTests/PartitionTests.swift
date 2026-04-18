import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct PartitionTests {
    let container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, Activity.self,
            configurations: config
        )
    }

    private func makeTrip(name: String, start: Date, end: Date) -> Trip {
        let t = Trip()
        t.name = name
        t.startDate = start
        t.endDate = end
        container.mainContext.insert(t)
        return t
    }

    @Test func upcomingIncludesTripEndingToday() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let trip = makeTrip(name: "Ends Today", start: today.addingTimeInterval(-86400 * 3), end: today)
        try container.mainContext.save()

        let upcoming = TripPartition.upcoming(from: [trip], now: Date())
        #expect(upcoming.contains { $0.name == "Ends Today" })
        let past = TripPartition.past(from: [trip], now: Date())
        #expect(!past.contains { $0.name == "Ends Today" })
    }

    @Test func pastIncludesTripEndingYesterday() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = today.addingTimeInterval(-86400)
        let trip = makeTrip(name: "Ended Yesterday", start: yesterday.addingTimeInterval(-86400 * 5), end: yesterday)
        try container.mainContext.save()

        let past = TripPartition.past(from: [trip], now: Date())
        #expect(past.contains { $0.name == "Ended Yesterday" })
        let upcoming = TripPartition.upcoming(from: [trip], now: Date())
        #expect(!upcoming.contains { $0.name == "Ended Yesterday" })
    }

    @Test func upcomingSortedAscending() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let a = makeTrip(name: "A", start: today.addingTimeInterval(86400 * 10), end: today.addingTimeInterval(86400 * 12))
        let b = makeTrip(name: "B", start: today.addingTimeInterval(86400 * 5), end: today.addingTimeInterval(86400 * 7))
        let c = makeTrip(name: "C", start: today.addingTimeInterval(86400 * 20), end: today.addingTimeInterval(86400 * 22))
        try container.mainContext.save()

        let upcoming = TripPartition.upcoming(from: [a, b, c], now: Date())
        #expect(upcoming.map(\.name) == ["B", "A", "C"])
    }

    @Test func pastSortedDescending() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let x = makeTrip(name: "X", start: today.addingTimeInterval(-86400 * 30), end: today.addingTimeInterval(-86400 * 25))
        let y = makeTrip(name: "Y", start: today.addingTimeInterval(-86400 * 10), end: today.addingTimeInterval(-86400 * 5))
        let z = makeTrip(name: "Z", start: today.addingTimeInterval(-86400 * 60), end: today.addingTimeInterval(-86400 * 55))
        try container.mainContext.save()

        let past = TripPartition.past(from: [x, y, z], now: Date())
        #expect(past.map(\.name) == ["Y", "X", "Z"])
    }

    @Test func emptyInputProducesEmptyOutput() {
        #expect(TripPartition.upcoming(from: []).isEmpty)
        #expect(TripPartition.past(from: []).isEmpty)
    }
}
