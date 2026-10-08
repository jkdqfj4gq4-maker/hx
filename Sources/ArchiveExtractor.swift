import Foundation
import SwiftArchive

enum ArchiveExtractor {
    static func extract(url: URL) throws -> URL {
        let entries = try Archive.list(url: url)
        try validate(entries: entries)

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let archiveName = url.deletingPathExtension().lastPathComponent
        var destination = documents.appendingPathComponent(archiveName, isDirectory: true)
        var suffix = 2

        while FileManager.default.fileExists(atPath: destination.path) {
            destination = documents.appendingPathComponent("\(archiveName) (\(suffix))", isDirectory: true)
            suffix += 1
        }

        try Archive.extract(url: url, to: destination)
        return destination
    }

    private static func validate(entries: [ArchiveEntry]) throws {
        for entry in entries {
            let path = entry.path
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.isEmpty,
                  !path.hasPrefix("/"),
                  !path.contains("\\"),
                  !path.contains("\0"),
                  !components.contains("."),
                  !components.contains(".."),
                  components.first?.contains(":") != true else {
                throw ExtractionError.unsafePath(path)
            }

            guard entry.type == .file || entry.type == .directory else {
                throw ExtractionError.unsupportedEntry(path)
            }
        }
    }
}

private enum ExtractionError: LocalizedError {
    case unsafePath(String)
    case unsupportedEntry(String)

    var errorDescription: String? {
        switch self {
        case .unsafePath(let path):
            return "The archive contains an unsafe path: \(path)"
        case .unsupportedEntry(let path):
            return "The archive contains a link or unsupported item: \(path)"
        }
    }
}