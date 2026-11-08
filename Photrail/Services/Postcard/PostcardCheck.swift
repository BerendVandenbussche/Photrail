import Foundation
import Photos
import CoreLocation

/// "Did the user take photos away from home today?" — answered straight from PhotoKit, without
/// the scan or SwiftData, so it fits in a background refresh's ~30 seconds.
///
/// The daily postcard notification is only scheduled when this finds photos: iOS can't hold
/// back a local notification at the moment it fires, so deciding up front is the only way to
/// never send one for a day without photos.
enum PostcardCheck {
    struct Result: Equatable, Sendable {
        /// Photos with a location taken today, away from home.
        let count: Int
        /// Where the latest of them was taken.
        let latitude: Double?
        let longitude: Double?
    }

    /// - Parameters:
    ///   - home: the user's precise home, when set. Photos within `radiusKm` of it don't count.
    static func photosToday(home: CLLocation?, radiusKm: Double = 50,
                            now: Date = Date(), calendar: Calendar = .current) -> Result {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return Result(count: 0, latitude: nil, longitude: nil)
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND mediaType == %d",
                                        calendar.startOfDay(for: now) as NSDate,
                                        PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: options)

        var count = 0
        var latest: CLLocation?
        assets.enumerateObjects { asset, _, _ in
            guard let location = asset.location else { return }
            if let home, location.distance(from: home) <= radiusKm * 1000 { return }
            count += 1
            if latest == nil { latest = location }   // sorted newest first
        }
        return Result(count: count,
                      latitude: latest?.coordinate.latitude,
                      longitude: latest?.coordinate.longitude)
    }
}
