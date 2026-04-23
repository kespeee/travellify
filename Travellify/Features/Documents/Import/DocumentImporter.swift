import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

enum DocumentImporter {

    // MARK: - Scan

    @MainActor
    static func importScanResult(
        pages: [UIImage],
        trip: Trip,
        modelContext: ModelContext
    ) async throws {
        let tripIDString = trip.id.uuidString
        let docID = UUID()
        let relativePath = "\(tripIDString)/\(docID.uuidString).pdf"

        // Assemble + write off-main; pages are @unchecked Sendable (Apple overlay)
        try await Task.detached(priority: .userInitiated) {
            let pdfData = try ScanPDFAssembler.assemble(pages: pages)
            try FileStorage.write(data: pdfData, toRelativePath: relativePath)
        }.value

        let doc = Document()
        doc.id = docID
        doc.displayName = "Scan " + Self.localizedDateString()
        doc.fileRelativePath = relativePath
        doc.kind = .pdf
        doc.importedAt = Date()
        doc.trip = trip
        modelContext.insert(doc)
        try modelContext.save()
    }

    // MARK: - Photos

    @MainActor
    static func importPhotosItem(
        _ item: PhotosPickerItem,
        trip: Trip,
        modelContext: ModelContext
    ) async throws {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw FileStorageError.writeFailed(
                path: "photos-pickeritem",
                underlying: PhotosImportError.dataUnavailable
            )
        }
        let ext = Self.fileExtension(for: item.supportedContentTypes) ?? "jpg"
        let tripIDString = trip.id.uuidString
        let docID = UUID()
        let relativePath = "\(tripIDString)/\(docID.uuidString).\(ext)"

        try await Task.detached(priority: .userInitiated) {
            try FileStorage.write(data: data, toRelativePath: relativePath)
        }.value

        let doc = Document()
        doc.id = docID
        doc.displayName = "Photo " + Self.localizedDateString()
        doc.fileRelativePath = relativePath
        doc.kind = .image
        doc.importedAt = Date()
        doc.trip = trip
        modelContext.insert(doc)
        try modelContext.save()
    }

    // MARK: - Files

    @MainActor
    static func importFileURL(
        _ url: URL,
        trip: Trip,
        modelContext: ModelContext
    ) async throws {
        let sourceName = url.deletingPathExtension().lastPathComponent
        let rawExt = url.pathExtension
        let ext = rawExt.isEmpty ? "bin" : rawExt
        let kind: DocumentKind = (ext.lowercased() == "pdf") ? .pdf : .image
        let tripIDString = trip.id.uuidString
        let docID = UUID()
        let relativePath = "\(tripIDString)/\(docID.uuidString).\(ext)"

        // FileStorage.copy handles security-scoped resource start/stop defensively.
        // Kick it off immediately to beat system cleanup of asCopy temp URL (Pitfall 4).
        try await Task.detached(priority: .userInitiated) {
            try FileStorage.copy(from: url, toRelativePath: relativePath)
        }.value

        let doc = Document()
        doc.id = docID
        doc.displayName = sourceName.isEmpty ? "Document" : sourceName
        doc.fileRelativePath = relativePath
        doc.kind = kind
        doc.importedAt = Date()
        doc.trip = trip
        modelContext.insert(doc)
        try modelContext.save()
    }

    // MARK: - Helpers

    private static func localizedDateString() -> String {
        Date().formatted(.dateTime.year().month().day())
    }

    // Stub — real implementation in GREEN commit.
    @MainActor
    static func nextDefaultName(in trip: Trip) -> String {
        "doc-stub"
    }

    private static func fileExtension(for types: [UTType]) -> String? {
        if types.contains(where: { $0.conforms(to: .heic) }) { return "heic" }
        if types.contains(where: { $0.conforms(to: .jpeg) }) { return "jpg" }
        if types.contains(where: { $0.conforms(to: .png) }) { return "png" }
        return types.first?.preferredFilenameExtension
    }
}

enum PhotosImportError: Error {
    case dataUnavailable
}
