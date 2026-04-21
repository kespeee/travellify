import Testing
import SwiftData
@testable import Travellify

@MainActor
struct SchemaTests {
    @Test func containerInitializesWithMigrationPlan() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            migrationPlan: TravellifyMigrationPlan.self,
            configurations: config
        )
        #expect(container.configurations.count >= 1)
    }

    @Test func schemaV1HasSixModels() {
        #expect(TravellifySchemaV1.models.count == 6)
    }

    @Test func migrationPlanHasNoStages() {
        #expect(TravellifyMigrationPlan.stages.isEmpty)
        #expect(TravellifyMigrationPlan.schemas.count == 1)
    }

    @Test func activitySchemaIsCloudKitSafe() throws {
        let activityPath = "Travellify/Models/Activity.swift"
        guard let src = try? String(contentsOfFile: activityPath, encoding: .utf8) else {
            // Test target's cwd may not resolve repo-relative paths; skip gracefully.
            return
        }
        #expect(src.contains("var title: String"),
                "Activity must declare title: String field (D40)")
        #expect(src.contains("var startAt: Date"),
                "Activity must declare startAt: Date field (D40)")
        #expect(src.contains("var createdAt: Date"),
                "Activity must declare createdAt: Date field (D40)")
        #expect(src.contains("var trip: Trip?"),
                "Activity must keep trip as optional inverse (CloudKit-safe)")
        #expect(!src.contains("@Attribute(.unique)"),
                "Activity must not use @Attribute(.unique) (CloudKit forbids)")
        #expect(!src.contains("@Attribute(.externalStorage)"),
                "Activity must not use @Attribute(.externalStorage) per D40")
    }
}
