import Foundation
import CoreLocation

/// Computes a travel personality profile from photo locations — fully on-device.
///
/// Signals used (all available offline at compute time):
/// - `city` presence (from prior geocoding) → urban vs. nature
/// - proximity to a known wonder/landmark → culture / nature / coastal / mountain
/// - movement between consecutive photos → transit / adventure
/// - optional `altitude` → mountain (GeoPhoto carries none today; kept for future use)
/// - a lightweight coastal-leaning country list → mild coastal lean for rural photos
///
/// Scoring is pure and deterministic, so it is straightforward to unit test.
struct TravelPersonalityEngine: Sendable {

    // MARK: Tunable weights

    enum Weight {
        static let cityUrban = 0.8
        static let ruralNature = 0.5
        static let wonderCulture = 1.0
        static let wonderNature = 0.8
        static let wonderCoastal = 1.0
        static let wonderMountain = 1.0
        static let altitudeHigh = 0.9     // > 1000m
        static let altitudeMedium = 0.5   // 500–1000m
        static let coastalNear = 1.0      // ≤ 10 km from coast
        static let coastalMedium = 0.5    // 10–50 km from coast
    }

    /// How a matched wonder contributes to personality.
    enum WonderKind { case cultural, natural, coastal, mountain }

    let aggregator: TravelPersonalityAggregator

    init(aggregator: TravelPersonalityAggregator = TravelPersonalityAggregator()) {
        self.aggregator = aggregator
    }

    // MARK: - Public API

    /// - Parameters:
    ///   - photos: geocoded photos with coordinates (order-independent; sorted internally)
    ///   - wonderIDByPhoto: photoID → matched wonder id (from `WonderDetector`)
    ///   - trips: trips used for per-trip aggregation
    ///   - home: home coordinate; photos within `homeRadiusKm` are excluded so everyday
    ///           local photos don't dominate the profile (the personality is about travel)
    ///   - homeRadiusKm: exclusion radius around home (default 50 km)
    func makeProfile(photos: [GeoPhoto],
                     wonderIDByPhoto: [String: String] = [:],
                     coastalDistanceByPhoto: [String: Double] = [:],
                     cityDistanceByPhoto: [String: Double] = [:],
                     trips: [Trip] = [],
                     home: GeoPhoto.Coordinate? = nil,
                     homeRadiusKm: Double = 50) -> TravelPersonalityProfile {
        var valid = photos
            .filter { $0.coordinate.latitude != 0 || $0.coordinate.longitude != 0 }
            .sorted { $0.date < $1.date }
        guard !valid.isEmpty else { return .empty }

        // Drop photos near home so daily life doesn't skew the profile. If that would
        // remove everything (e.g. you only have local photos), keep them all.
        if let home {
            let homeLocation = CLLocation(latitude: home.latitude, longitude: home.longitude)
            let away = valid.filter {
                let loc = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                return homeLocation.distance(from: loc) / 1000 > homeRadiusKm
            }
            if !away.isEmpty { valid = away }
        }

        var scored: [TravelPersonalityAggregator.ScoredPhoto] = []
        scored.reserveCapacity(valid.count)

        for (index, photo) in valid.enumerated() {
            let prev = index > 0 ? valid[index - 1] : nil
            let next = index < valid.count - 1 ? valid[index + 1] : nil
            let kind = wonderIDByPhoto[photo.id].flatMap(Self.wonderKind(forID:))
            let scores = score(photo: photo, previous: prev, next: next, wonderKind: kind,
                               coastalDistanceKm: coastalDistanceByPhoto[photo.id],
                               cityDistanceKm: cityDistanceByPhoto[photo.id],
                               altitude: photo.altitude)
            scored.append(.init(id: photo.id, scores: scores))
        }

        return aggregator.aggregate(scored, trips: trips, photoCount: valid.count)
    }

    // MARK: - Per-photo scoring (pure / testable)

    func score(photo: GeoPhoto,
               previous: GeoPhoto?,
               next: GeoPhoto?,
               wonderKind: WonderKind?,
               coastalDistanceKm: Double? = nil,
               cityDistanceKm: Double? = nil,
               altitude: Double? = nil) -> TravelCategoryScores {
        var s = TravelCategoryScores()

        // Urban vs. nature. The strongest signal is remoteness — distance to the nearest
        // populated place. Falls back to whether a real locality was resolved, then to the
        // raw city string (which over-counts urban) before any geocoding has run.
        let isUrban: Bool
        if let d = cityDistanceKm {
            isUrban = d <= 8
        } else if let hasLocality = photo.hasLocality {
            isUrban = hasLocality
        } else {
            isUrban = !(photo.city ?? "").isEmpty
        }

        // Wonder / landmark proximity
        switch wonderKind {
        case .cultural: s.add(.culture, Weight.wonderCulture)
        case .natural:  s.add(.nature, Weight.wonderNature); s.add(.adventure, 0.3)
        case .coastal:  s.add(.coastal, Weight.wonderCoastal)
        case .mountain: s.add(.mountain, Weight.wonderMountain); s.add(.adventure, 0.5)
        case .none:     break
        }

        // Urban vs. nature, graded by remoteness when available.
        if let d = cityDistanceKm {
            if d <= 8 {
                s.add(.urban, Weight.cityUrban)
            } else if d <= 30 {
                s.add(.urban, 0.3)
                s.add(.nature, 0.4)
            } else {
                s.add(.nature, 0.9)        // genuinely remote — countryside / parks / wilderness
                s.add(.adventure, 0.2)
            }
        } else if isUrban {
            s.add(.urban, Weight.cityUrban)
        } else {
            s.add(.nature, Weight.ruralNature)
        }

        // Coastal — distance to the nearest coastline (offline dataset)
        if let coast = coastalDistanceKm {
            if coast <= 10 { s.add(.coastal, Weight.coastalNear) }
            else if coast <= 50 { s.add(.coastal, Weight.coastalMedium) }
        }

        // Altitude (optional; future-proof)
        if let altitude {
            if altitude > 1000 { s.add(.mountain, Weight.altitudeHigh); s.add(.adventure, 0.4) }
            else if altitude > 500 { s.add(.mountain, Weight.altitudeMedium) }
        }

        // Movement between consecutive photos → transit / adventure
        if let move = maxNeighborDistanceKm(photo: photo, previous: previous, next: next) {
            if move > 500 {
                s.add(.transit, 0.8)
            } else if move > 150 {
                s.add(.transit, 0.3)
                s.add(.adventure, 0.2)
            }
            if move > 300 && !isUrban { s.add(.adventure, 0.3) }  // remote + on the move
        }

        // Guarantee a non-empty vector so the photo contributes something
        if s.total == 0 { s.add(.nature, 0.3) }
        return s
    }

    // MARK: - Helpers

    /// Largest distance (km) to a temporally-close neighbour (within 24h), or nil.
    private func maxNeighborDistanceKm(photo: GeoPhoto, previous: GeoPhoto?, next: GeoPhoto?) -> Double? {
        let here = CLLocation(latitude: photo.coordinate.latitude, longitude: photo.coordinate.longitude)
        var best: Double?
        for neighbor in [previous, next].compactMap({ $0 }) {
            guard abs(neighbor.date.timeIntervalSince(photo.date)) <= 86_400 else { continue }
            let there = CLLocation(latitude: neighbor.coordinate.latitude, longitude: neighbor.coordinate.longitude)
            let km = here.distance(from: there) / 1000
            best = max(best ?? 0, km)
        }
        return best
    }

    /// Personality classification for known wonders/landmarks (defaults to cultural).
    static func wonderKind(forID id: String) -> WonderKind {
        if mountainWonders.contains(id) { return .mountain }
        if coastalWonders.contains(id) { return .coastal }
        if naturalWonders.contains(id) { return .natural }
        return .cultural
    }

    private static let mountainWonders: Set<String> = ["machu-picchu", "mount-fuji"]
    private static let coastalWonders: Set<String> = ["santorini", "sydney-opera", "statue-liberty", "golden-gate", "moai"]
    private static let naturalWonders: Set<String> = ["grand-canyon", "niagara-falls"]
}
