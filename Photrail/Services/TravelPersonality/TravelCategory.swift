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
        case .urban:     return "Photos taken in towns and cities — close to a populated place."
        case .coastal:   return "Photos taken near a coastline (within ~50 km of the sea)."
        case .mountain:  return "Photos taken at high altitude or right by a famous mountain."
        case .nature:    return "Photos taken far from any city — countryside, parks and wild places."
        case .culture:   return "Photos taken at famous landmarks, monuments and cultural sites."
        case .transit:   return "Days you covered large distances — flights and long journeys between places."
        case .adventure: return "Remote spots, long distances and rugged landscapes, combined."
        }
    }

    var title: String {
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
