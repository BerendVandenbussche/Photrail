import UIKit
import Photos
import MapKit

/// Everything a postcard card needs: the day, its best photos and a map of its route.
///
/// `@unchecked Sendable`: the images are immutable once loaded and only handed from the
/// loading task to the view.
struct PostcardContent: @unchecked Sendable {
    let postcard: DayPostcard
    /// Best first, at most three.
    let photos: [UIImage]
    /// The day's route, or nil without network/map tiles (the card then leaves it out).
    let map: MapShot?

    /// How big the map appears on the card.
    static let mapSize = CGSize(width: 150, height: 110)
    /// How big it's rendered: twice the size, then scaled down into `mapSize`. The Apple Maps
    /// attribution has a fixed size in points and must stay, but this way it takes half the
    /// room on a map this small. Same pixels in the end (2× the points at 1.5× scale).
    static let mapRenderSize = CGSize(width: mapSize.width * 2, height: mapSize.height * 2)
    static let mapRenderScale: CGFloat = 1.5

    /// Picks the day's best photos and renders the map. Safe to call from any context.
    static func load(for postcard: DayPostcard) async -> PostcardContent {
        let best = await PhotoCurator().bestPhotos(candidateIDs: postcard.photoIDs,
                                                   category: nil, limit: 3, minSpacing: 1800)
        var photos: [UIImage] = []
        for id in best {
            if let image = await image(id, size: CGSize(width: 1080, height: 1080)) { photos.append(image) }
        }

        var map: MapShot?
        if !postcard.route.isEmpty {
            let coordinates = postcard.route.map(\.coordinate)
            map = await MapShotLoader.shot(
                region: MapShotLoader.region(fitting: coordinates, padding: 0.4, minimumMeters: 3_000),
                size: mapRenderSize, markers: coordinates, scale: mapRenderScale)
        }
        return PostcardContent(postcard: postcard, photos: photos, map: map)
    }

    private static func image(_ id: String, size: CGSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true   // Optimised Storage: fetch the original
            options.resizeMode = .exact
            PHImageManager.default().requestImage(for: asset, targetSize: size,
                                                  contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
