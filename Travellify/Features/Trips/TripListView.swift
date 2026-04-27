import SwiftUI
import SwiftData

struct TripListView: View {
    @Query(sort: \Trip.startDate, order: .forward)
    private var allTrips: [Trip]

    @Environment(\.modelContext) private var modelContext

    @State private var showNewTrip = false
    @State private var tripPendingDelete: Trip?
    @State private var tripToEdit: Trip?

    private var upcomingTrips: [Trip] {
        TripPartition.upcoming(from: allTrips)
    }

    private var pastTrips: [Trip] {
        TripPartition.past(from: allTrips)
    }

    var body: some View {
        Group {
            if allTrips.isEmpty {
                TripEmptyState(onCreateTrip: { showNewTrip = true })
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 16) {
                        LazyVStack(spacing: 16) {
                        if let hero = upcomingTrips.first {
                            NavigationLink(value: AppDestination.tripDetail(hero.persistentModelID)) {
                                UpcomingTripCard(
                                    trip: hero,
                                    onEdit: { tripToEdit = hero },
                                    onDelete: { tripPendingDelete = hero }
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }

                        let following = Array(upcomingTrips.dropFirst())
                        if !following.isEmpty {
                            sectionHeader("FOLLOWING")
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                            ForEach(following, id: \.id) { trip in
                                NavigationLink(value: AppDestination.tripDetail(trip.persistentModelID)) {
                                    FollowingTripRow(
                                        trip: trip,
                                        onEdit: { tripToEdit = trip },
                                        onDelete: { tripPendingDelete = trip }
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }

                        if !pastTrips.isEmpty {
                            sectionHeader("PAST")
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                            ForEach(pastTrips, id: \.id) { trip in
                                NavigationLink(value: AppDestination.tripDetail(trip.persistentModelID)) {
                                    FollowingTripRow(
                                        trip: trip,
                                        onEdit: { tripToEdit = trip },
                                        onDelete: { tripPendingDelete = trip }
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                        }
                        .padding(.bottom, 32)
                    }
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            }
        }
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !allTrips.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Trip")
                }
            }
        }
        .sheet(isPresented: $showNewTrip) {
            TripEditSheet(mode: .create)
        }
        .sheet(item: $tripToEdit) { trip in
            TripEditSheet(mode: .edit(trip))
        }
        .alert(
            tripPendingDelete.map { "Delete \"\($0.name)\"?" } ?? "Delete trip?",
            isPresented: Binding(
                get: { tripPendingDelete != nil },
                set: { if !$0 { tripPendingDelete = nil } }
            ),
            presenting: tripPendingDelete
        ) { trip in
            Button("Delete", role: .destructive) {
                // Capture ID before delete — trip reference may become invalid after save
                let tripIDString = trip.id.uuidString
                modelContext.delete(trip)
                do {
                    try modelContext.save()
                    // Phase 5 (ACT-08): reconcile notifications AFTER save — cascade
                    // has already removed activity rows; reconcile cancels their pending requests.
                    let ctx = modelContext
                    Task { await NotificationScheduler.shared.reconcile(modelContext: ctx) }
                    // Phase 2 (D16): remove the trip's file subtree AFTER save succeeds.
                    // Silent on failure — orphan files are tolerable; model delete already succeeded.
                    try? FileStorage.removeTripFolder(tripIDString: tripIDString)
                } catch {
                    // Model delete/save failed — do NOT remove files; keep on-disk state consistent with model.
                }
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
    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
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
