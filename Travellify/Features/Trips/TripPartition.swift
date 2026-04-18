import Foundation

enum TripPartition {
    static func upcoming(from trips: [Trip], now: Date = Date()) -> [Trip] {
        let today = Calendar.current.startOfDay(for: now)
        return trips
            .filter { $0.endDate >= today }
            .sorted { $0.startDate < $1.startDate }
    }

    static func past(from trips: [Trip], now: Date = Date()) -> [Trip] {
        let today = Calendar.current.startOfDay(for: now)
        return trips
            .filter { $0.endDate < today }
            .sorted { $0.startDate > $1.startDate }
    }
}
