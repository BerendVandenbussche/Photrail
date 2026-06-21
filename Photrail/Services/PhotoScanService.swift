import Foundation
import Photos

/// Scans the photo library for geotagged assets.
/// Runs on a background actor so the main thread stays free.
/// Streams progress so the UI can show a real-time scan indicator.
actor PhotoScanService {
    enum ScanState: Sendable {
        case idle
        case scanning(progress: Double, found: Int)
        case complete([GeoPhoto])
        case failed(Error)
    }

    private let cache = CacheService()

    /// Returns cached photos immediately if the library hasn't changed,
    /// otherwise performs a full re-scan.
    func scanIfNeeded() async throws -> [GeoPhoto] {
        let currentToken = await fetchChangeTokenString()

        if let meta = try? await cache.loadMeta(),
           meta.changeToken == currentToken,
           let cached = try? await cache.loadPhotos(),
           !cached.isEmpty {
            return cached
        }

        return try await fullScan(changeToken: currentToken)
    }

    // MARK: - Full Scan

    func fullScan(changeToken: String?, progressHandler: (@Sendable (Double, Int) -> Void)? = nil) async throws -> [GeoPhoto] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: fetchOptions)
        let total = assets.count

        guard total > 0 else { return [] }

        var photos: [GeoPhoto] = []
        photos.reserveCapacity(total / 4)  // assume ~25% are geotagged

        // Process in batches to bound memory usage
        let batchSize = 200
        var processed = 0

        while processed < total {
            let end = min(processed + batchSize, total)

            let batch = await withCheckedContinuation { continuation in
                var batchPhotos: [GeoPhoto] = []
                assets.enumerateObjects(at: IndexSet(integersIn: processed..<end)) { asset, _, _ in
                    guard let location = asset.location,
                          let date = asset.creationDate else { return }
                    let photo = GeoPhoto(
                        id: asset.localIdentifier,
                        coordinate: .init(latitude: location.coordinate.latitude,
                                          longitude: location.coordinate.longitude),
                        date: date
                    )
                    batchPhotos.append(photo)
                }
                continuation.resume(returning: batchPhotos)
            }

            photos.append(contentsOf: batch)
            processed = end
            progressHandler?(Double(processed) / Double(total), photos.count)

            // Yield to avoid blocking the actor for too long
            await Task.yield()
        }

        // Persist the raw GPS data immediately so partial geocoding isn't lost
        try? await cache.savePhotos(photos)
        let meta = CacheService.Meta(
            changeToken: changeToken,
            lastScanDate: Date(),
            totalAssetCount: total
        )
        try? await cache.saveMeta(meta)

        return photos
    }

    // MARK: - Helpers

    private func fetchChangeTokenString() async -> String? {
        PHPhotoLibrary.shared().currentChangeToken.description
    }
}
