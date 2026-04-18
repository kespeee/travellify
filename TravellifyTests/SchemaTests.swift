import Testing
import SwiftData
@testable import Travellify

@MainActor
struct SchemaTests {
    @Test func containerInitializesWithMigrationPlan() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, Activity.self,
            migrationPlan: TravellifyMigrationPlan.self,
            configurations: config
        )
        #expect(container.configurations.count >= 1)
    }

    @Test func schemaV1HasFiveModels() {
        #expect(TravellifySchemaV1.models.count == 5)
    }

    @Test func migrationPlanHasNoStages() {
        #expect(TravellifyMigrationPlan.stages.isEmpty)
        #expect(TravellifyMigrationPlan.schemas.count == 1)
    }
}
