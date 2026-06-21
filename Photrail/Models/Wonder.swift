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
    let countryCode: String   // ISO 3166-1 alpha-2, for the flag
    let emoji: String         // representative icon
    let category: WonderCategory
    let latitude: Double
    let longitude: Double
    /// Match radius in meters. Larger for sprawling sites (Great Wall, Grand Canyon).
    let radiusMeters: Double

    var flagEmoji: String {
        countryCode.unicodeScalars
            .compactMap { Unicode.Scalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
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
