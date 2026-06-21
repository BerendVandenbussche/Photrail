import Foundation

/// Everything the renderer needs to draw a single share card, decoupled from the
/// SwiftUI view. Built from existing app data via `ShareCardModel.make`.
struct ShareCardModel: Sendable {
    let type: ShareCardType

    /// Big, glanceable headline (may contain a line break).
    let headline: String
    /// Optional one-line context under the headline.
    let subheadline: String?

    /// Up to three supporting metrics.
    let supporting: [Stat]
    /// Personality breakdown (personality card).
    let slices: [TravelPersonalityProfile.Slice]
    /// Wonder badges (wonders card).
    let wonders: [WonderBadge]
    let wondersSeen: Int
    let wondersTotal: Int
    /// Trip details (trip card).
    let trip: TripCard?
    /// Country coordinates for the subtle map constellation.
    let pins: [Coordinate]

    struct Stat: Identifiable, Sendable {
        let id = UUID()
        let value: String
        let label: String
    }

    struct WonderBadge: Identifiable, Sendable {
        let id = UUID()
        let emoji: String
        let name: String
        let seen: Bool
    }

    struct TripCard: Sendable {
        let title: String
        let dateRange: String
        let photoCount: Int
        let cities: [String]
    }

    struct Coordinate: Sendable {
        let latitude: Double
        let longitude: Double
    }

    /// Brand tagline shown on every card.
    static let tagline = "Your travel history, automatically"

    /// True when there isn't enough data to make a meaningful card.
    var isEmpty: Bool {
        switch type {
        case .summary:     return supporting.isEmpty && headline.isEmpty
        case .personality: return slices.isEmpty
        case .wonders:     return wonders.isEmpty
        case .trip:        return trip == nil
        }
    }
}

extension ShareCardModel {

    /// Build a card model from the app's computed data. Returns a best-effort model;
    /// callers should only offer card types they have data for.
    static func make(type: ShareCardType,
                     stats: TravelStats,
                     profile: TravelPersonalityProfile?,
                     trip: Trip?) -> ShareCardModel {
        let pins = stats.countries
            .map { Coordinate(latitude: $0.representativeCoordinate.latitude,
                              longitude: $0.representativeCoordinate.longitude) }
            .filter { $0.latitude != 0 || $0.longitude != 0 }

        switch type {
        case .summary:
            return ShareCardModel(
                type: .summary,
                headline: "\(stats.countryCount)\nCountries",
                subheadline: nil,
                supporting: [
                    Stat(value: "\(stats.cityCount)", label: "Cities"),
                    Stat(value: "\(stats.visitedContinentCount)", label: "Continents"),
                    Stat(value: "\(stats.wondersSeenCount)", label: "Wonders")
                ],
                slices: [], wonders: [], wondersSeen: 0, wondersTotal: 0, trip: nil, pins: pins
            )

        case .personality:
            let visible = (profile?.visibleSlices ?? []).prefix(4)
            let dominant = profile?.dominantCategory
            let dominantPct = dominant.flatMap { profile?.categoryPercentages[$0] }.map { Int($0.rounded()) }
            let headline: String
            if let dominant, let dominantPct {
                headline = "\(dominantPct)%\n\(dominant.title)"
            } else {
                headline = ""
            }
            return ShareCardModel(
                type: .personality,
                headline: headline,
                subheadline: "My travel personality",
                supporting: [],
                slices: Array(visible),
                wonders: [], wondersSeen: 0, wondersTotal: 0, trip: nil, pins: pins
            )

        case .wonders:
            let seven = stats.wonders.filter { $0.wonder.category == .sevenWonders }
            let seenCount = seven.filter { $0.seen }.count
            let badges = seven
                .sorted { ($0.seen ? 0 : 1, $0.wonder.name) < ($1.seen ? 0 : 1, $1.wonder.name) }
                .map { WonderBadge(emoji: $0.wonder.emoji, name: $0.wonder.name, seen: $0.seen) }
            return ShareCardModel(
                type: .wonders,
                headline: "\(seenCount) / 7\nWorld Wonders",
                subheadline: nil,
                supporting: [],
                slices: [],
                wonders: badges,
                wondersSeen: seenCount,
                wondersTotal: 7,
                trip: nil, pins: pins
            )

        case .trip:
            let card = trip.map {
                TripCard(title: "\($0.flag) \($0.country)",
                         dateRange: $0.dateRangeText,
                         photoCount: $0.photoCount,
                         cities: $0.cities)
            }
            return ShareCardModel(
                type: .trip,
                headline: trip.map { "\($0.country)\nTrip" } ?? "",
                subheadline: nil,
                supporting: [], slices: [], wonders: [], wondersSeen: 0, wondersTotal: 0,
                trip: card,
                pins: trip.map { [Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)] } ?? []
            )
        }
    }
}
