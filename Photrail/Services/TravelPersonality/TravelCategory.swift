import Foundation

/// A travel style a photo can contribute to. Raw values are stable identifiers
/// used for Codable caching — don't rename without a cache migration.
enum TravelCategory: String, CaseIterable, Codable, Sendable {
    case urban
    case coastal
    case mountain
    case nature
    case culture
    case transit
    case adventure

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
