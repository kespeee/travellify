import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var path: [AppDestination] = []
    private let appState = AppState.shared

    var body: some View {
        TabView {
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
                guard case .activity(let uuid) = deepLink else { return }
                let descriptor = FetchDescriptor<Activity>(
                    predicate: #Predicate { $0.id == uuid }
                )
                if let activity = (try? modelContext.fetch(descriptor))?.first,
                   let trip = activity.trip {
                    path.append(AppDestination.activityList(trip.persistentModelID))
                }
                appState.pendingDeepLink = nil   // consume
            }
            .tabItem {
                Label("Trips", systemImage: "airplane")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

private struct SettingsView: View {
    var body: some View {
        List {
            Section {
                Text("Settings coming soon.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
#endif
