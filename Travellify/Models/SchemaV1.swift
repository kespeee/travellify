import SwiftData
import Foundation

enum TravellifySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            TravellifySchemaV1.Trip.self,
            TravellifySchemaV1.Destination.self,
            TravellifySchemaV1.Document.self,
            TravellifySchemaV1.PackingItem.self,
            TravellifySchemaV1.Activity.self,
        ]
    }
}

enum TravellifyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TravellifySchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// Module-level typealiases — call sites write `Trip` everywhere
typealias Trip        = TravellifySchemaV1.Trip
typealias Destination = TravellifySchemaV1.Destination
typealias Document    = TravellifySchemaV1.Document
typealias PackingItem = TravellifySchemaV1.PackingItem
typealias Activity    = TravellifySchemaV1.Activity
