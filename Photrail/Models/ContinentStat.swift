import Foundation

enum Continent: String, CaseIterable, Sendable, Codable {
    case africa       = "Africa"
    case antarctica   = "Antarctica"
    case asia         = "Asia"
    case europe       = "Europe"
    case northAmerica = "North America"
    case oceania      = "Oceania"
    case southAmerica = "South America"

    var emoji: String {
        switch self {
        case .africa:       return "🌍"
        case .antarctica:   return "🧊"
        case .asia:         return "🌏"
        case .europe:       return "🏰"
        case .northAmerica: return "🗽"
        case .oceania:      return "🌊"
        case .southAmerica: return "🌿"
        }
    }

    /// Localized display name (rawValue stays English for logic/persistence).
    var displayName: String {
        switch self {
        case .africa:       return String(localized: "Africa")
        case .antarctica:   return String(localized: "Antarctica")
        case .asia:         return String(localized: "Asia")
        case .europe:       return String(localized: "Europe")
        case .northAmerica: return String(localized: "North America")
        case .oceania:      return String(localized: "Oceania")
        case .southAmerica: return String(localized: "South America")
        }
    }

    /// Continents that can realistically be "visited" (excludes Antarctica).
    static var visitable: [Continent] {
        allCases.filter { $0 != .antarctica }
    }
}

struct ContinentStat: Identifiable, Sendable {
    var id: String { continent.rawValue }
    var continent: Continent
    var countries: [CountryStat]
    var photoCount: Int
    var visited: Bool { !countries.isEmpty }

    var countryCount: Int { countries.count }
}
