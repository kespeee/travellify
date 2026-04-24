import SwiftUI
import SwiftData

/// Trips-tab body. Owns the NavigationStack, AppDestination switch, and the
/// deep-link `.onChange(of:)` consumer. Hosted by `TabBarRoot` as the Trips tab.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var path: [AppDestination] = []
    private let appState = AppState.shared

    var body: some View {
        NavigationStack(path: $path) {
            TripListView()
                .navigationDestination(for: AppDestination.self) { dest in
                    switch dest {
                    case .tripDetail(let id):
                        TripDetailView(tripID: id)
                    case .documentList(let id):
                        DocumentListView(tripID: id)
                    case .packingList(let id):
                        PackingListView(tripID: id)
                    case .activityList(let id):
                        ActivityListView(tripID: id)
                    }
                }
        }
        .onChange(of: appState.pendingDeepLink) { _, deepLink in
            switch deepLink {
            case .activity(let uuid):
                let d = FetchDescriptor<Activity>(
                    predicate: #Predicate { $0.id == uuid }
                )
                if let activity = (try? modelContext.fetch(d))?.first,
                   let trip = activity.trip {
                    path.append(AppDestination.activityList(trip.persistentModelID))
                }
            case .trip(let uuid):
                let d = FetchDescriptor<Trip>(
                    predicate: #Predicate { $0.id == uuid }
                )
                if let trip = (try? modelContext.fetch(d))?.first {
                    path.append(AppDestination.tripDetail(trip.persistentModelID))
                }
            case .none:
                break
            }
            appState.pendingDeepLink = nil   // consume
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
#endif
