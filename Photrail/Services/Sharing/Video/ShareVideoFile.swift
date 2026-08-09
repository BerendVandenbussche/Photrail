import Foundation

/// Where exported share videos live before they're handed to the share sheet.
///
/// Everything goes in one subdirectory of `tmp/` so cleanup is a single sweep. iOS empties
/// `tmp/` eventually, but not promptly, and each export is several megabytes.
enum ShareVideoFile {

    private static let directoryName = "ShareVideos"

    private static var directory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    /// A fresh `.mp4` URL. The last path component becomes the suggested filename in Files
    /// and Mail, so `name` should read like something a person would want on disk.
    static func makeURL(named name: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safe = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return directory.appendingPathComponent("\(safe).mp4")
    }

    /// Deletes a single export once the share sheet is done with it.
    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Drops every leftover export. Called at launch as a backstop for shares that were
    /// interrupted (app killed mid-sheet), where the per-file cleanup never ran.
    static func purge() {
        try? FileManager.default.removeItem(at: directory)
    }
}
