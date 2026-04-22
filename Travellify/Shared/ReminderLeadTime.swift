import Foundation

enum ReminderLeadTime: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case oneHour = 60
    case threeHours = 180
    case oneDay = 1440

    var id: Int { rawValue }
    static let `default`: ReminderLeadTime = .oneHour   // D51

    var label: String {
        switch self {
        case .fifteenMinutes: "15 min before"
        case .oneHour: "1 hour before"
        case .threeHours: "3 hours before"
        case .oneDay: "1 day before"
        }
    }
}
