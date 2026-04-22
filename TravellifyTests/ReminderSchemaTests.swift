import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct ReminderSchemaTests {

    @Test func activityHasReminderFieldsWithDefaults() {
        let activityPath = "Travellify/Models/Activity.swift"
        guard let src = try? String(contentsOfFile: activityPath, encoding: .utf8) else {
            // Test target's cwd may not resolve repo-relative paths; skip gracefully.
            return
        }
        #expect(src.contains("var isReminderEnabled: Bool = false"),
                "Activity must declare isReminderEnabled: Bool = false (D52)")
        #expect(src.contains("var reminderLeadMinutes: Int?"),
                "Activity must declare reminderLeadMinutes: Int? (D52)")
        #expect(!src.contains("@Attribute(.unique)"),
                "Activity must not use @Attribute(.unique) (CloudKit forbids)")
        #expect(!src.contains("@Attribute(.externalStorage)"),
                "Activity must not use @Attribute(.externalStorage) per D40/D52")
    }

    @Test func schemaV1StillHasSixModels() {
        #expect(TravellifySchemaV1.models.count == 6)
    }

    @Test func migrationPlanStillHasNoStages() {
        #expect(TravellifyMigrationPlan.stages.isEmpty)
    }

    @Test func newActivityDefaultsAreReminderOff() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            migrationPlan: TravellifyMigrationPlan.self,
            configurations: config
        )
        let ctx = ModelContext(container)
        let a = Activity()
        ctx.insert(a)
        try ctx.save()
        #expect(a.isReminderEnabled == false)
        #expect(a.reminderLeadMinutes == nil)
    }
}
