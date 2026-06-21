import Foundation

/// Resolves coordinates to ISO country codes entirely on-device, using a bundled
/// GeoJSON of country borders. No network, no rate limit, no third-party TOS.
///
/// Expects a `countries.geojson` resource (Natural Earth admin-0, with ISO_A2/ISO_A2_EH
/// and NAME properties). If the file is missing it returns nil for everything, and the
/// caller can fall back to online geocoding.
actor OfflineCountryGeocoder {

    struct Match: Sendable {
        let code: String
        let fallbackName: String
    }

    private struct CountryShape {
        let code: String
        let name: String
        let minLat, maxLat, minLon, maxLon: Double
        // multipolygon → polygons → rings → (lat, lon) points
        let polygons: [[[(Double, Double)]]]
    }

    private var shapes: [CountryShape] = []
    private var loaded = false

    /// Resolve a batch in a single actor hop (far cheaper than one call per photo).
    /// Returns `(photoID, Match?)` aligned to the input.
    func resolve(_ items: [(id: String, latitude: Double, longitude: Double)]) -> [(String, Match?)] {
        loadIfNeeded()
        return items.map { ($0.id, match(latitude: $0.latitude, longitude: $0.longitude)) }
    }

    func match(latitude: Double, longitude: Double) -> Match? {
        loadIfNeeded()
        for shape in shapes {
            if latitude < shape.minLat || latitude > shape.maxLat
                || longitude < shape.minLon || longitude > shape.maxLon { continue }
            for polygon in shape.polygons where Self.contains(polygon, lat: latitude, lon: longitude) {
                return Match(code: shape.code, fallbackName: shape.name)
            }
        }
        return nil
    }

    /// Even-odd ray casting across every ring of a polygon — this naturally excludes
    /// holes (e.g. Vatican inside Italy), since a point in a hole crosses two rings.
    private static func contains(_ rings: [[(Double, Double)]], lat: Double, lon: Double) -> Bool {
        var inside = false
        for ring in rings {
            var j = ring.count - 1
            for i in 0..<ring.count {
                let (yi, xi) = ring[i]
                let (yj, xj) = ring[j]
                if (yi > lat) != (yj > lat),
                   lon < (xj - xi) * (lat - yi) / (yj - yi) + xi {
                    inside.toggle()
                }
                j = i
            }
        }
        return inside
    }

    // MARK: - Loading

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "countries", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            return
        }

        for feature in features {
            guard let props = feature["properties"] as? [String: Any],
                  let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { continue }

            let rawCode = (props["ISO_A2_EH"] as? String)
                ?? (props["ISO_A2"] as? String)
                ?? (props["iso_a2"] as? String) ?? ""
            let code = rawCode.uppercased()
            guard code.count == 2, code != "-9" else { continue }
            let name = (props["NAME"] as? String) ?? (props["ADMIN"] as? String) ?? code

            var polygons: [[[(Double, Double)]]] = []
            if type == "Polygon", let coords = geometry["coordinates"] as? [[[Double]]] {
                polygons = [rings(from: coords)]
            } else if type == "MultiPolygon", let coords = geometry["coordinates"] as? [[[[Double]]]] {
                polygons = coords.map { rings(from: $0) }
            }
            guard !polygons.isEmpty else { continue }

            var minLat = Double.greatestFiniteMagnitude, maxLat = -Double.greatestFiniteMagnitude
            var minLon = Double.greatestFiniteMagnitude, maxLon = -Double.greatestFiniteMagnitude
            for polygon in polygons {
                for ring in polygon {
                    for (lat, lon) in ring {
                        minLat = min(minLat, lat); maxLat = max(maxLat, lat)
                        minLon = min(minLon, lon); maxLon = max(maxLon, lon)
                    }
                }
            }

            shapes.append(CountryShape(code: code, name: name,
                                       minLat: minLat, maxLat: maxLat,
                                       minLon: minLon, maxLon: maxLon,
                                       polygons: polygons))
        }
    }

    /// Convert GeoJSON rings ([lon, lat] pairs) to (lat, lon) tuples.
    private func rings(from coords: [[[Double]]]) -> [[(Double, Double)]] {
        coords.map { ring in
            ring.compactMap { point in
                point.count >= 2 ? (point[1], point[0]) : nil
            }
        }
    }
}
