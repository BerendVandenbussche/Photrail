import Foundation
import CoreGraphics

/// Loads the bundled Natural Earth `coastline.geojson` once and exposes it as polylines in
/// raw lon/lat space (stored as `CGPoint(x: lon, y: lat)`), so views can draw a world outline
/// under any equirectangular projection. Parsing happens off the main actor and the result is
/// cached for the process lifetime — the map-reveal screen is the only consumer today.
actor WorldOutline {
    static let shared = WorldOutline()

    private var cached: [[CGPoint]]?

    /// Coastline polylines. Empty if the dataset isn't bundled.
    func polylines() -> [[CGPoint]] {
        if let cached { return cached }
        let result = Self.load()
        cached = result
        return result
    }

    private static func load() -> [[CGPoint]] {
        guard let url = Bundle.main.url(forResource: "coastline", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            return []
        }

        var lines: [[CGPoint]] = []
        func add(_ coords: [[Double]]) {
            var line: [CGPoint] = []
            line.reserveCapacity(coords.count)
            for c in coords where c.count >= 2 {
                line.append(CGPoint(x: c[0], y: c[1]))   // x = lon, y = lat
            }
            if line.count >= 2 { lines.append(line) }
        }

        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { continue }
            if type == "LineString", let coords = geometry["coordinates"] as? [[Double]] {
                add(coords)
            } else if type == "MultiLineString", let multi = geometry["coordinates"] as? [[[Double]]] {
                for coords in multi { add(coords) }
            }
        }
        return lines
    }
}
