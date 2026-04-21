import SwiftUI
import SwiftData

struct ActivityListView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [Activity]

    @State private var showAddSheet = false
    @State private var pendingEditActivity: Activity?
    @State private var errorMessage: String?

    init(tripID: PersistentIdentifier) {
        self.tripID = tripID
        _activities = Query(
            filter: #Predicate<Activity> { activity in
                activity.trip?.persistentModelID == tripID
            },
            sort: [
                SortDescriptor(\Activity.startAt, order: .forward),
                SortDescriptor(\Activity.createdAt, order: .forward)
            ]
        )
    }

    private var trip: Trip? {
        modelContext.model(for: tripID) as? Trip
    }

    // MARK: - Grouping (RESEARCH Pattern 2 / D42)

    private var groupedByDay: [Date: [Activity]] {
        Dictionary(grouping: activities) { activity in
            Calendar.current.startOfDay(for: activity.startAt)
        }
    }

    private var sortedDays: [Date] {
        groupedByDay.keys.sorted()
    }

    // MARK: - Body

    var body: some View {
        Group {
            if activities.isEmpty {
                EmptyActivitiesView()
            } else {
                listContent
            }
        }
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Activity")
                .disabled(trip == nil)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let trip {
                ActivityEditSheet(activity: nil, trip: trip)
            }
        }
        .sheet(item: $pendingEditActivity) { activity in
            if let trip {
                ActivityEditSheet(activity: activity, trip: trip)
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            ForEach(sortedDays, id: \.self) { day in
                let rowsForDay = groupedByDay[day] ?? []
                Section {
                    ForEach(rowsForDay) { activity in
                        ActivityRow(activity: activity)
                            .contentShape(Rectangle())
                            .onTapGesture { pendingEditActivity = activity }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(activity)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    ActivityDayHeader(day: day, count: rowsForDay.count)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listRowSpacing(8)
    }

    // MARK: - Mutations

    private func delete(_ activity: Activity) {
        modelContext.delete(activity)
        save("Couldn't delete activity. Please try again.")
    }

    private func save(_ failureMessage: String) {
        do { try modelContext.save() }
        catch { errorMessage = failureMessage }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Empty") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let trip = Trip()
    trip.name = "Rome 2026"
    trip.startDate = Date()
    trip.endDate = Date().addingTimeInterval(86_400 * 5)
    container.mainContext.insert(trip)
    return NavigationStack {
        ActivityListView(tripID: trip.persistentModelID)
    }
    .modelContainer(container)
}

#Preview("Populated") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let trip = Trip()
    trip.name = "Rome 2026"
    trip.startDate = Date()
    trip.endDate = Date().addingTimeInterval(86_400 * 5)
    container.mainContext.insert(trip)

    let seeds: [(String, TimeInterval, String?)] = [
        ("Louvre tour",   0,                  "Paris"),
        ("Dinner",        3 * 3600,           "Le Marais"),
        ("Train to Rome", 86_400 + 9 * 3600,  "Gare de Lyon"),
        ("Colosseum",     2 * 86_400 + 10 * 3600, "Rome")
    ]
    for (title, offset, loc) in seeds {
        let a = Activity()
        a.title = title
        a.startAt = Date().addingTimeInterval(offset)
        a.location = loc
        a.trip = trip
        container.mainContext.insert(a)
    }

    return NavigationStack {
        ActivityListView(tripID: trip.persistentModelID)
    }
    .modelContainer(container)
}
#endif
