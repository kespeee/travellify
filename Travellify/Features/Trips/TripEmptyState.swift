import SwiftUI

/// TripListView empty state — Figma node 93:132 (illustration node 96:870).
/// Centered illustration + title + subtitle + primary CTA. The CTA fires the
/// same NewTrip sheet entrypoint as the (populated-state) toolbar + button
/// via the onCreateTrip closure (D7-07).
struct TripEmptyState: View {
    let onCreateTrip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image("empty-state-trips")
                .resizable()
                .scaledToFit()
                .frame(width: 144, height: 144)
                .padding(.bottom, 16)
            Text("No trips yet")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)
            Text("Create your first trip to get started")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            createTripButton
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var createTripButton: some View {
        if #available(iOS 26.0, *) {
            Button("Create a trip", action: onCreateTrip)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        } else {
            Button("Create a trip", action: onCreateTrip)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

#if DEBUG
#Preview {
    TripEmptyState(onCreateTrip: {})
}
#endif
