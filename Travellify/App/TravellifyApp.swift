import SwiftUI
import SwiftData

@main
struct TravellifyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Trip.self, Destination.self, Document.self,
                     PackingItem.self, PackingCategory.self, Activity.self,
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
        .onChange(of: scenePhase) { _, new in
            if new == .active {
                let ctx = container.mainContext
                Task { @MainActor in
                    await NotificationScheduler.shared.reconcile(modelContext: ctx)
                }
            }
        }
    }
}
