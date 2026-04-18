import SwiftData
import Foundation

extension TravellifySchemaV1 {
    @Model
    final class Document {
        var id: UUID = UUID()
        var trip: Trip?

        init() {}
    }
}
