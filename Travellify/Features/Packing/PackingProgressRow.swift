import SwiftUI

struct PackingProgressRow: View {
    let checkedCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(checkedCount) / \(totalCount) packed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(
                value: Double(checkedCount),
                total: Double(max(totalCount, 1))
            )
            .progressViewStyle(.linear)
            .tint(.accentColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(checkedCount) of \(totalCount) items packed")
        .accessibilityValue(totalCount > 0
            ? "\(Int(Double(checkedCount) / Double(totalCount) * 100))%"
            : "0%")
    }
}

#if DEBUG
#Preview("Empty") {
    PackingProgressRow(checkedCount: 0, totalCount: 0)
        .padding()
}

#Preview("Partial") {
    PackingProgressRow(checkedCount: 3, totalCount: 7)
        .padding()
}

#Preview("Complete") {
    PackingProgressRow(checkedCount: 5, totalCount: 5)
        .padding()
}
#endif
