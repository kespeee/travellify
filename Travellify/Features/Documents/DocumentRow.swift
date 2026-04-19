import SwiftUI
import SwiftData

struct DocumentRow: View {
    let document: Document

    private var icon: String {
        document.kind == .pdf ? "doc.richtext" : "photo"
    }

    private var kindAccessibilityWord: String {
        document.kind == .pdf ? "PDF" : "Image"
    }

    private var importedDateText: String {
        document.importedAt.formatted(.dateTime.year().month().day())
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(importedDateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.displayName), \(kindAccessibilityWord), imported \(importedDateText)")
    }
}

#if DEBUG
#Preview {
    List {
        DocumentRow(document: {
            let d = Document()
            d.displayName = "Passport Scan"
            d.kind = .pdf
            d.importedAt = Date()
            return d
        }())
    }
    .modelContainer(previewContainer)
}
#endif
