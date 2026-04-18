import Foundation

enum TripDetailTab: String, CaseIterable, Identifiable {
    case documents
    case packing
    case activities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents:  return "Documents"
        case .packing:    return "Packing"
        case .activities: return "Activities"
        }
    }

    var placeholderHeading: String {
        switch self {
        case .documents:  return "Documents"
        case .packing:    return "Packing List"
        case .activities: return "Activities"
        }
    }

    var placeholderBody: String {
        switch self {
        case .documents:  return "Documents will appear here."
        case .packing:    return "Your packing list will appear here."
        case .activities: return "Your itinerary will appear here."
        }
    }
}
