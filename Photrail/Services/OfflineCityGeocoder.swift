import Foundation

/// Resolves a coordinate to the nearest city, fully on-device, from a bundled dataset
/// of every populated place with a population of 1,000 or more (GeoNames `cities1000`,
/// CC BY 4.0). This replaces the old rate-limited `CLGeocoder` city pass — the bottleneck
/// on large libraries — with an instant nearest-neighbour lookup.
///
/// Cities are indexed into a 1° grid so each query only tests nearby points.
actor OfflineCityGeocoder {

    private struct City { let lat, lon: Double; let name: String }

    private var cities: [City] = []
    private var grid: [Int: [Int]] = [:]
    private var loaded = false

    /// A point is considered to be "in" a town when the nearest city is within this range;
    /// mirrors CLGeocoder's `locality` signal (real urban area vs. open countryside).
    private let localityThresholdKm = 30.0
    /// Beyond this, we don't attach a city name at all (deep countryside / ocean).
    private let maxNameKm = 75.0

    /// A `CityResult` for each input point, aligned to the input order. `city` is the
    /// nearest city's name (nil when nothing is close enough); `hasLocality` is true only
    /// when that city is close enough that the point is plausibly within it.
    func resolve(_ points: [(id: String, latitude: Double, longitude: Double)])
        -> [(id: String, city: String?, hasLocality: Bool)] {
        loadIfNeeded()
        return points.map { point in
            let match = nearest(latitude: point.latitude, longitude: point.longitude)
            guard let match, match.distanceKm <= maxNameKm else {
                return (point.id, nil, false)
            }
            return (point.id, match.name, match.distanceKm <= localityThresholdKm)
        }
    }

    private struct Match { let name: String; let distanceKm: Double }

    private func nearest(latitude: Double, longitude: Double) -> Match? {
        guard !cities.isEmpty else { return nil }

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
        guard !candidates.isEmpty else { return nil }

        let cosLat = cos(latitude * .pi / 180)
        var best: (index: Int, dist: Double)?
        for index in candidates {
            let c = cities[index]
            let dx = (c.lon - longitude) * 111.32 * cosLat
            let dy = (c.lat - latitude) * 110.57
            let d = (dx * dx + dy * dy).squareRoot()
            if best == nil || d < best!.dist { best = (index, d) }
        }
        guard let best else { return nil }
        return Match(name: cities[best.index].name, distanceKm: best.dist)
    }

    private static func key(_ lat: Int, _ lon: Int) -> Int { (lat + 90) * 1000 + (lon + 180) }

    /// Parses the bundled `cities1000.tsv` (columns: name, lat, lon, countryCode, population).
    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "cities1000", withExtension: "tsv"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        text.enumerateLines { line, _ in
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 3,
                  let lat = Double(cols[1]), let lon = Double(cols[2]) else { return }
            let city = City(lat: lat, lon: lon, name: String(cols[0]))
            let index = self.cities.count
            self.cities.append(city)
            self.grid[Self.key(Int(floor(lat)), Int(floor(lon))), default: []].append(index)
        }
    }
}
