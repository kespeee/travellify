import SwiftUI

struct EmptyPackingListView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            Text("No Categories Yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)
            Text("Tap + in the top right to add your first category.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No categories yet. Tap plus in the top right to add your first category.")
    }
}

#if DEBUG
#Preview {
    EmptyPackingListView()
}
#endif
