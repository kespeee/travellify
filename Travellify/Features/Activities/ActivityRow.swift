import SwiftUI
import SwiftData

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(ActivityDateLabels.timeLabel(for: activity.startAt))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
                .accessibilityHidden(true)   // combined below

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title.isEmpty ? "Untitled" : activity.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let loc = activity.location, !loc.isEmpty {
                    Text(loc)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let title = activity.title.isEmpty ? "Untitled activity" : activity.title
        let time = ActivityDateLabels.timeLabel(for: activity.startAt)
        if let loc = activity.location, !loc.isEmpty {
            return "\(title), \(time), \(loc)"
        }
        return "\(title), \(time)"
    }
}

#if DEBUG
#Preview {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let a = Activity()
    a.title = "Louvre tour"
    a.startAt = Date()
    a.location = "Paris"
    container.mainContext.insert(a)
    return List { ActivityRow(activity: a) }
        .modelContainer(container)
}
#endif
