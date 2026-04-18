import SwiftUI

struct TripDetailHeader: View {
    let trip: Trip

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: trip.startDate)) – \(formatter.string(from: trip.endDate))"
    }

    private var sortedDestinations: [Destination] {
        (trip.destinations ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text(dateRangeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !sortedDestinations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedDestinations) { dest in
                            Text(dest.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
