import SwiftUI
import SwiftData

@main
struct TravellifyApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Trip.self, Destination.self, Document.self,
                     PackingItem.self, Activity.self,
                migrationPlan: TravellifyMigrationPlan.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .preferredColorScheme(.dark)
        }
    }
}
