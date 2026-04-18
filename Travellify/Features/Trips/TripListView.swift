import SwiftUI
import SwiftData

struct TripListView: View {
    @Query(sort: \Trip.startDate, order: .forward)
    private var allTrips: [Trip]

    @Environment(\.modelContext) private var modelContext

    @State private var showNewTrip = false

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var upcomingTrips: [Trip] {
        allTrips
            .filter { $0.endDate >= today }
            .sorted { $0.startDate < $1.startDate }
    }

    private var pastTrips: [Trip] {
        allTrips
            .filter { $0.endDate < today }
            .sorted { $0.startDate > $1.startDate }
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
                                NavigationLink(value: AppDestination.tripDetail(trip.persistentModelID)) {
                                    TripRow(trip: trip)
                                }
                            }
                        }
                    }
                    if !pastTrips.isEmpty {
                        Section("Past") {
                            ForEach(pastTrips) { trip in
                                NavigationLink(value: AppDestination.tripDetail(trip.persistentModelID)) {
                                    TripRow(trip: trip)
                                }
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
