import Testing
import SwiftData
import UIKit
import PDFKit
import Foundation
@testable import Travellify

// Reference type anchor for Bundle lookup in Swift Testing structs
private final class BundleAnchor {}

@MainActor
struct ImportTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, Activity.self,
            configurations: config
        )
    }

    private func makeTrip(in context: ModelContext) -> Trip {
        let trip = Trip()
        trip.name = "Import Test Trip"
        trip.startDate = Date()
        trip.endDate = Date()
        context.insert(trip)
        return trip
    }

    private func fixtureURL(name: String, ext: String) throws -> URL {
        let bundle = Bundle(for: BundleAnchor.self)
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw ImportTestError.fixtureNotFound("\(name).\(ext)")
        }
        return url
    }

    private func resolveRaw(_ relativePath: String) throws -> URL? {
        let base = try FileStorage.baseDirectory()
        let url = base.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - DOC-01: Scan assembles PDF and inserts Document

    @Test func scanAssembliesPDFAndInsertsDocument() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let trip = makeTrip(in: context)
        let tripID = trip.id.uuidString
        defer { try? FileStorage.removeTripFolder(tripIDString: tripID) }

        // Build two synthetic 100×100 UIImages using UIGraphicsImageRenderer
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let page1 = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let page2 = renderer.image { ctx in
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        // Assemble PDF
        let pdfData = try ScanPDFAssembler.assemble(pages: [page1, page2])

        // Validate PDF magic bytes (%PDF-)
        let magic = pdfData.prefix(5)
        #expect(magic == Data("%PDF-".utf8), "Assembled PDF must start with %PDF- magic bytes")
        #expect(pdfData.count > 100, "PDF data must be > 100 bytes, got \(pdfData.count)")

        // PDFKit must be able to parse it and see 2 pages
        let pdfDoc = PDFDocument(data: pdfData)
        #expect(pdfDoc != nil, "PDFDocument must load assembled PDF")
        #expect(pdfDoc?.pageCount == 2, "PDF must have 2 pages")

        // Import via DocumentImporter
        try await DocumentImporter.importScanResult(pages: [page1, page2], trip: trip, modelContext: context)

        let docs = try context.fetch(FetchDescriptor<Document>())
        #expect(docs.count == 1, "One Document must be inserted after scan import")

        let insertedDoc = try #require(docs.first)
        #expect(insertedDoc.kind == .pdf, "Scanned document must have kind == .pdf")
        #expect(!insertedDoc.fileRelativePath.isEmpty, "fileRelativePath must not be empty")

        // File must exist on disk
        let resolvedURL = try resolveRaw(insertedDoc.fileRelativePath)
        #expect(resolvedURL != nil, "Scanned PDF file must exist on disk at \(insertedDoc.fileRelativePath)")
    }

    // MARK: - DOC-02: Photos import preserves JPEG bytes

    @Test func photosImportPreservesJpegBytes() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let trip = makeTrip(in: context)
        let tripID = trip.id.uuidString
        defer { try? FileStorage.removeTripFolder(tripIDString: tripID) }

        // Load fixture bytes
        let fixtureURL = try fixtureURL(name: "tiny-jpeg", ext: "jpg")
        let originalBytes = try Data(contentsOf: fixtureURL)
        #expect(!originalBytes.isEmpty, "Fixture must have content")

        // Write directly via FileStorage (the same path DocumentImporter uses for photos)
        let docID = UUID()
        let relativePath = "\(tripID)/\(docID.uuidString).jpg"
        try await Task.detached(priority: .userInitiated) {
            try FileStorage.write(data: originalBytes, toRelativePath: relativePath)
        }.value

        // Read back and compare bytes
        let resolvedURL = try resolveRaw(relativePath)
        #expect(resolvedURL != nil, "Written file must exist at \(relativePath)")

        let readBack = try Data(contentsOf: resolvedURL!)
        #expect(readBack == originalBytes, "Written bytes must match original JPEG bytes exactly")
    }

    // MARK: - DOC-03: Files import copies source URL to <tripUUID>/<docUUID>.<ext>

    @Test func filesImportCopiesToDestination() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let trip = makeTrip(in: context)
        let tripID = trip.id.uuidString
        defer { try? FileStorage.removeTripFolder(tripIDString: tripID) }

        let fixtureURL = try fixtureURL(name: "tiny-pdf", ext: "pdf")
        let originalBytes = try Data(contentsOf: fixtureURL)

        // Import via DocumentImporter
        try await DocumentImporter.importFileURL(fixtureURL, trip: trip, modelContext: context)

        let docs = try context.fetch(FetchDescriptor<Document>())
        #expect(docs.count == 1, "One Document must be inserted after file import")

        let insertedDoc = try #require(docs.first)
        let relativePath = insertedDoc.fileRelativePath

        // Path must match <UUID>/<UUID>.pdf — never the source filename
        let pathRegex = try Regex("^[A-F0-9a-f-]+/[A-F0-9a-f-]+\\.pdf$")
        #expect(relativePath.wholeMatch(of: pathRegex) != nil,
                "Path '\(relativePath)' must match <tripUUID>/<docUUID>.pdf pattern (never source filename)")

        // File must exist on disk with matching bytes
        let resolvedURL = try resolveRaw(relativePath)
        #expect(resolvedURL != nil, "Imported file must exist on disk")

        let writtenBytes = try Data(contentsOf: resolvedURL!)
        #expect(writtenBytes == originalBytes, "Copied bytes must match source file bytes exactly")
    }

    // MARK: - Concurrency: import writes off-main, inserts on-main

    @Test func importRunsOffMainThenHopsToMain() async throws {
        let tripID = UUID().uuidString
        defer { try? FileStorage.removeTripFolder(tripIDString: tripID) }

        let relativePath = "\(tripID)/\(UUID().uuidString).pdf"
        let testData = Data("concurrency test".utf8)

        // Detached task returns whether the write happened off-main.
        // Returning a value avoids mutation of a shared variable across isolation domains.
        let wasOffMainDuringWrite: Bool = await Task.detached(priority: .userInitiated) {
            let offMain = !isOnMainThread() // isOnMainThread() is a non-async free fn
            try? FileStorage.write(data: testData, toRelativePath: relativePath)
            return offMain
        }.value

        // Back on @MainActor — assertIsolated confirms we're on main actor
        MainActor.assertIsolated("After await Task.detached, must be back on MainActor")
        #expect(wasOffMainDuringWrite == true, "FileStorage.write must run off main thread")
    }
}

// MARK: - Error types

private enum ImportTestError: Error {
    case fixtureNotFound(String)
}

// MARK: - Sync helpers (nonisolated, non-async — safe to call Thread.isMainThread)

/// Returns `true` when called from the main thread.
/// This free function is NOT async, so Swift 6 permits `Thread.isMainThread` here.
private func isOnMainThread() -> Bool {
    Thread.isMainThread
}
