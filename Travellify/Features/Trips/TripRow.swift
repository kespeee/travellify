import SwiftUI

struct TripRow: View {
    let trip: Trip

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let start = formatter.string(from: trip.startDate)
        let end = formatter.string(from: trip.endDate)
        return "\(start) – \(end)"
    }

    private var destinationCountText: String {
        let count = trip.destinations?.count ?? 0
        if count == 0 {
            return "No destinations"
        } else if count == 1 {
            return "1 destination"
        } else {
            return "\(count) destinations"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name)
                .font(.body)
                .foregroundStyle(.primary)
            Text("\(dateRangeText) • \(destinationCountText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    List {
        TripRow(trip: {
            let t = Trip()
            t.name = "Rome & Florence"
            t.startDate = Date()
            t.endDate = Date().addingTimeInterval(86400 * 7)
            return t
        }())
    }
    .modelContainer(previewContainer)
}
#endif
