import SwiftData
import Foundation

extension TravellifySchemaV1 {

    @Model
    final class Trip {
        var id: UUID = UUID()
        var name: String = ""
        var startDate: Date = Date()
        var endDate: Date = Date()
        var createdAt: Date = Date()

        // Phase 6 (D76) — additive reminder fields, CloudKit-safe defaults
        var isReminderEnabled: Bool = false
        var reminderLeadMinutes: Int? = nil

        // CASCADE — child records deleted when trip is deleted
        @Relationship(deleteRule: .cascade, inverse: \Destination.trip)
        var destinations: [Destination]? = []

        @Relationship(deleteRule: .cascade, inverse: \Document.trip)
        var documents: [Document]? = []

        @Relationship(deleteRule: .cascade, inverse: \PackingCategory.trip)
        var packingCategories: [PackingCategory]? = []

        @Relationship(deleteRule: .cascade, inverse: \Activity.trip)
        var activities: [Activity]? = []

        init() {}
    }
}
