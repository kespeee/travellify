import SwiftData
import Foundation

extension TravellifySchemaV1 {

    @Model
    final class PackingCategory {
        var id: UUID = UUID()
        var name: String = ""
        var sortOrder: Int = 0
        var trip: Trip?

        @Relationship(deleteRule: .cascade, inverse: \PackingItem.category)
        var items: [PackingItem]? = []

        init() {}
    }
}
