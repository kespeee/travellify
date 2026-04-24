import SwiftUI

/// 2-tab root introduced by Phase 7 wave 1 (D7-04). Hosts the existing
/// `ContentView` (Trips tab) and `SettingsPlaceholderView` (Settings stub).
///
/// Watches `AppState.pendingDeepLink` and flips the selected tab to `.trips`
/// before `ContentView`'s own onChange handler pushes the destination — this
/// keeps the existing Phase 6 D81 deep-link flow intact.
struct TabBarRoot: View {
    enum Tab: Hashable {
        case trips
        case settings
    }

    @State private var selectedTab: Tab = .trips
    private let appState = AppState.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem { Label("Trips", systemImage: "airplane") }
                .tag(Tab.trips)

            SettingsPlaceholderView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(DSColor.Accent.primary)
        .onChange(of: appState.pendingDeepLink) { _, newValue in
            if newValue != nil {
                selectedTab = .trips
            }
        }
    }
}

#if DEBUG
#Preview {
    TabBarRoot()
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}
#endif
