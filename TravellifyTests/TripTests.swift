import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct TripTests {
    let container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            configurations: config
        )
    }

    @Test func createTripPersists() throws {
        let context = container.mainContext
        let trip = Trip()
        trip.name = "Tokyo"
        trip.startDate = Calendar.current.startOfDay(for: Date())
        trip.endDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400 * 7))
        context.insert(trip)
        try context.save()

        let trips = try context.fetch(FetchDescriptor<Trip>())
        #expect(trips.count == 1)
        #expect(trips.first?.name == "Tokyo")
    }

    @Test func editTripUpdatesPersistedValues() throws {
        let context = container.mainContext
        let trip = Trip()
        trip.name = "Original"
        trip.startDate = Calendar.current.startOfDay(for: Date())
        trip.endDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400 * 3))
        context.insert(trip)
        try context.save()

        trip.name = "Updated"
        trip.endDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400 * 10))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Trip>())
        #expect(fetched.first?.name == "Updated")
        let delta = fetched.first?.endDate.timeIntervalSince(fetched.first?.startDate ?? .distantPast)
        #expect((delta ?? 0) >= 86400 * 9)
    }

    @Test func deleteTripCascadesToDestinations() throws {
        let context = container.mainContext
        let trip = Trip()
        trip.name = "Cascade Test"
        trip.startDate = Date()
        trip.endDate = Date()
        context.insert(trip)

        for i in 0..<3 {
            let dest = Destination()
            dest.name = "Dest\(i)"
            dest.sortIndex = i
            dest.trip = trip
            context.insert(dest)
        }
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Destination>()).count == 3)

        context.delete(trip)
        try context.save()

        let destinations = try context.fetch(FetchDescriptor<Destination>())
        #expect(destinations.isEmpty, "Cascade delete must remove all destinations")
    }

    @Test func deleteTripCascadesToPackingModels() throws {
        let context = container.mainContext
        let trip = Trip()
        trip.name = "Cascade Test"
        trip.startDate = Date()
        trip.endDate = Date()
        context.insert(trip)

        let doc = Document(); doc.trip = trip; context.insert(doc)
        let act = Activity(); act.trip = trip; context.insert(act)

        let cat = PackingCategory(); cat.name = "Toiletries"; cat.sortOrder = 0; cat.trip = trip
        context.insert(cat)
        let item = PackingItem(); item.name = "Toothbrush"; item.sortOrder = 0; item.category = cat
        context.insert(item)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Document>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PackingCategory>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PackingItem>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Activity>()).count == 1)

        context.delete(trip)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Document>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PackingCategory>()).isEmpty,
                "Trip delete must cascade to PackingCategory")
        #expect(try context.fetch(FetchDescriptor<PackingItem>()).isEmpty,
                "Trip delete must cascade to PackingItem through PackingCategory")
        #expect(try context.fetch(FetchDescriptor<Activity>()).isEmpty)
    }

    @Test func dateNormalizationProducesStartOfDay() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 10; comps.hour = 14; comps.minute = 37
        let afternoon = Calendar.current.date(from: comps)!
        let normalized = Calendar.current.startOfDay(for: afternoon)
        let normalizedComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: normalized)
        #expect(normalizedComps.year == 2026)
        #expect(normalizedComps.month == 5)
        #expect(normalizedComps.day == 10)
        #expect(normalizedComps.hour == 0)
        #expect(normalizedComps.minute == 0)
        #expect(normalizedComps.second == 0)
    }

    @Test func destinationSortIndexPreservesOrder() throws {
        let context = container.mainContext
        let trip = Trip(); trip.name = "Multi-stop"
        trip.startDate = Date(); trip.endDate = Date()
        context.insert(trip)
        let names = ["Paris", "Lyon", "Marseille"]
        for (i, n) in names.enumerated() {
            let d = Destination(); d.name = n; d.sortIndex = i; d.trip = trip
            context.insert(d)
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Destination>())
        let sorted = fetched.sorted { $0.sortIndex < $1.sortIndex }
        #expect(sorted.map(\.name) == names)
    }

    @Test func destinationSortIndexReorderRewritesContiguously() throws {
        let context = container.mainContext
        let trip = Trip(); trip.name = "Reorder"
        trip.startDate = Date(); trip.endDate = Date()
        context.insert(trip)
        let d0 = Destination(); d0.name = "A"; d0.sortIndex = 0; d0.trip = trip
        let d1 = Destination(); d1.name = "B"; d1.sortIndex = 1; d1.trip = trip
        let d2 = Destination(); d2.name = "C"; d2.sortIndex = 2; d2.trip = trip
        [d0, d1, d2].forEach { context.insert($0) }
        try context.save()

        let reordered = [d2, d0, d1]
        for (i, dest) in reordered.enumerated() {
            dest.sortIndex = i
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Destination>())
        let sorted = fetched.sorted { $0.sortIndex < $1.sortIndex }
        #expect(sorted.map(\.name) == ["C", "A", "B"])
        #expect(sorted.map(\.sortIndex) == [0, 1, 2])
    }
}
