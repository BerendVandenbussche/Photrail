import Foundation

/// Computes distance from a coordinate to the nearest coastline, fully on-device,
/// using a bundled GeoJSON of coastline geometry (Natural Earth `coastline.geojson`).
///
/// Segments are indexed into a 1° grid so each query only tests nearby segments.
/// Returns nil when no dataset is bundled (caller then skips distance-based scoring).
actor OfflineCoastline {

    private struct Segment {
        let lat1, lon1, lat2, lon2: Double
    }

    private var segments: [Segment] = []
    private var grid: [Int: [Int]] = [:]   // gridKey → segment indices
    private var loaded = false

    /// Distance (km) to the nearest coast, or nil if no coastline dataset is available.
    func distanceKm(latitude: Double, longitude: Double) -> Double? {
        loadIfNeeded()
        guard !segments.isEmpty else { return nil }

        let cellLat = Int(floor(latitude))
        let cellLon = Int(floor(longitude))
        var candidates = Set<Int>()
        for dLat in -1...1 {
            for dLon in -1...1 {
                if let ids = grid[Self.key(cellLat + dLat, cellLon + dLon)] {
                    candidates.formUnion(ids)
                }
            }
        }

        let cosLat = cos(latitude * .pi / 180)
        var best = Double.greatestFiniteMagnitude
        for index in candidates {
            best = min(best, distance(toSegment: segments[index],
                                      qlat: latitude, qlon: longitude, cosLat: cosLat))
        }
        return best
    }

    func distancesKm(_ points: [(id: String, latitude: Double, longitude: Double)]) -> [String: Double] {
        loadIfNeeded()
        guard !segments.isEmpty else { return [:] }
        var result: [String: Double] = [:]
        result.reserveCapacity(points.count)
        for p in points {
            if let d = distanceKm(latitude: p.latitude, longitude: p.longitude) {
                result[p.id] = d
            }
        }
        return result
    }

    // MARK: - Geometry

    /// Planar (equirectangular) distance in km from the query point to a segment.
    /// Accurate enough at the < ~100 km scale we care about.
    private func distance(toSegment seg: Segment, qlat: Double, qlon: Double, cosLat: Double) -> Double {
        func project(_ lat: Double, _ lon: Double) -> (Double, Double) {
            ((lon - qlon) * 111.32 * cosLat, (lat - qlat) * 110.57)
        }
        let (ax, ay) = project(seg.lat1, seg.lon1)
        let (bx, by) = project(seg.lat2, seg.lon2)
        let dx = bx - ax, dy = by - ay
        let len2 = dx * dx + dy * dy
        var t = len2 > 0 ? -(ax * dx + ay * dy) / len2 : 0
        t = max(0, min(1, t))
        let cx = ax + t * dx, cy = ay + t * dy
        return (cx * cx + cy * cy).squareRoot()
    }

    private static func key(_ lat: Int, _ lon: Int) -> Int {
        (lat + 90) * 1000 + (lon + 180)
    }

    // MARK: - Loading

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "coastline", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            return
        }

        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { continue }
            if type == "LineString", let coords = geometry["coordinates"] as? [[Double]] {
                addLine(coords)
            } else if type == "MultiLineString", let lines = geometry["coordinates"] as? [[[Double]]] {
                for line in lines { addLine(line) }
            }
        }
    }

    private func addLine(_ coords: [[Double]]) {
        guard coords.count >= 2 else { return }
        for i in 0..<(coords.count - 1) {
            let a = coords[i], b = coords[i + 1]
            guard a.count >= 2, b.count >= 2 else { continue }
            let seg = Segment(lat1: a[1], lon1: a[0], lat2: b[1], lon2: b[0])
            let index = segments.count
            segments.append(seg)

            // Index into every 1° cell the segment's bounding box touches.
            let minLat = Int(floor(min(seg.lat1, seg.lat2)))
            let maxLat = Int(floor(max(seg.lat1, seg.lat2)))
            let minLon = Int(floor(min(seg.lon1, seg.lon2)))
            let maxLon = Int(floor(max(seg.lon1, seg.lon2)))
            for lat in minLat...maxLat {
                for lon in minLon...maxLon {
                    grid[Self.key(lat, lon), default: []].append(index)
                }
            }
        }
    }
}
