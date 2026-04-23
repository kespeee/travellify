import SwiftUI
import SwiftData

struct DocumentRow: View {
    let document: Document

    private var kindAccessibilityWord: String {
        document.kind == .pdf ? "PDF" : "Image"
    }

    private var importedDateText: String {
        document.importedAt.formatted(.dateTime.year().month().day())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DocumentThumbnail(document: document)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(document.displayName)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.displayName), \(kindAccessibilityWord), imported \(importedDateText)")
    }
}

#if DEBUG
#Preview {
    DocumentRow(document: {
        let d = Document()
        d.displayName = "Passport Scan"
        d.kind = .pdf
        d.importedAt = Date()
        return d
    }())
    .padding()
    .frame(width: 180)
    .modelContainer(previewContainer)
}
#endif
