import SwiftUI
import SwiftData

struct TripEditSheet: View {
    enum Mode {
        case create
        case edit(Trip)
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var endDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var destinations: [DestinationDraft] = []
    @State private var didLoadInitialValues = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && endDate >= startDate
    }

    private var showEndDateError: Bool {
        endDate < startDate
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return "New Trip"
        case .edit:   return "Edit Trip"
        }
    }

    private var confirmButtonTitle: String {
        switch mode {
        case .create: return "Create Trip"
        case .edit:   return "Save Changes"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Trip name", text: $name)
                        .textInputAutocapitalization(.words)
                    if trimmedName.isEmpty {
                        Text("Trip name is required.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    if showEndDateError {
                        Text("End date must be on or after the start date.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Destinations") {
                    ForEach(destinations.indices, id: \.self) { index in
                        TextField("Destination", text: $destinations[index].name)
                    }
                    .onDelete { indexSet in
                        destinations.remove(atOffsets: indexSet)
                    }
                    .onMove { source, destinationOffset in
                        destinations.move(fromOffsets: source, toOffset: destinationOffset)
                    }

                    Button {
                        destinations.append(DestinationDraft())
                    } label: {
                        Label("Add Destination", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmButtonTitle) { save() }
                        .disabled(!isValid)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .onAppear(perform: loadInitialValuesIfNeeded)
        }
    }

    private func loadInitialValuesIfNeeded() {
        guard !didLoadInitialValues else { return }
        didLoadInitialValues = true
        if case .edit(let trip) = mode {
            name = trip.name
            startDate = trip.startDate
            endDate = trip.endDate
            let existing = (trip.destinations ?? [])
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(DestinationDraft.from)
            destinations = existing
        }
    }

    private func save() {
        let normalizedStart = Calendar.current.startOfDay(for: startDate)
        let normalizedEnd = Calendar.current.startOfDay(for: endDate)
        let cleanedDrafts = destinations
            .map { DestinationDraft(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespaces), existingModelID: $0.existingModelID) }
            .filter { !$0.name.isEmpty }

        switch mode {
        case .create:
            let trip = Trip()
            trip.name = trimmedName
            trip.startDate = normalizedStart
            trip.endDate = normalizedEnd
            modelContext.insert(trip)
            for (index, draft) in cleanedDrafts.enumerated() {
                let dest = Destination()
                dest.name = draft.name
                dest.sortIndex = index
                dest.trip = trip
                modelContext.insert(dest)
            }

        case .edit(let trip):
            trip.name = trimmedName
            trip.startDate = normalizedStart
            trip.endDate = normalizedEnd
            reconcileDestinations(for: trip, with: cleanedDrafts)
        }

        do {
            try modelContext.save()
        } catch {
            // Keep dismiss() so user is not stuck; real error surfacing deferred to Phase 6
            assertionFailure("modelContext.save failed: \(error)")
        }
        dismiss()
    }

    private func reconcileDestinations(for trip: Trip, with drafts: [DestinationDraft]) {
        let existing = trip.destinations ?? []
        let existingByID: [PersistentIdentifier: Destination] = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.persistentModelID, $0) }
        )
        let draftModelIDs = Set(drafts.compactMap(\.existingModelID))

        // Delete destinations removed from the draft list
        for dest in existing where !draftModelIDs.contains(dest.persistentModelID) {
            modelContext.delete(dest)
        }

        // Apply draft ordering: update existing or create new, always rewriting sortIndex 0..n-1
        for (index, draft) in drafts.enumerated() {
            if let modelID = draft.existingModelID, let dest = existingByID[modelID] {
                dest.name = draft.name
                dest.sortIndex = index
            } else {
                let dest = Destination()
                dest.name = draft.name
                dest.sortIndex = index
                dest.trip = trip
                modelContext.insert(dest)
            }
        }
    }
}

#if DEBUG
#Preview("Create") {
    TripEditSheet(mode: .create)
        .modelContainer(previewContainer)
}

#Preview("Edit") {
    let container = previewContainer
    let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.startDate)])
    let trip = (try? container.mainContext.fetch(descriptor))?.first ?? Trip()
    return TripEditSheet(mode: .edit(trip))
        .modelContainer(container)
}
#endif
