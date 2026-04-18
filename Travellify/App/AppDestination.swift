import Foundation
import SwiftData

enum AppDestination: Hashable {
    case tripDetail(Trip.ID)   // Trip.ID is PersistentIdentifier (Hashable + Sendable)
}
