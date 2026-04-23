import Testing
import SwiftData
import Foundation
@preconcurrency import UserNotifications
@testable import Travellify

/// Integration tests for ACT-08 (reschedule-on-edit + cancel-on-delete +
/// trip-cascade-cancel) driven through `NotificationScheduler.reconcile`
/// with an injected `MockNotificationCenter`.
///
/// Pattern note (Wave 2 SUMMARY): `MockNotificationCenter.remove(...)` dispatches
/// via `Task { @MainActor in }`, so after any path that cancels notifications
/// we must `await Task.yield()` before asserting `mock.pending`.
@MainActor
struct ReminderLifecycleTests {

    // MARK: - Fixtures

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            configurations: config
        )
    }

    private func makeTrip(in context: ModelContext) -> Trip {
        let trip = Trip()
        trip.name = "Paris trip"
        trip.startDate = Date()
        trip.endDate = Date().addingTimeInterval(86_400 * 7)
        context.insert(trip)
        return trip
    }

    @discardableResult
    private func insertActivity(
        title: String,
        startAt: Date,
        leadMinutes: Int?,
        enabled: Bool,
        trip: Trip,
        in context: ModelContext
    ) -> Activity {
        let a = Activity()
        a.title = title
        a.startAt = startAt
        a.isReminderEnabled = enabled
        a.reminderLeadMinutes = leadMinutes
        a.trip = trip
        context.insert(a)
        return a
    }

    // MARK: - Tests

    @Test func scheduleOnEnable() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        // fireDate = startAt - 60min, must be > now.
        let startAt = Date().addingTimeInterval(2 * 3600)
        let activity = insertActivity(
            title: "Louvre",
            startAt: startAt,
            leadMinutes: 60,
            enabled: true,
            trip: trip,
            in: ctx
        )
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)

        #expect(mock.pending.count == 1)
        #expect(mock.pending.first?.identifier == activity.id.uuidString)
    }

    @Test func rescheduleOnDateChange() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let startAt = Date().addingTimeInterval(3 * 3600)
        let activity = insertActivity(
            title: "Dinner",
            startAt: startAt,
            leadMinutes: 60,
            enabled: true,
            trip: trip,
            in: ctx
        )
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)

        #expect(mock.pending.count == 1)
        let initialID = mock.pending.first?.identifier
        let initialTrigger = mock.pending.first?.trigger as? UNCalendarNotificationTrigger
        let initialHour = initialTrigger?.dateComponents.hour

        // Advance startAt by +1h — fireDate shifts +1h, new trigger replaces old
        // under the same identifier via the scheduler's delete-then-add diff.
        activity.startAt = startAt.addingTimeInterval(3600)
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        // Yield so MockNotificationCenter's Task-based remove drains before assertion.
        await Task.yield()

        #expect(mock.pending.count == 1)
        #expect(mock.pending.first?.identifier == initialID)
        let newTrigger = mock.pending.first?.trigger as? UNCalendarNotificationTrigger
        let newHour = newTrigger?.dateComponents.hour
        // Hours should differ by 1 (modulo 24). If the hour wraps across midnight,
        // (newHour - initialHour + 24) % 24 == 1.
        if let initialHour, let newHour {
            let delta = ((newHour - initialHour) + 24) % 24
            #expect(delta == 1)
        } else {
            Issue.record("Missing hour components on trigger")
        }
    }

    @Test func cancelOnDelete() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        let activity = insertActivity(
            title: "Colosseum",
            startAt: Date().addingTimeInterval(4 * 3600),
            leadMinutes: 60,
            enabled: true,
            trip: trip,
            in: ctx
        )
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)
        #expect(mock.pending.count == 1)

        ctx.delete(activity)
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        // Yield so MockNotificationCenter's Task-based remove drains.
        await Task.yield()

        #expect(mock.pending.isEmpty)
    }

    @Test func cancelOnTripCascade() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let trip = makeTrip(in: ctx)

        _ = insertActivity(
            title: "Activity 1",
            startAt: Date().addingTimeInterval(5 * 3600),
            leadMinutes: 60,
            enabled: true,
            trip: trip,
            in: ctx
        )
        _ = insertActivity(
            title: "Activity 2",
            startAt: Date().addingTimeInterval(6 * 3600),
            leadMinutes: 60,
            enabled: true,
            trip: trip,
            in: ctx
        )
        try ctx.save()

        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        await scheduler.reconcile(modelContext: ctx)
        #expect(mock.pending.count == 2)

        ctx.delete(trip)
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        // Yield so MockNotificationCenter's Task-based remove drains.
        await Task.yield()

        #expect(mock.pending.isEmpty)
    }

    // MARK: - Trip lifecycle (TRIP-08)

    @discardableResult
    private func insertTripReminder(
        name: String = "Paris",
        startDate: Date,
        leadMinutes: Int = 4320,
        in context: ModelContext
    ) -> Trip {
        let trip = Trip()
        trip.name = name
        trip.startDate = startDate
        trip.endDate = startDate.addingTimeInterval(86_400 * 7)
        trip.isReminderEnabled = true
        trip.reminderLeadMinutes = leadMinutes
        context.insert(trip)
        return trip
    }

    @Test func tripToggleOffCancels() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        let trip = insertTripReminder(startDate: Date().addingTimeInterval(86_400 * 10), in: ctx)
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        await Task.yield()
        #expect(mock.pending.count == 1)

        trip.isReminderEnabled = false
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        await Task.yield()
        #expect(mock.pending.isEmpty)
    }

    @Test func tripDateEditReschedules() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        let trip = insertTripReminder(startDate: Date().addingTimeInterval(86_400 * 10), in: ctx)
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        await Task.yield()
        let expectedID = "trip-\(trip.id.uuidString)"
        #expect(mock.pending.first?.identifier == expectedID)

        trip.startDate = trip.startDate.addingTimeInterval(86_400)
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        await Task.yield()
        #expect(mock.pending.count == 1)
        #expect(mock.pending.first?.identifier == expectedID)  // same identifier
    }

    @Test func tripDeleteCancels() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let mock = MockNotificationCenter()
        let scheduler = NotificationScheduler(center: mock)
        let trip = insertTripReminder(startDate: Date().addingTimeInterval(86_400 * 10), in: ctx)
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        await Task.yield()
        #expect(mock.pending.count == 1)

        ctx.delete(trip)
        try ctx.save()
        await scheduler.reconcile(modelContext: ctx)
        await Task.yield()
        #expect(mock.pending.isEmpty)
    }
}
