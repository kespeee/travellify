import SwiftUI
import PDFKit
import UIKit

struct DocumentThumbnail: View {
    let document: Document

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: document.kind == .pdf ? "doc.richtext" : "photo")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
        .clipped()
        .task(id: document.fileRelativePath) {
            image = await Self.render(for: document)
        }
    }

    private static func render(for document: Document) async -> UIImage? {
        guard let url = FileStorage.resolveURL(for: document) else { return nil }
        let kind = document.kind
        return await Task.detached(priority: .userInitiated) {
            switch kind {
            case .image:
                return downsampled(url: url, maxPixelSize: 600)
            case .pdf:
                return pdfFirstPageThumbnail(url: url, maxPixelSize: 600)
            }
        }.value
    }

    nonisolated private static func downsampled(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cg)
    }

    nonisolated private static func pdfFirstPageThumbnail(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        guard let pdf = PDFDocument(url: url), let page = pdf.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let longest = max(bounds.width, bounds.height)
        let scale = longest > 0 ? maxPixelSize / longest : 1
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        return page.thumbnail(of: size, for: .mediaBox)
    }
}

#if DEBUG
#Preview {
    DocumentThumbnail(document: {
        let d = Document()
        d.displayName = "Sample"
        d.kind = .pdf
        return d
    }())
    .frame(width: 180, height: 180)
}
#endif
