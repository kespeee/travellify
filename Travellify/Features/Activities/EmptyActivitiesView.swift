import SwiftUI

struct EmptyActivitiesView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            Text("No activities yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)
            Text("Tap + in the top right to add your first activity.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No activities yet. Tap plus in the top right to add your first activity.")
    }
}

#if DEBUG
#Preview { EmptyActivitiesView() }
#endif
