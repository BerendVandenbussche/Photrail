import SwiftUI

/// The colours used to tell one country's territory from another — on the interactive map's
/// "visited areas" layer and on the shareable world poster. Shared so the two can't drift:
/// a country you see in teal on the map is teal on the poster too.
enum CountryPalette {

    /// Chosen to stay legible over both the map basemap (light and dark) and the poster's
    /// dark sky.
    static let colors: [Color] = [
        Color(red: 0.36, green: 0.42, blue: 0.98),   // indigo
        Color(red: 0.95, green: 0.45, blue: 0.35),   // coral
        Color(red: 0.20, green: 0.70, blue: 0.55),   // teal
        Color(red: 0.85, green: 0.55, blue: 0.15),   // amber
        Color(red: 0.70, green: 0.35, blue: 0.85),   // violet
        Color(red: 0.20, green: 0.60, blue: 0.85),   // sky
        Color(red: 0.90, green: 0.35, blue: 0.60)    // rose
    ]

    /// The colour for a country, keyed on its ISO code so it never changes between launches
    /// or between screens.
    static func color(for countryCode: String) -> Color {
        colors[index(for: countryCode)]
    }

    /// A stable index into `colors`. Uses an explicit hash because Swift's own `hashValue`
    /// is seeded per process — colours would change every time the app restarted.
    static func index(for countryCode: String) -> Int {
        guard !colors.isEmpty else { return 0 }
        var hash = 0
        for scalar in countryCode.uppercased().unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) % 100_003
        }
        return abs(hash) % colors.count
    }
}
