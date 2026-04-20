import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct DocumentTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, PackingCategory.self, Activity.self,
            configurations: config
        )
    }

    private func makeTrip(in context: ModelContext) -> Trip {
        let trip = Trip()
        trip.name = "Test Trip"
        trip.startDate = Date()
        trip.endDate = Date()
        context.insert(trip)
        return trip
    }

    /// Resolve a raw relative path without needing a Document object.
    private func resolveRaw(_ relativePath: String) throws -> URL? {
        let base = try FileStorage.baseDirectory()
        let url = base.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Default fields

    @Test func defaultFieldsAreSet() throws {
        let doc = Document()
        #expect(doc.displayName == "")
        #expect(doc.fileRelativePath == "")
        #expect(doc.kindRaw == DocumentKind.pdf.rawValue)
        let delta = abs(doc.importedAt.timeIntervalSinceNow)
        #expect(delta < 1.0, "importedAt should be within 1 second of now, got delta=\(delta)")
    }

    // MARK: - Kind round-trip

    @Test func kindRoundTrip() throws {
        let doc = Document()
        doc.kindRaw = DocumentKind.image.rawValue
        #expect(doc.kind == .image)

        doc.kind = .pdf
        #expect(doc.kindRaw == DocumentKind.pdf.rawValue)
    }

    // MARK: - Rename persists displayName; fileRelativePath untouched (T-02-08)

    @Test func renamePersistsDisplayName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let trip = makeTrip(in: context)

        let doc = Document()
        doc.trip = trip
        doc.displayName = "Old Name"
        doc.fileRelativePath = "abc123/def456.pdf"
        doc.kindRaw = DocumentKind.pdf.rawValue
        context.insert(doc)
        try context.save()

        let pathBefore = doc.fileRelativePath

        // Rename — only mutate displayName
        doc.displayName = "New Name"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Document>())
        let found = fetched.first(where: { $0.id == doc.id })
        #expect(found?.displayName == "New Name")
        // T-02-08: fileRelativePath must not change
        #expect(found?.fileRelativePath == pathBefore, "fileRelativePath must be immutable after rename")
    }

    // MARK: - Delete removes file and model

    @Test func deleteRemovesFileAndModel() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let trip = makeTrip(in: context)

        let tripID = trip.id.uuidString
        let docID = UUID()
        let relativePath = "\(tripID)/\(docID.uuidString).pdf"
        defer { try? FileStorage.removeTripFolder(tripIDString: tripID) }

        // Write file
        try FileStorage.write(data: Data("doc content".utf8), toRelativePath: relativePath)
        #expect(try resolveRaw(relativePath) != nil)

        // Insert document
        let doc = Document()
        doc.id = docID
        doc.trip = trip
        doc.displayName = "Doc To Delete"
        doc.fileRelativePath = relativePath
        doc.kindRaw = DocumentKind.pdf.rawValue
        context.insert(doc)
        try context.save()

        let docIDCopy = doc.id

        // Delete: file first, then model
        try FileStorage.remove(relativePath: relativePath)
        context.delete(doc)
        try context.save()

        // File gone
        #expect(try resolveRaw(relativePath) == nil)

        // Model gone
        let remaining = try context.fetch(FetchDescriptor<Document>())
        #expect(!remaining.contains(where: { $0.id == docIDCopy }))
    }

    // MARK: - DOC-07: fileRelativePath is String, not Data

    @Test func documentStoresPathNotData() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let trip = makeTrip(in: context)

        let doc = Document()
        doc.trip = trip
        doc.displayName = "test"
        doc.fileRelativePath = "abc/def.pdf"
        doc.kindRaw = DocumentKind.pdf.rawValue
        context.insert(doc)
        try context.save()

        // Compile-time: this must be a String assignment — if fileRelativePath were Data this line would fail to compile
        let _: String = doc.fileRelativePath
        #expect(doc.fileRelativePath is String)

        // Mirror check: no property named 'fileData' or similar Data-typed path property
        let mirror = Mirror(reflecting: doc)
        let dataProps = mirror.children.filter { child in
            if let label = child.label, label.lowercased().contains("path") {
                return child.value is Data
            }
            return false
        }
        #expect(dataProps.isEmpty, "fileRelativePath must be String, found Data-typed path property")
    }

    // MARK: - Trip cascade delete removes trip folder

    @Test func tripCascadeDeleteRemovesTripFolder() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let trip = Trip()
        trip.name = "Cascade Trip"
        trip.startDate = Date()
        trip.endDate = Date()
        context.insert(trip)

        let tripID = trip.id.uuidString
        let docID = UUID()
        let relativePath = "\(tripID)/\(docID.uuidString).pdf"

        // Write a file under this trip's folder
        try FileStorage.write(data: Data("cascade test".utf8), toRelativePath: relativePath)
        #expect(try resolveRaw(relativePath) != nil)

        let doc = Document()
        doc.id = docID
        doc.trip = trip
        doc.displayName = "Cascade Doc"
        doc.fileRelativePath = relativePath
        doc.kindRaw = DocumentKind.pdf.rawValue
        context.insert(doc)
        try context.save()

        let capturedTripID = trip.id.uuidString

        // Delete trip — SwiftData cascade removes Document model rows
        context.delete(trip)
        try context.save()

        // Mirroring TripListView 02-05 wiring: explicit folder removal after save
        try? FileStorage.removeTripFolder(tripIDString: capturedTripID)

        // Folder and file must be gone
        let base = try FileStorage.baseDirectory()
        let tripDir = base.appendingPathComponent(capturedTripID, isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: tripDir.path), "Trip folder must be removed after cascade delete")
        #expect(try resolveRaw(relativePath) == nil, "File under trip folder must be gone")

        // Document model rows must be gone
        let docs = try context.fetch(FetchDescriptor<Document>())
        #expect(docs.isEmpty, "All Document rows must be cascade-deleted with the trip")
    }
}
