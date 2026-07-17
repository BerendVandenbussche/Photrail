import Foundation

/// A travel style a photo can contribute to. Raw values are stable identifiers
/// used for Codable caching — don't rename without a cache migration.
enum TravelCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case urban
    case coastal
    case mountain
    case nature
    case culture
    case transit
    case adventure

    var id: String { rawValue }

    /// User-facing explanation of what this score is based on.
    var basis: String {
        switch self {
        case .urban:     return String(localized: "Photos taken in towns and cities — close to a populated place.")
        case .coastal:   return String(localized: "Photos taken near a coastline (within ~50 km of the sea).")
        case .mountain:  return String(localized: "Photos taken at high altitude or right by a famous mountain.")
        case .nature:    return String(localized: "Photos taken far from any city — countryside, parks and wild places.")
        case .culture:   return String(localized: "Photos taken at famous landmarks, monuments and cultural sites.")
        case .transit:   return String(localized: "Days you covered large distances — flights and long journeys between places.")
        case .adventure: return String(localized: "Remote spots, long distances and rugged landscapes, combined.")
        }
    }

    var title: String {
        switch self {
        case .urban:     return String(localized: "Urban Explorer")
        case .coastal:   return String(localized: "Coastal Traveler")
        case .mountain:  return String(localized: "Mountain Seeker")
        case .nature:    return String(localized: "Nature Lover")
        case .culture:   return String(localized: "Cultural Explorer")
        case .transit:   return String(localized: "Transit Traveler")
        case .adventure: return String(localized: "Adventurer")
        }
    }

    /// Always-English title — used on shareable cards, which stay English by design.
    var englishTitle: String {
        switch self {
        case .urban:     return "Urban Explorer"
        case .coastal:   return "Coastal Traveler"
        case .mountain:  return "Mountain Seeker"
        case .nature:    return "Nature Lover"
        case .culture:   return "Cultural Explorer"
        case .transit:   return "Transit Traveler"
        case .adventure: return "Adventurer"
        }
    }

    var emoji: String {
        switch self {
        case .urban:     return "🏙"
        case .coastal:   return "🌊"
        case .mountain:  return "🏔"
        case .nature:    return "🌳"
        case .culture:   return "🏛"
        case .transit:   return "✈️"
        case .adventure: return "🧭"
        }
    }
}
