import Foundation

/// Computes distance from a coordinate to the nearest populated place (city/town),
/// fully on-device, from a bundled GeoJSON of populated places (Natural Earth
/// `places.geojson`). Used as a "remoteness" signal: far from any city → nature.
///
/// Points are indexed into a 1° grid so each query only tests nearby points.
/// Returns nil when no dataset is bundled (caller then skips remoteness scoring).
actor OfflinePlaces {

    /// One populated place from the Natural Earth dataset.
    ///
    /// Only `lat`/`lon` feed the remoteness grid; the rest exists so the same parse can answer
    /// "name me a few notable places in this country" for trip suggestions, rather than the app
    /// bundling and parsing a second copy of the file.
    private struct Place {
        let lat, lon: Double
        let name: String
        let countryCode: String
        let population: Int
        /// 1 when the place is its country's capital — the obvious first thing to name.
        let isCapital: Bool
    }

    /// A named place, for suggesting somewhere to go rather than measuring distance to it.
    struct NamedPlace: Sendable {
        let name: String
        let latitude, longitude: Double
        let population: Int
    }

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

    /// The most recognisable places in each of the given countries, best first — a capital
    /// ahead of a bigger non-capital, then by population. Keyed by ISO country code; countries
    /// the dataset has nothing for are simply absent.
    ///
    /// Batched because the caller asks about every unvisited country at once, and one actor
    /// hop for 150 countries is the difference between free and noticeable.
    func notablePlaces(inCountries codes: [String], limit: Int = 3) -> [String: [NamedPlace]] {
        loadIfNeeded()
        let wanted = Set(codes.map { $0.uppercased() })
        guard !wanted.isEmpty, !places.isEmpty else { return [:] }

        var byCountry: [String: [Place]] = [:]
        for place in places where wanted.contains(place.countryCode) && !place.name.isEmpty {
            byCountry[place.countryCode, default: []].append(place)
        }
        return byCountry.mapValues { candidates in
            candidates
                .sorted { ($0.isCapital ? 1 : 0, $0.population) > ($1.isCapital ? 1 : 0, $1.population) }
                .prefix(limit)
                .map { NamedPlace(name: $0.name, latitude: $0.lat, longitude: $0.lon,
                                  population: $0.population) }
        }
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
            let properties = feature["properties"] as? [String: Any] ?? [:]
            let place = Place(lat: coords[1], lon: coords[0],
                              name: (properties["name"] as? String) ?? "",
                              countryCode: ((properties["iso_a2"] as? String) ?? "").uppercased(),
                              population: (properties["pop_max"] as? NSNumber)?.intValue ?? 0,
                              isCapital: ((properties["adm0cap"] as? NSNumber)?.intValue ?? 0) == 1)
            let index = places.count
            places.append(place)
            grid[Self.key(Int(floor(place.lat)), Int(floor(place.lon))), default: []].append(index)
        }
    }
}
