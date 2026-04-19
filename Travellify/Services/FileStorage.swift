import Foundation
import OSLog

enum FileStorageError: Error {
    case baseDirectoryUnavailable
    case invalidPath(String)
    case writeFailed(path: String, underlying: Error)
    case copyFailed(source: URL, destination: URL, underlying: Error)
    case pdfPageCreationFailed(index: Int)
    case pdfSerializationFailed
}

extension Logger {
    static let fileStorage = Logger(subsystem: "com.travellify.app", category: "FileStorage")
}

enum FileStorage {

    // MARK: - Base directory

    /// "<AppSupport>/Documents/". Created on first call (idempotent).
    static func baseDirectory() throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw FileStorageError.baseDirectoryUnavailable
        }
        let base = appSupport.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// "<base>/<tripIDString>/" — created if missing.
    static func tripFolder(tripIDString: String) throws -> URL {
        try validateComponent(tripIDString)
        let folder = try baseDirectory().appendingPathComponent(tripIDString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    // MARK: - Path resolution

    /// Returns an on-disk URL for the document, or nil if the file is missing.
    static func resolveURL(for document: Document) -> URL? {
        guard !document.fileRelativePath.isEmpty else { return nil }
        do {
            try validateRelativePath(document.fileRelativePath)
            let url = try baseDirectory().appendingPathComponent(document.fileRelativePath)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        } catch {
            Logger.fileStorage.error("resolveURL failed for id=\(document.id, privacy: .private): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Write

    /// Writes `data` atomically to "<base>/<relativePath>". Ensures parent dir exists.
    /// REJECTS paths containing ".." or starting with "/" (path-traversal defense).
    static func write(data: Data, toRelativePath relativePath: String) throws {
        try validateRelativePath(relativePath)
        let destination = try baseDirectory().appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            throw FileStorageError.writeFailed(path: relativePath, underlying: error)
        }
    }

    /// Copies from an external URL into "<base>/<relativePath>".
    /// Defensively manages security-scoped resource lifecycle.
    static func copy(from sourceURL: URL, toRelativePath relativePath: String) throws {
        try validateRelativePath(relativePath)
        let didStart = sourceURL.startAccessingSecurityScopedResource()
        defer { if didStart { sourceURL.stopAccessingSecurityScopedResource() } }

        let destination = try baseDirectory().appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Remove any stale existing file (copyItem fails if destination exists)
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            throw FileStorageError.copyFailed(source: sourceURL, destination: destination, underlying: error)
        }
    }

    // MARK: - Remove

    /// Removes a single file. Missing file is silent (not an error).
    static func remove(relativePath: String) throws {
        try validateRelativePath(relativePath)
        let url = try baseDirectory().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// Removes the full "<base>/<tripIDString>/" subtree. Missing is silent.
    static func removeTripFolder(tripIDString: String) throws {
        try validateComponent(tripIDString)
        let folder = try baseDirectory().appendingPathComponent(tripIDString, isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        try FileManager.default.removeItem(at: folder)
    }

    // MARK: - Validation (path-traversal defense)

    private static func validateRelativePath(_ relativePath: String) throws {
        guard !relativePath.isEmpty,
              !relativePath.contains(".."),
              !relativePath.hasPrefix("/") else {
            throw FileStorageError.invalidPath(relativePath)
        }
    }

    private static func validateComponent(_ component: String) throws {
        guard !component.isEmpty,
              !component.contains("/"),
              !component.contains(".."),
              !component.hasPrefix(".") else {
            throw FileStorageError.invalidPath(component)
        }
    }
}
