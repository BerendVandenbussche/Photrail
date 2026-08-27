import Foundation

/// Whether a site is one of the official New 7 Wonders of the World, or another
/// famous landmark / natural wonder.
enum WonderCategory: String, Sendable, CaseIterable {
    case sevenWonders = "World Wonders"
    case landmark = "Landmarks"
}

/// A famous landmark / world wonder, matched against photo coordinates.
struct Wonder: Identifiable, Sendable {
    let id: String
    let name: String
    let countryCode: String   // ISO 3166-1 alpha-2, the country the site is usually filed under
    let emoji: String         // representative icon
    let category: WonderCategory
    let latitude: Double
    let longitude: Double
    /// Match radius in meters. Larger for sprawling sites (Great Wall, Grand Canyon).
    let radiusMeters: Double
    /// Other countries the site also sits in. A border can run straight through a wonder —
    /// Niagara Falls is in both the United States and Canada, and someone who only ever stood
    /// on the Canadian bank was still there. Detection is purely by coordinate and never
    /// looked at country anyway; this exists so the *presentation* stops insisting on one side.
    var alsoInCountryCodes: [String] = []

    /// Every country this site sits in, the primary one first.
    var countryCodes: [String] { [countryCode] + alsoInCountryCodes }

    /// One flag per country the site sits in — 🇺🇸🇨🇦 for a wonder that straddles a border.
    var flagEmoji: String {
        countryCodes.map { code in
            code.unicodeScalars
                .compactMap { Unicode.Scalar(127397 + $0.value) }
                .map { String($0) }
                .joined()
        }.joined()
    }
}

/// A wonder plus whether (and how) the user has photographed it.
struct WonderStat: Identifiable, Sendable {
    let wonder: Wonder
    var id: String { wonder.id }
    var photoCount: Int
    var firstSeen: Date?
    var lastSeen: Date?
    var representativePhotoID: String?
    var photoIDs: [String] = []   // all matching photos, newest first

    var seen: Bool { photoCount > 0 }
}
