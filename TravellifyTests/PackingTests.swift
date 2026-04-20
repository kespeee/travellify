import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct PackingTests {

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

    // MARK: - Default fields

    @Test func packingCategoryDefaults() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let cat = PackingCategory()
        context.insert(cat)
        try context.save()
        // id must not be the nil-UUID (i.e., a fresh UUID was assigned)
        #expect(cat.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(cat.name == "")
        #expect(cat.sortOrder == 0)
        #expect(cat.trip == nil)
        #expect((cat.items ?? []).isEmpty)
    }

    @Test func packingItemDefaults() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = PackingItem()
        context.insert(item)
        try context.save()
        #expect(item.name == "")
        #expect(item.isChecked == false)
        #expect(item.sortOrder == 0)
        #expect(item.category == nil)
    }

    // MARK: - Round-trip insert (PACK-01, PACK-02)

    @Test func insertItemUnderCategoryRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let category = PackingCategory()
        category.name = "Toiletries"
        category.sortOrder = 0
        category.trip = trip
        context.insert(category)

        let item = PackingItem()
        item.name = "Toothbrush"
        item.sortOrder = 0
        item.category = category
        context.insert(item)
        try context.save()

        let categories = try context.fetch(FetchDescriptor<PackingCategory>())
        let fetchedCat = categories.first(where: { $0.id == category.id })
        #expect(fetchedCat != nil)
        #expect(fetchedCat?.items?.count == 1)
        #expect(fetchedCat?.items?.first?.name == "Toothbrush")
        #expect(fetchedCat?.trip?.persistentModelID == trip.persistentModelID)
    }

    // MARK: - One-level cascade: category delete cascades to items (PACK-04)

    @Test func deleteCategoryCascadesToItems() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let category = PackingCategory()
        category.name = "Clothes"
        category.sortOrder = 0
        category.trip = trip
        context.insert(category)

        let itemNames = ["T-shirt", "Jeans", "Jacket"]
        for (idx, name) in itemNames.enumerated() {
            let item = PackingItem()
            item.name = name
            item.sortOrder = idx
            item.category = category
            context.insert(item)
        }
        try context.save()

        #expect(try context.fetch(FetchDescriptor<PackingItem>()).count == 3)

        context.delete(category)
        try context.save()

        let remainingItems = try context.fetch(FetchDescriptor<PackingItem>())
        #expect(remainingItems.isEmpty, "Category delete must cascade to items")

        let remainingCategories = try context.fetch(FetchDescriptor<PackingCategory>())
        #expect(remainingCategories.isEmpty)
    }

    // MARK: - Two-level cascade: trip delete cascades to categories and items (PACK-01, PACK-04)

    @Test func deleteTripCascadesToCategoriesAndItemsTwoLevel() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        // Category A: 2 items
        let catA = PackingCategory()
        catA.name = "Electronics"
        catA.sortOrder = 0
        catA.trip = trip
        context.insert(catA)
        for i in 0..<2 {
            let item = PackingItem()
            item.name = "Device \(i)"
            item.sortOrder = i
            item.category = catA
            context.insert(item)
        }

        // Category B: 2 items
        let catB = PackingCategory()
        catB.name = "Toiletries"
        catB.sortOrder = 1
        catB.trip = trip
        context.insert(catB)
        for i in 0..<2 {
            let item = PackingItem()
            item.name = "Toiletry \(i)"
            item.sortOrder = i
            item.category = catB
            context.insert(item)
        }
        try context.save()

        #expect(try context.fetch(FetchDescriptor<PackingCategory>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<PackingItem>()).count == 4)

        context.delete(trip)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<PackingCategory>()).isEmpty,
                "Trip delete must cascade to PackingCategory")
        #expect(try context.fetch(FetchDescriptor<PackingItem>()).isEmpty,
                "Trip delete must cascade two levels to PackingItem")
    }

    // MARK: - isChecked defaults false, persists after toggle (PACK-06)

    @Test func isCheckedDefaultsFalseAndPersistsToggle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let category = PackingCategory()
        category.name = "Clothes"
        category.sortOrder = 0
        category.trip = trip
        context.insert(category)

        let uuid = UUID()
        let item = PackingItem()
        item.id = uuid
        item.name = "Socks"
        item.sortOrder = 0
        item.category = category
        context.insert(item)
        try context.save()

        // Verify default false
        let refetched1 = try context.fetch(FetchDescriptor<PackingItem>(predicate: #Predicate { $0.id == uuid }))
        #expect(refetched1.first?.isChecked == false)

        // Toggle to true, save, refetch
        refetched1.first?.isChecked = true
        try context.save()
        let refetched2 = try context.fetch(FetchDescriptor<PackingItem>(predicate: #Predicate { $0.id == uuid }))
        #expect(refetched2.first?.isChecked == true)

        // Toggle back to false, save, refetch
        refetched2.first?.isChecked = false
        try context.save()
        let refetched3 = try context.fetch(FetchDescriptor<PackingItem>(predicate: #Predicate { $0.id == uuid }))
        #expect(refetched3.first?.isChecked == false)
    }

    // MARK: - sortOrder monotonic on insert (PACK-01 / D21)

    @Test func sortOrderMonotonicOnInsert() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let category = PackingCategory()
        category.name = "Clothes"
        category.sortOrder = 0
        category.trip = trip
        context.insert(category)

        let itemData: [(String, Int)] = [("Shirt", 0), ("Pants", 1), ("Belt", 2)]
        for (name, order) in itemData {
            let item = PackingItem()
            item.name = name
            item.sortOrder = order
            item.category = category
            context.insert(item)
        }
        try context.save()

        var descriptor = FetchDescriptor<PackingItem>()
        descriptor.sortBy = [SortDescriptor(\.sortOrder, order: .forward)]
        let fetched = try context.fetch(descriptor)
        #expect(fetched.map(\.name) == ["Shirt", "Pants", "Belt"])
    }

    // MARK: - Empty items array sanity check

    @Test func categoryWithoutItemsHasEmptyArrayNotNilAfterSave() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = makeTrip(in: context)

        let category = PackingCategory()
        category.name = "Empty Category"
        category.sortOrder = 0
        category.trip = trip
        context.insert(category)
        try context.save()

        let catID = category.id
        let fetched = try context.fetch(FetchDescriptor<PackingCategory>())
        let fetchedCat = fetched.first(where: { $0.id == catID })
        #expect(fetchedCat != nil)
        #expect((fetchedCat?.items ?? []).isEmpty,
                "Category with no items must have empty items array after save")
    }
}
