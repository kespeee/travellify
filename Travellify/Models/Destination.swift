import SwiftData
import Foundation

extension TravellifySchemaV1 {

    @Model
    final class Destination {
        var id: UUID = UUID()
        var name: String = ""
        var sortIndex: Int = 0

        // NULLIFY inverse — CloudKit requires optional back-reference
        var trip: Trip?

        init() {}
    }
}
