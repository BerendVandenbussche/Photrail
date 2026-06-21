import Foundation
import Photos
import SwiftUI

@MainActor
@Observable
final class CountryDetailViewModel {
    let country: CountryStat
    var thumbnails: [String: UIImage] = [:]
    var isLoadingPhotos = false

    init(country: CountryStat) {
        self.country = country
    }

    func loadThumbnails(for ids: [String]) {
        isLoadingPhotos = true
        let imageManager = PHCachingImageManager()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        let targetSize = CGSize(width: 200, height: 200)

        // Pre-cache in one go
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
        imageManager.startCachingImages(for: assets, targetSize: targetSize,
                                        contentMode: .aspectFill, options: options)

        for asset in assets {
            imageManager.requestImage(for: asset, targetSize: targetSize,
                                      contentMode: .aspectFill, options: options) { [weak self] image, _ in
                if let image {
                    self?.thumbnails[asset.localIdentifier] = image
                }
            }
        }
        isLoadingPhotos = false
    }
}
