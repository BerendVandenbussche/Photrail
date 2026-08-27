import Foundation
import CoreLocation

/// Assembles the pool of places the app is willing to suggest, and gives each one a style
/// vector in the same seven categories the user's own personality is measured in.
///
/// The vectors are built with the same rules as `TravelPersonalityEngine.score` — coastal by
/// distance to the sea, urban vs. wild by distance to the nearest town, culture from wonder
/// proximity — because a match only means something if both sides were measured the same way.
/// The terms that need a photo (EXIF altitude, movement between shots) simply have no
/// counterpart here; see `DestinationTraits` for the one gap that had to be filled by hand.
struct DestinationCandidateBuilder: Sendable {
    let coastline: OfflineCoastline
    let places: OfflinePlaces
    let geocoder: OfflineCountryGeocoder

    /// A candidate together with the style vector it will be matched on.
    struct Scored: Sendable {
        let candidate: DestinationCandidate
        let vector: TravelCategoryScores
    }

    /// Everywhere worth offering, given where the user has already been.
    ///
    /// - Parameters:
    ///   - visitedCountryCodes: countries with photos — excluded wholesale, including their wonders
    ///   - seenWonderIDs: wonders already photographed
    ///   - homeCountryCode: never suggested; "go home" is not a suggestion
    func build(visitedCountryCodes: Set<String>,
               seenWonderIDs: Set<String>,
               homeCountryCode: String?) async -> [Scored] {
        let visited = Set(visitedCountryCodes.map { $0.uppercased() })
        let excludedCountries = visited.union([homeCountryCode?.uppercased()].compactMap { $0 })

        // Wonders: unseen, and not in a country the user has already covered — standing in
        // Rome and being told to visit the Colosseum is not a discovery.
        let wonders = WonderCatalog.all.filter {
            !seenWonderIDs.contains($0.id) && $0.countryCodes.allSatisfy { !excludedCountries.contains($0) }
        }

        let countryCodes = ContinentMapper.allCodes
            .map { $0.uppercased() }
            .filter { !excludedCountries.contains($0) }

        let centroids = await geocoder.representativeCoordinates(for: countryCodes)
        let notable = await places.notablePlaces(inCountries: Array(centroids.keys), limit: 3)

        // Every point that needs measuring, gathered so the two offline datasets are each
        // walked exactly once for the whole pool rather than once per candidate.
        var points: [(id: String, latitude: Double, longitude: Double)] = []
        for wonder in wonders {
            points.append(("w:\(wonder.id)", wonder.latitude, wonder.longitude))
        }
        for (code, centroid) in centroids {
            points.append(("c:\(code)", centroid.latitude, centroid.longitude))
            for (index, place) in (notable[code] ?? []).enumerated() {
                points.append(("c:\(code)#\(index)", place.latitude, place.longitude))
            }
        }
        let coastByPoint = await coastline.distancesKm(points)
        let cityByPoint = await places.distancesKm(points)

        // Which wonders sit in which country, so an unvisited country inherits the pull of the
        // landmarks it holds. Uses the whole catalog, not just unseen ones — a country's
        // character doesn't depend on what this particular user has photographed.
        var wondersByCountry: [String: [Wonder]] = [:]
        for wonder in WonderCatalog.all {
            for code in wonder.countryCodes { wondersByCountry[code, default: []].append(wonder) }
        }

        var result: [Scored] = []
        result.reserveCapacity(wonders.count + centroids.count)

        for wonder in wonders {
            let key = "w:\(wonder.id)"
            var vector = Self.siteVector(wonderKind: TravelPersonalityEngine.wonderKind(forID: wonder.id),
                                         coastalDistanceKm: coastByPoint[key],
                                         cityDistanceKm: cityByPoint[key])
            if DestinationTraits.mountainous.contains(wonder.countryCode) {
                vector.add(.mountain, DestinationTraits.mountainWeight * 0.5)
            }
            let candidate = DestinationCandidate(
                kind: .wonder(id: wonder.id),
                name: wonder.name,
                countryCode: wonder.countryCode,
                emoji: wonder.emoji,
                latitude: wonder.latitude,
                longitude: wonder.longitude,
                highlights: [CountryCatalog.name(for: wonder.countryCode)])
            result.append(Scored(candidate: candidate, vector: vector.normalized()))
        }

        for (code, centroid) in centroids {
            let countryPlaces = notable[code] ?? []
            var vector = TravelCategoryScores()

            // The centroid stands for the country's land, the notable places for where its
            // people are. Sampling only the cities would make every country look urban —
            // Namibia's three biggest towns say nothing about the Namib.
            let samples: [(key: String, weight: Double)] =
                [("c:\(code)", 1.5)]
                + countryPlaces.indices.map { ("c:\(code)#\($0)", 1.0) }
            for sample in samples {
                let point = Self.siteVector(wonderKind: nil,
                                            coastalDistanceKm: coastByPoint[sample.key],
                                            cityDistanceKm: cityByPoint[sample.key])
                vector = vector + point.normalized(to: sample.weight)
            }

            // Landmarks the country holds — the culture / nature / coastal pull of being there.
            for wonder in wondersByCountry[code] ?? [] {
                switch TravelPersonalityEngine.wonderKind(forID: wonder.id) {
                case .cultural: vector.add(.culture, 0.8)
                case .natural:  vector.add(.nature, 0.6); vector.add(.adventure, 0.2)
                case .coastal:  vector.add(.coastal, 0.7)
                case .mountain: vector.add(.mountain, 0.8); vector.add(.adventure, 0.3)
                }
            }

            if DestinationTraits.mountainous.contains(code) {
                vector.add(.mountain, DestinationTraits.mountainWeight)
                vector.add(.adventure, DestinationTraits.mountainWeight * 0.4)
            }

            // A country with a megacity in it really is a more urban proposition than one whose
            // largest place is a market town.
            if let biggest = countryPlaces.map(\.population).max() {
                if biggest >= 5_000_000 { vector.add(.urban, 0.6) }
                else if biggest >= 1_000_000 { vector.add(.urban, 0.3) }
            }

            guard vector.total > 0 else { continue }
            let candidate = DestinationCandidate(
                kind: .country(code: code),
                name: CountryCatalog.name(for: code),
                countryCode: code,
                emoji: CountryCatalog.flag(for: code),
                latitude: centroid.latitude,
                longitude: centroid.longitude,
                highlights: countryPlaces.map(\.name))
            result.append(Scored(candidate: candidate, vector: vector.normalized()))
        }

        return result
    }

    /// The style of a single point on the map, using `TravelPersonalityEngine`'s weights for
    /// the signals a candidate can actually have. Altitude and movement are photo-only and are
    /// simply absent rather than guessed at.
    static func siteVector(wonderKind: TravelPersonalityEngine.WonderKind?,
                           coastalDistanceKm: Double?,
                           cityDistanceKm: Double?) -> TravelCategoryScores {
        var s = TravelCategoryScores()

        switch wonderKind {
        case .cultural: s.add(.culture, TravelPersonalityEngine.Weight.wonderCulture)
        case .natural:  s.add(.nature, TravelPersonalityEngine.Weight.wonderNature); s.add(.adventure, 0.3)
        case .coastal:  s.add(.coastal, TravelPersonalityEngine.Weight.wonderCoastal)
        case .mountain: s.add(.mountain, TravelPersonalityEngine.Weight.wonderMountain); s.add(.adventure, 0.5)
        case .none:     break
        }

        if let d = cityDistanceKm {
            if d <= 8 {
                s.add(.urban, TravelPersonalityEngine.Weight.cityUrban)
            } else if d <= 30 {
                s.add(.urban, 0.3)
                s.add(.nature, 0.4)
            } else {
                s.add(.nature, 0.9)
                s.add(.adventure, 0.2)
            }
        }

        if let coast = coastalDistanceKm {
            if coast <= 10 { s.add(.coastal, TravelPersonalityEngine.Weight.coastalNear) }
            else if coast <= 50 { s.add(.coastal, TravelPersonalityEngine.Weight.coastalMedium) }
        }

        if s.total == 0 { s.add(.nature, 0.3) }
        return s
    }
}
