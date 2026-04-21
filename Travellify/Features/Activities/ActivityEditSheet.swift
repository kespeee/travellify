import SwiftUI
import SwiftData

struct ActivityEditSheet: View {
    let activity: Activity?
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var startAt: Date = Date()
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var didLoadInitialValues = false

    // MARK: - Computed

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespaces)
    }
    private var isValid: Bool { !trimmedTitle.isEmpty }

    private var isOutsideTripRange: Bool {
        let cal = Calendar.current
        let activityDay = cal.startOfDay(for: startAt)
        let tripStartDay = cal.startOfDay(for: trip.startDate)
        let tripEndDay = cal.startOfDay(for: trip.endDate)
        return activityDay < tripStartDay || activityDay > tripEndDay
    }

    private var navigationTitle: String {
        activity == nil ? "New Activity" : "Edit Activity"
    }

    private var confirmButtonTitle: String {
        activity == nil ? "Add" : "Save"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section("When") {
                    DatePicker(
                        "Starts",
                        selection: $startAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)

                    if isOutsideTripRange {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .imageScale(.small)
                            Text("Outside trip dates")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Warning: activity is outside trip dates")
                    }
                }

                Section("Location") {
                    TextField("Optional", text: $location)
                        .textInputAutocapitalization(.words)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmButtonTitle) {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear(perform: loadInitialValuesIfNeeded)
        }
    }

    // MARK: - Lifecycle

    private func loadInitialValuesIfNeeded() {
        guard !didLoadInitialValues else { return }
        didLoadInitialValues = true
        if let activity {
            title = activity.title
            startAt = activity.startAt
            location = activity.location ?? ""
            notes = activity.notes ?? ""
        } else {
            startAt = ActivityDateLabels.defaultStartAt(for: trip)
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let nextLocation: String? = trimmedLocation.isEmpty ? nil : trimmedLocation
        let nextNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        if let activity {
            activity.title = trimmedTitle
            activity.startAt = startAt
            activity.location = nextLocation
            activity.notes = nextNotes
        } else {
            let newActivity = Activity()
            newActivity.title = trimmedTitle
            newActivity.startAt = startAt
            newActivity.location = nextLocation
            newActivity.notes = nextNotes
            newActivity.trip = trip
            modelContext.insert(newActivity)
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("ActivityEditSheet.save failed: \(error)")
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Create mode — in-range") {
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
    return ActivityEditSheet(activity: nil, trip: trip)
        .modelContainer(container)
}

#Preview("Edit mode") {
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

    let a = Activity()
    a.title = "Louvre tour"
    a.startAt = Date().addingTimeInterval(86_400)
    a.location = "Paris"
    a.notes = "Guide meets at 14:30 at the pyramid entrance."
    a.trip = trip
    container.mainContext.insert(a)

    return ActivityEditSheet(activity: a, trip: trip)
        .modelContainer(container)
}
#endif
