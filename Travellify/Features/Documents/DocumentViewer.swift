import SwiftUI
import PDFKit
import SwiftData

struct DocumentViewer: View {
    let document: Document

    @Environment(\.dismiss) private var dismiss
    @State private var imageScale: CGFloat = 1.0
    @State private var lastImageScale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                if let fileURL = FileStorage.resolveURL(for: document) {
                    switch document.kind {
                    case .pdf:
                        PDFKitView(url: fileURL)
                            .ignoresSafeArea(edges: .bottom)
                    case .image:
                        imageBody(url: fileURL)
                    }
                } else {
                    errorBody
                }
            }

            topChrome
        }
    }

    @ViewBuilder
    private func imageBody(url: URL) -> some View {
        if let uiImage = UIImage(contentsOfFile: url.path) {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(imageScale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                imageScale = min(max(lastImageScale * value, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastImageScale = imageScale
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            imageScale = 1.0
                            lastImageScale = 1.0
                        }
                    }
                    .accessibilityLabel(document.displayName)
            }
        } else {
            errorBody
        }
    }

    private var errorBody: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("This document is unavailable.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topChrome: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")

            Spacer(minLength: 8)

            Text(document.displayName)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
    }
}

#if DEBUG
private struct DocumentViewerPreview: View {
    private let container: ModelContainer = {
        try! ModelContainer(
            for: Trip.self, Destination.self, Document.self, PackingItem.self, Activity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()

    private let doc: Document = {
        let d = Document()
        d.displayName = "Sample Doc"
        d.kindRaw = "pdf"
        d.fileRelativePath = "missing/path.pdf"
        return d
    }()

    var body: some View {
        DocumentViewer(document: doc)
            .modelContainer(container)
    }
}

#Preview("Missing file") {
    DocumentViewerPreview()
}
#endif
