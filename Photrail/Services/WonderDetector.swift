import Foundation
import CoreLocation

/// Decides which world wonders a user has photographed.
///
/// Currently purely location-based: a wonder counts as "seen" if any photo was
/// taken within its radius. The per-photo matching is isolated here so a future
/// image-recognition pass (e.g. Vision/CoreML to confirm the wonder is actually
/// in frame) can be added as a second filtering stage without touching callers.
struct WonderDetector: Sendable {

    func detect(photos: [GeoPhoto], wonders: [Wonder] = WonderCatalog.all) -> [WonderStat] {
        wonders.map { wonder in
            let center = CLLocation(latitude: wonder.latitude, longitude: wonder.longitude)

            // Cheap bounding-box prefilter to skip the (many) far-away photos before
            // computing precise distances. 1.3× padding keeps it safe near the edge.
            let latPad = (wonder.radiusMeters / 111_000.0) * 1.3
            let cosLat = max(0.01, cos(wonder.latitude * .pi / 180))
            let lonPad = (wonder.radiusMeters / (111_000.0 * cosLat)) * 1.3

            var matches: [(id: String, date: Date)] = []

            for photo in photos {
                let coord = photo.coordinate
                if abs(coord.latitude - wonder.latitude) > latPad { continue }
                if abs(coord.longitude - wonder.longitude) > lonPad { continue }

                let distance = center.distance(
                    from: CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                )
                guard distance <= wonder.radiusMeters else { continue }

                // --- Future hook: confirm the wonder is visible in the image here ---

                matches.append((photo.id, photo.date))
            }

            // Newest first, so the detail grid and thumbnail lead with recent photos.
            matches.sort { $0.date > $1.date }

            return WonderStat(
                wonder: wonder,
                photoCount: matches.count,
                firstSeen: matches.map(\.date).min(),
                lastSeen: matches.first?.date,
                representativePhotoID: matches.first?.id,
                photoIDs: matches.map(\.id)
            )
        }
    }
}
