import SwiftUI
import SwiftData
import UserNotifications

struct ActivityEditSheet: View {
    let activity: Activity?
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var title: String = ""
    @State private var startAt: Date = Date()
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var didLoadInitialValues = false

    // Reminder state (Wave 3)
    @State private var isReminderEnabled: Bool = false
    @State private var leadMinutes: Int = ReminderLeadTime.default.rawValue  // D51: default 60
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isPrimingShown: Bool = false

    // Dirty-tracking snapshot (Pitfall 6)
    @State private var initialIsReminderEnabled: Bool = false
    @State private var initialLeadMinutes: Int? = nil
    @State private var initialStartAt: Date = Date()

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

                reminderSection()
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
            .sheet(isPresented: $isPrimingShown) {
                ReminderPrimingSheet(
                    onEnable: {
                        UserDefaults.standard.set(true, forKey: "hasSeenReminderPriming")
                        isPrimingShown = false
                        Task { await requestAuthAndEnable() }
                    },
                    onCancel: {
                        UserDefaults.standard.set(true, forKey: "hasSeenReminderPriming")
                        isPrimingShown = false
                    }
                )
            }
            .task { await refreshAuthStatus() }
            .onChange(of: scenePhase) { _, new in
                if new == .active { Task { await refreshAuthStatus() } }
            }
        }
    }

    // MARK: - Reminder Section (D64)

    @ViewBuilder
    private func reminderSection() -> some View {
        Section("Reminder") {
            Toggle("Reminder", isOn: Binding(
                get: { isReminderEnabled },
                set: { newValue in handleToggleChange(newValue) }
            ))
            .disabled(ReminderPermissionState.isToggleDisabled(authStatus: authStatus))

            if isReminderEnabled && authStatus != .denied {
                Picker("Notify", selection: $leadMinutes) {
                    ForEach(ReminderLeadTime.allCases) { preset in
                        Text(preset.label).tag(preset.rawValue)
                    }
                }
            }

            if ReminderPermissionState.shouldShowOpenSettingsRow(authStatus: authStatus) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .imageScale(.small)
                    Text("Notifications disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Notifications are disabled for Travellify")

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
    }

    // MARK: - Toggle + auth flow

    private func handleToggleChange(_ newValue: Bool) {
        if newValue {
            // Going ON
            switch authStatus {
            case .notDetermined:
                let hasSeenPriming = UserDefaults.standard.bool(forKey: "hasSeenReminderPriming")
                if ReminderPermissionState.shouldShowPrimingOnToggleOn(
                    authStatus: .notDetermined,
                    hasSeenPriming: hasSeenPriming
                ) {
                    isPrimingShown = true
                } else {
                    Task { await requestAuthAndEnable() }
                }
            case .authorized, .provisional, .ephemeral:
                isReminderEnabled = true
            case .denied:
                break  // UI disables toggle; shouldn't fire
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

    // MARK: - Lifecycle

    private func loadInitialValuesIfNeeded() {
        guard !didLoadInitialValues else { return }
        didLoadInitialValues = true
        if let activity {
            title = activity.title
            startAt = activity.startAt
            location = activity.location ?? ""
            notes = activity.notes ?? ""
            isReminderEnabled = activity.isReminderEnabled
            leadMinutes = activity.reminderLeadMinutes ?? ReminderLeadTime.default.rawValue
        } else {
            startAt = ActivityDateLabels.defaultStartAt(for: trip)
        }
        // Snapshot for dirty-tracking (both create + edit modes).
        initialIsReminderEnabled = isReminderEnabled
        initialLeadMinutes = activity?.reminderLeadMinutes
        initialStartAt = startAt
    }

    // MARK: - Save

    private func save() {
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let nextLocation: String? = trimmedLocation.isEmpty ? nil : trimmedLocation
        let nextNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        // Write reminder fields to the Activity
        let newLeadMinutes: Int? = isReminderEnabled ? leadMinutes : nil

        if let activity {
            activity.title = trimmedTitle
            activity.startAt = startAt
            activity.location = nextLocation
            activity.notes = nextNotes
            activity.isReminderEnabled = isReminderEnabled
            activity.reminderLeadMinutes = newLeadMinutes
        } else {
            let newActivity = Activity()
            newActivity.title = trimmedTitle
            newActivity.startAt = startAt
            newActivity.location = nextLocation
            newActivity.notes = nextNotes
            newActivity.isReminderEnabled = isReminderEnabled
            newActivity.reminderLeadMinutes = newLeadMinutes
            newActivity.trip = trip
            modelContext.insert(newActivity)
        }

        // Dirty check (Pitfall 6): only reconcile when a reminder-affecting field changed.
        let reminderChanged = isReminderEnabled != initialIsReminderEnabled
            || newLeadMinutes != initialLeadMinutes
            || startAt != initialStartAt
            || activity == nil  // new activity creation — unconditional reconcile

        do {
            try modelContext.save()
            if reminderChanged {
                let context = modelContext
                Task { await NotificationScheduler.shared.reconcile(modelContext: context) }
            }
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
