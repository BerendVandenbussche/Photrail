import Foundation
import Photos

/// Scans the photo library for geotagged assets.
/// Runs on a background actor so the main thread stays free.
/// Persistence is handled by `PhotoStore`; this service only extracts GPS metadata.
actor PhotoScanService {

    /// A stable, comparable representation of the library's current change token.
    /// Used to skip re-enumerating assets when the library hasn't changed.
    func currentChangeToken() -> String? {
        let token = PHPhotoLibrary.shared().currentChangeToken
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token,
                                                        requiringSecureCoding: true) {
            return data.base64EncodedString()
        }
        return token.description
    }

    /// Enumerate the photo library and return every geotagged image as a (un-geocoded) GeoPhoto.
    func fetchGeotaggedPhotos(progressHandler: (@Sendable (Double, Int) -> Void)? = nil) async throws -> [GeoPhoto] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: fetchOptions)
        let total = assets.count

        guard total > 0 else { return [] }

        var photos: [GeoPhoto] = []
        photos.reserveCapacity(total / 4)  // assume ~25% are geotagged

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

            await Task.yield()
        }

        return photos
    }
}
