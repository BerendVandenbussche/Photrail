import Foundation

/// Generates the hero "travel title" from the year's behaviour + dominant personality.
/// Big-picture breadth (continents/countries) wins over personality; personality is
/// the tiebreaker that gives the title its flavour.
enum TravelTitle {
    static func generate(profile: TravelPersonalityProfile?,
                         countries: Int,
                         continents: Int,
                         trips: Int) -> String {
        if continents >= 4 { return "Continental Hopper" }
        if countries >= 12 { return "Global Explorer" }

        if let dominant = profile?.dominantCategory {
            switch dominant {
            case .urban:     return "Urban Explorer"
            case .coastal:   return "Coastal Adventurer"
            case .mountain:  return "Mountain Seeker"
            case .nature:    return "Nature Lover"
            case .culture:   return "Culture Hunter"
            case .transit:   return "Globetrotter"
            case .adventure: return "Adventurer"
            }
        }

        if trips >= 4 && countries <= 2 { return "Weekend Wanderer" }
        return "Explorer"
    }
}
