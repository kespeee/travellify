import Foundation
import Observation

/// App-wide observable carrying deep-link intent. AppDelegate sets
/// `pendingDeepLink` on notification tap; ContentView observes and consumes.
///
/// Uses UUID (not PersistentIdentifier) per RESEARCH §12 — PersistentIdentifier
/// does not round-trip through userInfo.
@Observable
@MainActor
final class AppState {
    static let shared = AppState()
    private init() {}

    var pendingDeepLink: PendingDeepLink?

    enum PendingDeepLink: Equatable {
        case activity(UUID)
    }
}
