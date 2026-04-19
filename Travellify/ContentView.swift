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
                        case .documentList(let id):
                            // TODO(02-02): replace with DocumentListView(tripID: id)
                            Text("Documents coming soon").foregroundStyle(.secondary)
                                .navigationTitle("Documents")
                                .onAppear { _ = id } // silence unused-let warning until wired
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
