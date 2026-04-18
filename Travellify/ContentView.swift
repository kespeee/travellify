import SwiftUI

struct ContentView: View {
    @State private var path: [AppDestination] = []

    var body: some View {
        TabView {
            NavigationStack(path: $path) {
                TripListView()
                    .navigationDestination(for: AppDestination.self) { dest in
                        switch dest {
                        case .tripDetail(let id):
                            TripDetailView(tripID: id)
                        }
                    }
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
