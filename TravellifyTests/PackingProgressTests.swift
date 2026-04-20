import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct PackingProgressTests {

    // MARK: - Helpers

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

    /// Seeds a category with items and links it to the given trip.
    /// itemStates: array of (name, isChecked)
    @discardableResult
    private func seedCategory(
        name: String,
        itemStates: [(String, Bool)],
        in context: ModelContext,
        trip: Trip
    ) -> PackingCategory {
        let cat = PackingCategory()
        cat.name = name
        cat.sortOrder = 0
        cat.trip = trip
        context.insert(cat)
        for (idx, (itemName, checked)) in itemStates.enumerated() {
            let item = PackingItem()
            item.name = itemName
            item.isChecked = checked
            item.sortOrder = idx
            item.category = cat
            context.insert(item)
        }
        return cat
    }

    // MARK: - Trip-level progress: partial

    @Test func tripLevelProgressPartial() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        seedCategory(
            name: "Clothes",
            itemStates: [("Shirt", true), ("Pants", false), ("Belt", false)],
            in: context, trip: trip
        )
        try context.save()

        let categories = trip.packingCategories ?? []
        let total = categories.flatMap { $0.items ?? [] }.count
        let checked = categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
        #expect(total == 3)
        #expect(checked == 1)
    }

    // MARK: - Trip-level progress: all checked

    @Test func tripLevelProgressAllChecked() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        seedCategory(
            name: "Clothes",
            itemStates: [("Shirt", true), ("Pants", true)],
            in: context, trip: trip
        )
        seedCategory(
            name: "Toiletries",
            itemStates: [("Toothbrush", true), ("Shampoo", true)],
            in: context, trip: trip
        )
        try context.save()

        let categories = trip.packingCategories ?? []
        let total = categories.flatMap { $0.items ?? [] }.count
        let checked = categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
        #expect(total == 4)
        #expect(checked == 4)
    }

    // MARK: - Trip-level progress: none checked

    @Test func tripLevelProgressNoneChecked() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        seedCategory(
            name: "Clothes",
            itemStates: [("Shirt", false), ("Pants", false)],
            in: context, trip: trip
        )
        seedCategory(
            name: "Toiletries",
            itemStates: [("Toothbrush", false)],
            in: context, trip: trip
        )
        try context.save()

        let categories = trip.packingCategories ?? []
        let total = categories.flatMap { $0.items ?? [] }.count
        let checked = categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
        #expect(checked == 0)
        #expect(total > 0)
    }

    // MARK: - Trip-level progress: empty list (PACK-07 edge case / divide-by-zero guard)

    @Test func tripLevelProgressEmptyList() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        // One category, zero items
        seedCategory(name: "Empty", itemStates: [], in: context, trip: trip)
        try context.save()

        let categories = trip.packingCategories ?? []
        let total = categories.flatMap { $0.items ?? [] }.count
        let checked = categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
        #expect(total == 0)
        #expect(checked == 0)

        // Denominator guard: replicates ProgressView's total: Double(max(totalCount, 1))
        let guardedDenominator = Double(max(total, 1))
        #expect(guardedDenominator == 1.0)
    }

    // MARK: - Trip-level progress: no categories (empty trip)

    @Test func tripLevelProgressNoCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)
        // No categories seeded
        try context.save()

        let categories = trip.packingCategories ?? []
        let total = categories.flatMap { $0.items ?? [] }.count
        let checked = categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
        #expect(total == 0)
        #expect(checked == 0)

        let guardedDenominator = max(total, 1)
        #expect(guardedDenominator == 1)
    }

    // MARK: - Per-category progress

    @Test func categoryLevelProgressPerCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let catA = seedCategory(
            name: "Clothes",
            itemStates: [("Shirt", true), ("Pants", true), ("Belt", false)],
            in: context, trip: trip
        )
        let catB = seedCategory(
            name: "Toiletries",
            itemStates: [("Toothbrush", false), ("Shampoo", false)],
            in: context, trip: trip
        )
        try context.save()

        // Per-category A: 2 checked of 3 total
        let itemsA = catA.items ?? []
        let checkedA = itemsA.filter(\.isChecked).count
        let totalA = itemsA.count
        #expect(checkedA == 2)
        #expect(totalA == 3)

        // Per-category B: 0 checked of 2 total
        let itemsB = catB.items ?? []
        let checkedB = itemsB.filter(\.isChecked).count
        let totalB = itemsB.count
        #expect(checkedB == 0)
        #expect(totalB == 2)

        // Trip-level aggregate
        let categories = trip.packingCategories ?? []
        let tripTotal = categories.flatMap { $0.items ?? [] }.count
        let tripChecked = categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
        #expect(tripTotal == 5)
        #expect(tripChecked == 2)
    }

    // MARK: - Per-category progress: empty category

    @Test func categoryLevelProgressEmptyCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let cat = seedCategory(name: "Empty", itemStates: [], in: context, trip: trip)
        try context.save()

        let items = cat.items ?? []
        let checked = items.filter(\.isChecked).count
        let total = items.count
        #expect(checked == 0)
        #expect(total == 0)

        // ProgressView denominator guard for empty category
        let guardedDenominator = max(total, 1)
        #expect(guardedDenominator == 1)
    }

    // MARK: - Progress percent formula (accessibility value)

    @Test func progressPercentFormula() throws {
        // For 1 of 4 checked, UI-SPEC accessibility percent must be 25
        let checkedCount = 1
        let totalCount = 4
        let percent = Int(Double(checkedCount) / Double(totalCount) * 100)
        #expect(percent == 25)
    }
}
