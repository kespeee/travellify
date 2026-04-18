import SwiftUI
import SwiftData

struct TripListView: View {
    @Query(sort: \Trip.startDate, order: .forward)
    private var allTrips: [Trip]

    @Environment(\.modelContext) private var modelContext

    @State private var showNewTrip = false
    @State private var tripPendingDelete: Trip?

    private var upcomingTrips: [Trip] {
        TripPartition.upcoming(from: allTrips)
    }

    private var pastTrips: [Trip] {
        TripPartition.past(from: allTrips)
    }

    var body: some View {
        Group {
            if allTrips.isEmpty {
                TripEmptyState()
            } else {
                List {
                    if !upcomingTrips.isEmpty {
                        Section("Upcoming") {
                            ForEach(upcomingTrips) { trip in
                                row(for: trip)
                            }
                        }
                    }
                    if !pastTrips.isEmpty {
                        Section("Past") {
                            ForEach(pastTrips) { trip in
                                row(for: trip)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewTrip = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Trip")
            }
        }
        .sheet(isPresented: $showNewTrip) {
            TripEditSheet(mode: .create)
        }
        .confirmationDialog(
            tripPendingDelete.map { "Delete \"\($0.name)\"?" } ?? "",
            isPresented: Binding(
                get: { tripPendingDelete != nil },
                set: { if !$0 { tripPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: tripPendingDelete
        ) { trip in
            Button("Delete Trip", role: .destructive) {
                modelContext.delete(trip)
                try? modelContext.save()
                tripPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                tripPendingDelete = nil
            }
        } message: { _ in
            Text("This will also delete all documents, packing items, and activities for this trip.")
        }
    }

    @ViewBuilder
    private func row(for trip: Trip) -> some View {
        NavigationLink(value: AppDestination.tripDetail(trip.persistentModelID)) {
            TripRow(trip: trip)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                tripPendingDelete = trip
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#if DEBUG
#Preview("With trips") {
    NavigationStack {
        TripListView()
    }
    .modelContainer(previewContainer)
}

#Preview("Empty") {
    NavigationStack {
        TripListView()
    }
    .modelContainer(try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ))
}
#endif
