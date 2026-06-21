import Foundation

/// Computes distance from a coordinate to the nearest populated place (city/town),
/// fully on-device, from a bundled GeoJSON of populated places (Natural Earth
/// `places.geojson`). Used as a "remoteness" signal: far from any city → nature.
///
/// Points are indexed into a 1° grid so each query only tests nearby points.
/// Returns nil when no dataset is bundled (caller then skips remoteness scoring).
actor OfflinePlaces {

    private struct Place { let lat, lon: Double }

    private var places: [Place] = []
    private var grid: [Int: [Int]] = [:]
    private var loaded = false

    /// Distance (km) to the nearest populated place, or nil if no dataset is available.
    func distanceKm(latitude: Double, longitude: Double) -> Double? {
        loadIfNeeded()
        guard !places.isEmpty else { return nil }

        let cellLat = Int(floor(latitude))
        let cellLon = Int(floor(longitude))
        var candidates = Set<Int>()
        // Search outward until we find candidates (remote points may be a few cells away).
        var radius = 1
        while candidates.isEmpty && radius <= 4 {
            for dLat in -radius...radius {
                for dLon in -radius...radius {
                    if let ids = grid[Self.key(cellLat + dLat, cellLon + dLon)] {
                        candidates.formUnion(ids)
                    }
                }
            }
            radius += 1
        }
        guard !candidates.isEmpty else { return Double.greatestFiniteMagnitude }

        let cosLat = cos(latitude * .pi / 180)
        var best = Double.greatestFiniteMagnitude
        for index in candidates {
            let p = places[index]
            let dx = (p.lon - longitude) * 111.32 * cosLat
            let dy = (p.lat - latitude) * 110.57
            best = min(best, (dx * dx + dy * dy).squareRoot())
        }
        return best
    }

    func distancesKm(_ points: [(id: String, latitude: Double, longitude: Double)]) -> [String: Double] {
        loadIfNeeded()
        guard !places.isEmpty else { return [:] }
        var result: [String: Double] = [:]
        result.reserveCapacity(points.count)
        for p in points {
            if let d = distanceKm(latitude: p.latitude, longitude: p.longitude) {
                result[p.id] = d
            }
        }
        return result
    }

    private static func key(_ lat: Int, _ lon: Int) -> Int { (lat + 90) * 1000 + (lon + 180) }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "places", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            return
        }

        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  (geometry["type"] as? String) == "Point",
                  let coords = geometry["coordinates"] as? [Double], coords.count >= 2 else { continue }
            let place = Place(lat: coords[1], lon: coords[0])
            let index = places.count
            places.append(place)
            grid[Self.key(Int(floor(place.lat)), Int(floor(place.lon))), default: []].append(index)
        }
    }
}
