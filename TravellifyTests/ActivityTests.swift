import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct ActivityTests {

    // MARK: - Helpers (mirrors PackingTests.swift)

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
        trip.endDate = Date().addingTimeInterval(86_400 * 5)
        context.insert(trip)
        return trip
    }

    // MARK: - Defaults

    @Test func activityDefaults() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let a = Activity()
        context.insert(a)
        try context.save()

        #expect(a.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(a.title == "")
        #expect(a.location == nil)
        #expect(a.notes == nil)
        #expect(a.trip == nil)
        #expect(abs(a.startAt.timeIntervalSinceNow) < 5)
        #expect(abs(a.createdAt.timeIntervalSinceNow) < 5)
    }

    // MARK: - Round-trip insert under trip

    @Test func insertActivityRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let when = Date().addingTimeInterval(86_400) // tomorrow
        let a = Activity()
        a.title = "Louvre tour"
        a.startAt = when
        a.location = "Paris"
        a.notes = "Tour guide meets at 2:30 at the pyramid."
        a.trip = trip
        context.insert(a)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Activity>())
        #expect(fetched.count == 1)
        let r = try #require(fetched.first)
        #expect(r.title == "Louvre tour")
        #expect(r.startAt.timeIntervalSince1970 == when.timeIntervalSince1970)
        #expect(r.location == "Paris")
        #expect(r.notes == "Tour guide meets at 2:30 at the pyramid.")
        #expect(r.trip?.name == "Rome 2026")
    }

    // MARK: - Mutation persists after save

    @Test func mutationPersistsAfterSave() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let a = Activity()
        a.title = "Original"
        a.trip = trip
        context.insert(a)
        try context.save()

        let newDate = Date().addingTimeInterval(3 * 86_400)
        a.title = "Edited"
        a.startAt = newDate
        a.location = "Rome"
        a.notes = "Updated notes"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Activity>())
        let r = try #require(fetched.first)
        #expect(r.title == "Edited")
        #expect(r.startAt.timeIntervalSince1970 == newDate.timeIntervalSince1970)
        #expect(r.location == "Rome")
        #expect(r.notes == "Updated notes")
    }

    // MARK: - Trip delete cascades to activities

    @Test func deleteTripCascadesToActivities() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)
        for i in 0..<3 {
            let a = Activity()
            a.title = "Activity \(i)"
            a.startAt = Date().addingTimeInterval(Double(i) * 3600)
            a.trip = trip
            context.insert(a)
        }
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Activity>()).count == 3)

        context.delete(trip)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Activity>()).isEmpty)
    }

    // MARK: - Optional fields can be cleared to nil

    @Test func optionalFieldsCanBeClearedToNil() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let a = Activity()
        a.title = "Clearable"
        a.location = "To be cleared"
        a.notes = "To be cleared"
        a.trip = trip
        context.insert(a)
        try context.save()

        a.location = nil
        a.notes = nil
        try context.save()

        let r = try #require(try context.fetch(FetchDescriptor<Activity>()).first)
        #expect(r.location == nil)
        #expect(r.notes == nil)
    }
}
