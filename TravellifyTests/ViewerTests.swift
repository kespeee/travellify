import Testing
import PDFKit
import Foundation
@testable import Travellify

// Reference type anchor for Bundle lookup in Swift Testing structs
private final class ViewerBundleAnchor {}

@MainActor
struct ViewerTests {

    // MARK: - Helpers

    private func fixtureURL(name: String, ext: String) throws -> URL {
        let bundle = Bundle(for: ViewerBundleAnchor.self)
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw ViewerTestError.fixtureNotFound("\(name).\(ext)")
        }
        return url
    }

    // MARK: - DOC-04: PDFView loads PDF URL smoke

    @Test func pdfViewerLoadsDocumentUrl() throws {
        let fixtureURL = try fixtureURL(name: "tiny-pdf", ext: "pdf")

        // Validate the PDFKit contract that PDFKitView's makeUIView depends on
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: fixtureURL)

        #expect(pdfView.document != nil, "PDFView must successfully load document from URL \(fixtureURL.path)")
        #expect(pdfView.document?.pageCount == 1, "tiny-pdf.pdf must have exactly 1 page")
        #expect(pdfView.document?.documentURL == fixtureURL, "PDFDocument URL must match the fixture URL")
    }
}

// MARK: - Error types

private enum ViewerTestError: Error {
    case fixtureNotFound(String)
}
