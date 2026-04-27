import SwiftUI

/// Compact trip row used in the FOLLOWING and PAST sections of TripListView
/// (Figma node 115:1744 — `Multiplier Info` card).
struct FollowingTripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 16) {
            DatePill(date: trip.startDate)
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(trip.name), \(subtitle)"))
    }

    private var subtitle: String {
        let days = Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0
        let destCount = trip.destinations?.count ?? 0
        return "\(days) day\(days == 1 ? "" : "s") • \(destCount) destination\(destCount == 1 ? "" : "s")"
    }

    private struct DatePill: View {
        let date: Date

        var body: some View {
            let cal = Calendar.current
            let monthFmt: DateFormatter = {
                let f = DateFormatter()
                f.setLocalizedDateFormatFromTemplate("MMM")
                return f
            }()
            let month = monthFmt.string(from: date)
            let day = cal.component(.day, from: date)

            VStack(spacing: 0) {
                Text(month.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.259, blue: 0.271))
                Text("\(day)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: 52, height: 52)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
    }
}

#if DEBUG
#Preview {
    FollowingTripRow(trip: Trip())
        .padding()
        .background(Color.black)
}
#endif
