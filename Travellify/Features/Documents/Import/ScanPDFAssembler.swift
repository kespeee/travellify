import Foundation
import PDFKit
import UIKit

enum ScanPDFAssembler {
    /// Assembles [UIImage] pages into a single PDF data blob.
    /// Callable from any isolation context (no main-actor dependency).
    static func assemble(pages: [UIImage]) throws -> Data {
        let pdfDocument = PDFDocument()
        for (index, image) in pages.enumerated() {
            guard let page = PDFPage(image: image) else {
                throw FileStorageError.pdfPageCreationFailed(index: index)
            }
            pdfDocument.insert(page, at: index)
        }
        guard let data = pdfDocument.dataRepresentation() else {
            throw FileStorageError.pdfSerializationFailed
        }
        return data
    }
}
