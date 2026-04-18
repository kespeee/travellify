import Foundation
import SwiftData

enum AppDestination: Hashable {
    case tripDetail(PersistentIdentifier)   // PersistentIdentifier is Hashable + Sendable
}
