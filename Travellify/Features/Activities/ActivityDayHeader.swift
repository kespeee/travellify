import SwiftUI

struct ActivityDayHeader: View {
    let day: Date
    let count: Int

    var body: some View {
        HStack {
            Text(ActivityDateLabels.dayLabel(for: day))
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            if count > 0 {
                Text("\(count) activit\(count == 1 ? "y" : "ies")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            count > 0
                ? "\(ActivityDateLabels.dayLabel(for: day)), \(count) activit\(count == 1 ? "y" : "ies")"
                : ActivityDateLabels.dayLabel(for: day)
        )
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ActivityDayHeader(day: Date(), count: 3)
        ActivityDayHeader(day: Date().addingTimeInterval(86_400), count: 1)
        ActivityDayHeader(day: Date().addingTimeInterval(5 * 86_400), count: 0)
    }
    .padding()
}
#endif
