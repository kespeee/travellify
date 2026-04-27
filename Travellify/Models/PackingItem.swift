import SwiftData
import Foundation

extension TravellifySchemaV1 {

    @Model
    final class PackingItem {
        var id: UUID = UUID()
        var name: String = ""
        var isChecked: Bool = false
        var sortOrder: Int = 0
        var category: PackingCategory?

        // Phase 7 (07-04, D7-22) — additive back-ref so uncategorized items can be
        // queried directly from a Trip. Categorized items get this set lazily by
        // PackingListView's backfill helper. CloudKit-safe (optional, no @Relationship needed
        // here — Trip.packingItems declares the inverse).
        var trip: Trip?

        init() {}
    }
}
