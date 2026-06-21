import Foundation
import Photos

/// Persists scan results to disk so we avoid re-scanning unchanged libraries.
/// Uses the PHPhotoLibrary change token to detect library mutations cheaply.
actor CacheService {
    private let fileURL: URL
    private let metaURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("photrail_cache.json")
        metaURL = docs.appendingPathComponent("photrail_meta.json")
    }

    // MARK: - GeoPhoto Cache

    func savePhotos(_ photos: [GeoPhoto]) throws {
        let data = try JSONEncoder().encode(photos)
        try data.write(to: fileURL, options: .atomic)
    }

    func loadPhotos() throws -> [GeoPhoto] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([GeoPhoto].self, from: data)
    }

    // MARK: - Metadata / Change Token

    struct Meta: Codable {
        var changeToken: String?
        var lastScanDate: Date
        var totalAssetCount: Int
    }

    func saveMeta(_ meta: Meta) throws {
        let data = try JSONEncoder().encode(meta)
        try data.write(to: metaURL, options: .atomic)
    }

    func loadMeta() throws -> Meta? {
        guard FileManager.default.fileExists(atPath: metaURL.path) else { return nil }
        let data = try Data(contentsOf: metaURL)
        return try JSONDecoder().decode(Meta.self, from: data)
    }

    func clearAll() throws {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: metaURL)
    }
}
