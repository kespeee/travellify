#if DEBUG
import SwiftData
import Foundation

@MainActor
let previewContainer: ModelContainer = {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            configurations: config
        )

        // Seed upcoming trip — Rome & Florence (7 days from today, 7-day duration)
        let rome = Trip()
        rome.name = "Rome & Florence"
        rome.startDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(7 * 86400))
        rome.endDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(14 * 86400))
        container.mainContext.insert(rome)
        let dest1 = Destination(); dest1.name = "Rome"; dest1.sortIndex = 0; dest1.trip = rome
        let dest2 = Destination(); dest2.name = "Florence"; dest2.sortIndex = 1; dest2.trip = rome
        container.mainContext.insert(dest1)
        container.mainContext.insert(dest2)

        // Seed packing categories + items for Rome trip
        let cat1 = PackingCategory(); cat1.name = "Clothes"; cat1.sortOrder = 0; cat1.trip = rome
        container.mainContext.insert(cat1)
        let item1 = PackingItem(); item1.name = "T-shirts"; item1.sortOrder = 0; item1.category = cat1
        let item2 = PackingItem(); item2.name = "Jeans"; item2.sortOrder = 1; item2.isChecked = true; item2.category = cat1
        container.mainContext.insert(item1); container.mainContext.insert(item2)
        let cat2 = PackingCategory(); cat2.name = "Toiletries"; cat2.sortOrder = 1; cat2.trip = rome
        container.mainContext.insert(cat2)
        let item3 = PackingItem(); item3.name = "Toothbrush"; item3.sortOrder = 0; item3.category = cat2
        container.mainContext.insert(item3)

        // Seed upcoming trip — Tokyo (30 days from today)
        let tokyo = Trip()
        tokyo.name = "Tokyo Spring"
        tokyo.startDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(30 * 86400))
        tokyo.endDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(40 * 86400))
        container.mainContext.insert(tokyo)
        let dest3 = Destination(); dest3.name = "Tokyo"; dest3.sortIndex = 0; dest3.trip = tokyo
        container.mainContext.insert(dest3)

        // Seed past trip — Paris Weekend (30 days ago)
        let paris = Trip()
        paris.name = "Paris Weekend"
        paris.startDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(-30 * 86400))
        paris.endDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(-23 * 86400))
        container.mainContext.insert(paris)
        let dest4 = Destination(); dest4.name = "Paris"; dest4.sortIndex = 0; dest4.trip = paris
        container.mainContext.insert(dest4)

        try container.mainContext.save()
        return container
    } catch {
        fatalError("PreviewContainer: \(error)")
    }
}()
#endif
