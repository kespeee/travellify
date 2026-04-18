import Foundation
import SwiftData

/// Non-persisted local draft of a destination during TripEditSheet editing.
/// On Save, drafts are reconciled against the Trip's actual Destination children.
struct DestinationDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    /// Non-nil if this draft maps to an existing persistent Destination (edit mode).
    /// Nil for newly-added drafts.
    let existingModelID: PersistentIdentifier?

    init(id: UUID = UUID(), name: String = "", existingModelID: PersistentIdentifier? = nil) {
        self.id = id
        self.name = name
        self.existingModelID = existingModelID
    }

    static func from(_ destination: Destination) -> DestinationDraft {
        DestinationDraft(id: destination.id, name: destination.name, existingModelID: destination.persistentModelID)
    }
}
