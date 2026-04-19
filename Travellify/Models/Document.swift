import SwiftData
import Foundation

enum DocumentKind: String, Codable, CaseIterable {
    case pdf
    case image
}

extension TravellifySchemaV1 {
    @Model
    final class Document {
        var id: UUID = UUID()
        var trip: Trip?

        // Phase 2 additions (D10) — every stored property has a default to enable
        // SwiftData lightweight migration on the existing SchemaV1 store.
        var displayName: String = ""
        var fileRelativePath: String = ""
        var kindRaw: String = DocumentKind.pdf.rawValue
        var importedAt: Date = Date()

        // Computed — not a stored property; no CloudKit concern.
        var kind: DocumentKind {
            get { DocumentKind(rawValue: kindRaw) ?? .pdf }
            set { kindRaw = newValue.rawValue }
        }

        init() {}
    }
}
