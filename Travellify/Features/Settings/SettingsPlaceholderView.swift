import SwiftUI

/// Stub Settings tab — landing for v1.x Settings work.
///
/// Per D7-04 the tab is visually active but its body is a centered placeholder.
/// Matches the TripListView empty-state pattern (large title + centered empty
/// state) so both root tabs share the same shell.
struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Image(systemName: "gearshape")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 32)
                Text("Coming Soon")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 8)
                Text("Settings will be available in a future update.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Settings coming soon. Settings will be available in a future update.")
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#if DEBUG
#Preview {
    SettingsPlaceholderView()
}
#endif
