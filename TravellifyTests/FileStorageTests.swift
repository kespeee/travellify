import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct FileStorageTests {

    // MARK: - Helpers

    private func uniqueTripID() -> String { UUID().uuidString }

    /// Resolve a raw relative path by building from base directory.
    private func resolveRaw(_ relativePath: String) throws -> URL? {
        let base = try FileStorage.baseDirectory()
        let url = base.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Make a Document whose fileRelativePath is the given path (no SwiftData context needed).
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, Activity.self,
            configurations: config
        )
    }

    // MARK: - Round-trip

    @Test func writeThenResolveRoundTrip() throws {
        let tripID = uniqueTripID()
        let relativePath = "\(tripID)/\(UUID().uuidString).pdf"
        defer { try? FileStorage.removeTripFolder(tripIDString: tripID) }

        let sampleBytes = Data("hello travellify".utf8)
        try FileStorage.write(data: sampleBytes, toRelativePath: relativePath)

        let resolvedURL = try resolveRaw(relativePath)
        #expect(resolvedURL != nil)

        let readBack = try Data(contentsOf: resolvedURL!)
        #expect(readBack == sampleBytes)
    }

    // MARK: - Missing file

    @Test func missingFileReturnsNil() throws {
        let tripID = uniqueTripID()
        let relativePath = "\(tripID)/missing.pdf"
        // No write — file should not exist
        let url = try resolveRaw(relativePath)
        #expect(url == nil)
    }

    // MARK: - Remove missing is no-op

    @Test func removeMissingIsNoOp() throws {
        let tripID = uniqueTripID()
        let relativePath = "\(tripID)/nonexistent.pdf"
        // Must not throw
        try FileStorage.remove(relativePath: relativePath)
        #expect(Bool(true)) // reached here without throw
    }

    // MARK: - Remove trip folder removes all children

    @Test func removeTripFolderRemovesAllChildren() throws {
        let tripID = uniqueTripID()
        defer { try? FileStorage.removeTripFolder(tripIDString: tripID) }

        let pathA = "\(tripID)/a.pdf"
        let pathB = "\(tripID)/b.pdf"
        let pathC = "\(tripID)/c.pdf"

        try FileStorage.write(data: Data("a".utf8), toRelativePath: pathA)
        try FileStorage.write(data: Data("b".utf8), toRelativePath: pathB)
        try FileStorage.write(data: Data("c".utf8), toRelativePath: pathC)

        #expect(try resolveRaw(pathA) != nil)
        #expect(try resolveRaw(pathB) != nil)
        #expect(try resolveRaw(pathC) != nil)

        try FileStorage.removeTripFolder(tripIDString: tripID)

        #expect(try resolveRaw(pathA) == nil)
        #expect(try resolveRaw(pathB) == nil)
        #expect(try resolveRaw(pathC) == nil)

        // Directory itself must be gone
        let base = try FileStorage.baseDirectory()
        let dir = base.appendingPathComponent(tripID, isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    // MARK: - Path-traversal guard

    @Test func pathTraversalIsRejected() throws {
        var threw = false
        do {
            try FileStorage.write(data: Data(), toRelativePath: "../escape.pdf")
        } catch {
            threw = true
        }
        #expect(threw, "Expected throw for path containing '..'")

        var threwAbsolute = false
        do {
            try FileStorage.write(data: Data(), toRelativePath: "/abs.pdf")
        } catch {
            threwAbsolute = true
        }
        #expect(threwAbsolute, "Expected throw for absolute path")
    }

    // MARK: - CloudKit-safety gate

    @Test func noUniqueOrDenyInModels() throws {
        let sourceDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // TravellifyTests/
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Travellify/Models")

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: sourceDir, includingPropertiesForKeys: nil) else {
            Issue.record("Could not enumerate Travellify/Models — path: \(sourceDir.path)")
            return
        }

        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let content = try String(contentsOf: url, encoding: .utf8)
            if content.contains("@Attribute(.unique)") || content.contains("deleteRule: .deny") {
                offenders.append(url.lastPathComponent)
            }
        }
        #expect(offenders.isEmpty, "CloudKit-unsafe schema attributes found in: \(offenders)")
    }
}
