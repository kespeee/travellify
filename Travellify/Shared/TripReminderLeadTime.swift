import Foundation

enum TripReminderLeadTime: Int, CaseIterable, Identifiable {
    case oneDay = 1440
    case threeDays = 4320
    case oneWeek = 10080
    case twoWeeks = 20160

    var id: Int { rawValue }
    static let `default`: TripReminderLeadTime = .threeDays

    var label: String {
        switch self {
        case .oneDay:    "1 day before"
        case .threeDays: "3 days before"
        case .oneWeek:   "1 week before"
        case .twoWeeks:  "2 weeks before"
        }
    }

    var bodyPhrase: String {
        switch self {
        case .oneDay:    "tomorrow"
        case .threeDays: "in 3 days"
        case .oneWeek:   "in 1 week"
        case .twoWeeks:  "in 2 weeks"
        }
    }
}
