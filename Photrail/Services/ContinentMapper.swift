import Foundation

/// Maps ISO 3166-1 alpha-2 country codes to continents.
enum ContinentMapper {
    static func continent(for countryCode: String) -> Continent? {
        map[countryCode.uppercased()]
    }

    /// Every ISO country code the app knows — the universe for manual country entry.
    static var allCodes: [String] { Array(map.keys) }

    /// Total number of countries the mapper knows for a continent — the denominator
    /// for "how much of this continent have I seen".
    static func totalCountries(in continent: Continent) -> Int {
        countsByContinent[continent] ?? 0
    }

    private static let countsByContinent: [Continent: Int] = {
        var counts: [Continent: Int] = [:]
        for continent in map.values { counts[continent, default: 0] += 1 }
        return counts
    }()

    private static let map: [String: Continent] = [
        // Africa
        "DZ": .africa, "AO": .africa, "BJ": .africa, "BW": .africa, "BF": .africa,
        "BI": .africa, "CM": .africa, "CV": .africa, "CF": .africa, "TD": .africa,
        "KM": .africa, "CG": .africa, "CD": .africa, "CI": .africa, "DJ": .africa,
        "EG": .africa, "GQ": .africa, "ER": .africa, "SZ": .africa, "ET": .africa,
        "GA": .africa, "GM": .africa, "GH": .africa, "GN": .africa, "GW": .africa,
        "KE": .africa, "LS": .africa, "LR": .africa, "LY": .africa, "MG": .africa,
        "MW": .africa, "ML": .africa, "MR": .africa, "MU": .africa, "MA": .africa,
        "MZ": .africa, "NA": .africa, "NE": .africa, "NG": .africa, "RW": .africa,
        "ST": .africa, "SN": .africa, "SC": .africa, "SL": .africa, "SO": .africa,
        "ZA": .africa, "SS": .africa, "SD": .africa, "TZ": .africa, "TG": .africa,
        "TN": .africa, "UG": .africa, "ZM": .africa, "ZW": .africa,

        // Antarctica
        "AQ": .antarctica,

        // Asia
        "AF": .asia, "AM": .asia, "AZ": .asia, "BH": .asia, "BD": .asia,
        "BT": .asia, "BN": .asia, "KH": .asia, "CN": .asia, "CY": .asia,
        "GE": .asia, "IN": .asia, "ID": .asia, "IR": .asia, "IQ": .asia,
        "IL": .asia, "JP": .asia, "JO": .asia, "KZ": .asia, "KW": .asia,
        "KG": .asia, "LA": .asia, "LB": .asia, "MY": .asia, "MV": .asia,
        "MN": .asia, "MM": .asia, "NP": .asia, "KP": .asia, "OM": .asia,
        "PK": .asia, "PS": .asia, "PH": .asia, "QA": .asia, "SA": .asia,
        "SG": .asia, "KR": .asia, "LK": .asia, "SY": .asia, "TW": .asia,
        "TJ": .asia, "TH": .asia, "TL": .asia, "TR": .asia, "TM": .asia,
        "AE": .asia, "UZ": .asia, "VN": .asia, "YE": .asia,

        // Europe
        "AL": .europe, "AD": .europe, "AT": .europe, "BY": .europe, "BE": .europe,
        "BA": .europe, "BG": .europe, "HR": .europe, "CZ": .europe, "DK": .europe,
        "EE": .europe, "FI": .europe, "FR": .europe, "DE": .europe, "GR": .europe,
        "HU": .europe, "IS": .europe, "IE": .europe, "IT": .europe, "XK": .europe,
        "LV": .europe, "LI": .europe, "LT": .europe, "LU": .europe, "MT": .europe,
        "MD": .europe, "MC": .europe, "ME": .europe, "NL": .europe, "MK": .europe,
        "NO": .europe, "PL": .europe, "PT": .europe, "RO": .europe, "RU": .europe,
        "SM": .europe, "RS": .europe, "SK": .europe, "SI": .europe, "ES": .europe,
        "SE": .europe, "CH": .europe, "UA": .europe, "GB": .europe, "VA": .europe,

        // North America
        "AG": .northAmerica, "BS": .northAmerica, "BB": .northAmerica, "BZ": .northAmerica,
        "CA": .northAmerica, "CR": .northAmerica, "CU": .northAmerica, "DM": .northAmerica,
        "DO": .northAmerica, "SV": .northAmerica, "GD": .northAmerica, "GT": .northAmerica,
        "HT": .northAmerica, "HN": .northAmerica, "JM": .northAmerica, "MX": .northAmerica,
        "NI": .northAmerica, "PA": .northAmerica, "KN": .northAmerica, "LC": .northAmerica,
        "VC": .northAmerica, "TT": .northAmerica, "US": .northAmerica,

        // Oceania
        "AU": .oceania, "FJ": .oceania, "KI": .oceania, "MH": .oceania, "FM": .oceania,
        "NR": .oceania, "NZ": .oceania, "PW": .oceania, "PG": .oceania, "WS": .oceania,
        "SB": .oceania, "TO": .oceania, "TV": .oceania, "VU": .oceania,

        // South America
        "AR": .southAmerica, "BO": .southAmerica, "BR": .southAmerica, "CL": .southAmerica,
        "CO": .southAmerica, "EC": .southAmerica, "GY": .southAmerica, "PY": .southAmerica,
        "PE": .southAmerica, "SR": .southAmerica, "UY": .southAmerica, "VE": .southAmerica,
    ]
}
