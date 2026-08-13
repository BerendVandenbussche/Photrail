import Photos
import UIKit

/// Every photo the recap film needs, fetched and downsampled **once** before rendering starts.
///
/// This exists because the renderer re-draws the whole card ~600 times. Fetching from Photos
/// inside that loop would put an iCloud round-trip on every frame; handing the film a bag of
/// ready `UIImage`s keeps the per-frame cost to compositing.
///
/// Every field is optional and the film degrades scene by scene, which is the point: under
/// "Optimize iPhone Storage" most of a real library isn't on the device, and a scene that
/// quietly falls back to its vector design is fine where a black hole in the video is not.
struct RecapFilmAssets {
    var opener: UIImage?
    var numbers: UIImage?
    /// One per `recap.headlineTrips`, same order — an entry may be nil if that trip's cover
    /// isn't on the device.
    var trips: [UIImage?] = []
    var peak: UIImage?
    /// Curated best-of-the-year shots for the closing montage.
    var shots: [UIImage] = []

    static let empty = RecapFilmAssets()

    /// Full-bleed scenes are drawn at 1080×1920 (the export resolution), so anything larger
    /// is memory we'd carry for the whole render with nothing to show for it.
    private static let fullBleed = CGSize(width: 1080, height: 1920)
    /// Montage frames are on screen for under half a second apiece and never full quality.
    private static let montage = CGSize(width: 810, height: 1440)
    /// Six shots is already more than the montage can show legibly, and each one costs memory
    /// that has to stay resident until the last frame is encoded.
    private static let maxShots = 6

    @MainActor
    static func load(for recap: RecapModel) async -> RecapFilmAssets {
        let shotIDs = Array(recap.highlightPhotoIDs.prefix(maxShots))

        var assets = RecapFilmAssets()
        assets.opener = await image(recap.highlightPhotoIDs.first, size: fullBleed)
        assets.numbers = await image(recap.highlightPhotoIDs.dropFirst().first
                                     ?? recap.highlightPhotoIDs.first, size: fullBleed)
        assets.peak = await image(recap.highestPeakPhotoID, size: fullBleed)

        var trips: [UIImage?] = []
        for trip in recap.headlineTrips {
            trips.append(await image(trip.photoID, size: fullBleed))
        }
        assets.trips = trips

        var shots: [UIImage] = []
        for id in shotIDs {
            if let image = await image(id, size: montage) { shots.append(image) }
        }
        assets.shots = shots
        return assets
    }

    private static func image(_ id: String?, size: CGSize) async -> UIImage? {
        guard let id,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            // The film is a deliberate, progress-tracked export, so it's worth pulling an
            // iCloud original rather than shipping a blurry placeholder into a share.
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .exact
            PHImageManager.default().requestImage(
                for: asset, targetSize: size, contentMode: .aspectFill, options: options
            ) { image, _ in
                // `.highQualityFormat` calls the handler exactly once, so there's no degraded
                // placeholder to filter out — and filtering one would risk a continuation that
                // never resumes, hanging the export before it starts.
                continuation.resume(returning: image)
            }
        }
    }
}
