import SwiftUI

/// Stub Settings tab — landing for v1.x Settings work.
///
/// Per D7-04 the tab is visually active but its body is a centered placeholder.
struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: DSSpacing.s16) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(DSColor.Label.secondary)

            VStack(spacing: DSSpacing.s8) {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DSColor.Label.primary)
                Text("Coming in a future update")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(DSColor.Label.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DSSpacing.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.Background.primary)
        .ignoresSafeArea()
    }
}

#if DEBUG
#Preview {
    SettingsPlaceholderView()
}
#endif
