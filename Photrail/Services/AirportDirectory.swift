import Foundation
import CoreLocation

/// Every airport with scheduled flights, bundled offline (`airports.tsv`, from the public-domain
/// OurAirports data set). Used by the trip planner to draw flight routes without any network
/// request. Separate from `AirportCatalog`, whose short hub list drives trip detection and is
/// deliberately left alone.
enum AirportDirectory {

    struct Airport: Identifiable, Hashable, Sendable {
        enum Size: Int, Sendable { case large = 0, medium = 1, small = 2 }

        let iata: String
        let name: String
        let city: String
        let countryCode: String
        let latitude: Double
        let longitude: Double
        let size: Size

        var id: String { iata }
        var flag: String { CountryCatalog.flag(for: countryCode) }
        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        /// The city when known, else the airport name: "Tokyo", "Brussels".
        var placeName: String { city.isEmpty ? name : city }
    }

    /// Loaded on first use, about 4,000 rows.
    static let all: [Airport] = load()
    private static let byCode: [String: Airport] = Dictionary(all.map { ($0.iata, $0) },
                                                              uniquingKeysWith: { a, _ in a })

    static func airport(_ iata: String) -> Airport? { byCode[iata.uppercased()] }

    /// Airports for a search box: an exact code first, then city and name matches, bigger
    /// airports before smaller ones. Matching ignores case and accents ("zurich" finds Zürich).
    static func search(_ query: String, limit: Int = 60) -> [Airport] {
        let q = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !q.isEmpty else { return all.filter { $0.size == .large }.prefix(limit).map { $0 } }

        func rank(_ a: Airport) -> Int? {
            if a.iata.lowercased() == q { return 0 }
            let city = fold(a.city), name = fold(a.name)
            if city.hasPrefix(q) { return 1 }
            if name.hasPrefix(q) || name.contains(" " + q) { return 2 }
            if city.contains(q) || name.contains(q) || fold(CountryCatalog.name(for: a.countryCode)).hasPrefix(q) {
                return 3
            }
            return nil
        }
        return all
            .compactMap { a in rank(a).map { (a, $0) } }
            .sorted { ($0.1, $0.0.size.rawValue, $0.0.city) < ($1.1, $1.0.size.rawValue, $1.0.city) }
            .prefix(limit)
            .map(\.0)
    }

    /// The nearest large or medium airport within `maxKm`, e.g. to suggest where a trip departs
    /// from based on the user's home.
    static func nearest(to coordinate: CLLocationCoordinate2D, maxKm: Double = 150) -> Airport? {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var best: Airport?
        var bestScore = Double.infinity
        for airport in all where airport.size != .small {
            let meters = CLLocation(latitude: airport.latitude, longitude: airport.longitude).distance(from: here)
            guard meters <= maxKm * 1000 else { continue }
            // Prefer a large airport unless a medium one is much (40 km+) closer.
            let score = meters + Double(airport.size.rawValue) * 40_000
            if score < bestScore { bestScore = score; best = airport }
        }
        return best
    }

    /// The airport a photo at `coordinate` was taken at: the closest one within 3 km (2 km for
    /// small airports, which often sit right next to town). Nil when there's none that close.
    static func airport(at coordinate: CLLocationCoordinate2D) -> Airport? {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var best: (airport: Airport, meters: Double)?
        let lat = Int(coordinate.latitude.rounded(.down)), lon = Int(coordinate.longitude.rounded(.down))
        for dLat in -1...1 {
            for dLon in -1...1 {
                for airport in grid[GridKey(lat: lat + dLat, lon: lon + dLon)] ?? [] {
                    let meters = CLLocation(latitude: airport.latitude, longitude: airport.longitude)
                        .distance(from: here)
                    let limit: Double = airport.size == .small ? 2_000 : 3_000
                    if meters <= limit, meters < (best?.meters ?? .infinity) { best = (airport, meters) }
                }
            }
        }
        return best?.airport
    }

    /// Large and medium airports within `maxKm`, nearest first.
    static func airports(near coordinate: CLLocationCoordinate2D, maxKm: Double = 150,
                         includeSmall: Bool = false) -> [Airport] {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return all
            .filter { includeSmall || $0.size != .small }
            .map { ($0, CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: here)) }
            .filter { $0.1 <= maxKm * 1000 }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }

    /// The large airport nearest `coordinate` (any distance up to `maxKm`), for guessing where
    /// a trip landed when no photo was taken at the airport.
    static func nearestLarge(to coordinate: CLLocationCoordinate2D, maxKm: Double = 400) -> Airport? {
        airports(near: coordinate, maxKm: maxKm).first { $0.size == .large }
    }

    /// Airports per whole degree of latitude and longitude, so `airport(at:)` only measures
    /// the handful nearby instead of all 4,000.
    private struct GridKey: Hashable { let lat: Int; let lon: Int }
    private static let grid: [GridKey: [Airport]] = Dictionary(grouping: all) {
        GridKey(lat: Int($0.latitude.rounded(.down)), lon: Int($0.longitude.rounded(.down)))
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func load() -> [Airport] {
        guard let url = Bundle.main.url(forResource: "airports", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var result: [Airport] = []
        result.reserveCapacity(4_100)
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard f.count == 7, let lat = Double(f[4]), let lon = Double(f[5]) else { continue }
            let size: Airport.Size = f[6] == "L" ? .large : f[6] == "M" ? .medium : .small
            result.append(Airport(iata: String(f[0]), name: String(f[1]), city: String(f[2]),
                                  countryCode: String(f[3]), latitude: lat, longitude: lon, size: size))
        }
        return result
    }
}
