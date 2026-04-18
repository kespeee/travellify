import SwiftUI

struct ContentView: View {
    @State private var path: [AppDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            TripListView()
                .navigationDestination(for: AppDestination.self) { dest in
                    switch dest {
                    case .tripDetail(let id):
                        TripDetailView(tripID: id)
                    }
                }
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
#endif
