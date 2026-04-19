import SwiftUI

struct EmptyDocumentsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            Text("No Documents Yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)
            Text("Tap + to scan, pick a photo, or import a file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No documents yet. Tap plus to scan, pick a photo, or import a file.")
    }
}

#if DEBUG
#Preview {
    EmptyDocumentsView()
}
#endif
