import SwiftData
import Foundation

extension TravellifySchemaV1 {
    @Model
    final class Activity {
        var id: UUID = UUID()
        var trip: Trip?

        // Phase 4 additions (D40) — every stored property has a default to enable
        // SwiftData lightweight migration on the existing SchemaV1 store.
        var title: String = ""
        var startAt: Date = Date()
        var location: String?
        var notes: String?
        var createdAt: Date = Date()

        // Phase 5 additions (D52) — additive, defaults ensure SwiftData lightweight
        // migration stays inside SchemaV1. CloudKit-safe (no @Attribute, no .unique).
        var isReminderEnabled: Bool = false
        var reminderLeadMinutes: Int? = nil

        init() {}
    }
}
