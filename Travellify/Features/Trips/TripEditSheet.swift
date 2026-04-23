import SwiftUI
import SwiftData
import UserNotifications

struct TripEditSheet: View {
    enum Mode {
        case create
        case edit(Trip)
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var name: String = ""
    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var endDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var destinations: [DestinationDraft] = []
    @State private var didLoadInitialValues = false

    // Reminder state (Phase 6 D76/D82)
    @State private var isReminderEnabled: Bool = false
    @State private var leadMinutes: Int = TripReminderLeadTime.default.rawValue
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showDeniedAlert: Bool = false

    // Dirty-tracking triplet — trip version anchors on startDate (NOT startAt)
    @State private var initialIsReminderEnabled: Bool = false
    @State private var initialLeadMinutes: Int? = nil
    @State private var initialStartDate: Date = Date()

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var isValid: Bool {
        true
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
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, newStart in
                            if newStart > endDate { endDate = newStart }
                        }
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
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

                reminderSection()
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
            }
            .onAppear(perform: loadInitialValuesIfNeeded)
            .task { await refreshAuthStatus() }
            .onChange(of: scenePhase) { _, new in
                if new == .active { Task { await refreshAuthStatus() } }
            }
            .alert("Notifications are off", isPresented: $showDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable them in Settings to get activity reminders.")
            }
        }
    }

    // MARK: - Reminder Section (D82)

    @ViewBuilder
    private func reminderSection() -> some View {
        Section("Reminder") {
            Toggle("Reminder", isOn: Binding(
                get: { isReminderEnabled },
                set: { newValue in handleToggleChange(newValue) }
            ))

            if isReminderEnabled && authStatus != .denied {
                Picker("Notify", selection: $leadMinutes) {
                    ForEach(TripReminderLeadTime.allCases) { preset in
                        Text(preset.label).tag(preset.rawValue)
                    }
                }
            }
        }
    }

    // MARK: - Toggle + auth flow

    private func handleToggleChange(_ newValue: Bool) {
        if newValue {
            switch authStatus {
            case .notDetermined:
                Task { await requestAuthAndEnable() }
            case .authorized, .provisional, .ephemeral:
                isReminderEnabled = true
            case .denied:
                showDeniedAlert = true
            @unknown default:
                break
            }
        } else {
            isReminderEnabled = false
        }
    }

    private func requestAuthAndEnable() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthStatus()
        if granted { isReminderEnabled = true }
    }

    private func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
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
            isReminderEnabled = trip.isReminderEnabled
            leadMinutes = trip.reminderLeadMinutes ?? TripReminderLeadTime.default.rawValue
        }
        // Dirty-tracking snapshot (both create + edit).
        initialIsReminderEnabled = isReminderEnabled
        initialLeadMinutes = {
            if case .edit(let trip) = mode { return trip.reminderLeadMinutes }
            return nil
        }()
        initialStartDate = startDate
    }

    private func save() {
        let normalizedStart = Calendar.current.startOfDay(for: startDate)
        let normalizedEnd = Calendar.current.startOfDay(for: endDate)
        let cleanedDrafts = destinations
            .map { DestinationDraft(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespaces), existingModelID: $0.existingModelID) }
            .filter { !$0.name.isEmpty }

        let newLeadMinutes: Int? = isReminderEnabled ? leadMinutes : nil

        switch mode {
        case .create:
            let trip = Trip()
            trip.name = trimmedName.isEmpty ? "Untitled Trip" : trimmedName
            trip.startDate = normalizedStart
            trip.endDate = normalizedEnd
            trip.isReminderEnabled = isReminderEnabled
            trip.reminderLeadMinutes = newLeadMinutes
            modelContext.insert(trip)
            for (index, draft) in cleanedDrafts.enumerated() {
                let dest = Destination()
                dest.name = draft.name
                dest.sortIndex = index
                dest.trip = trip
                modelContext.insert(dest)
            }

        case .edit(let trip):
            trip.name = trimmedName.isEmpty ? "Untitled Trip" : trimmedName
            trip.startDate = normalizedStart
            trip.endDate = normalizedEnd
            trip.isReminderEnabled = isReminderEnabled
            trip.reminderLeadMinutes = newLeadMinutes
            reconcileDestinations(for: trip, with: cleanedDrafts)
        }

        // Dirty check: reconcile only when a reminder-affecting field changed,
        // or we're in create mode.
        let reminderChanged = isReminderEnabled != initialIsReminderEnabled
            || newLeadMinutes != initialLeadMinutes
            || normalizedStart != initialStartDate
        let isCreate: Bool = { if case .create = mode { return true } else { return false } }()

        do {
            try modelContext.save()
            if reminderChanged || isCreate {
                let context = modelContext
                Task { await NotificationScheduler.shared.reconcile(modelContext: context) }
            }
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
