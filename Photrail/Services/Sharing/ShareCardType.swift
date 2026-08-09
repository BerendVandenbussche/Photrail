import Foundation

/// The share templates a user can export. Ordered by viral priority.
enum ShareCardType: String, CaseIterable, Identifiable, Sendable {
    /// The world map with every visited country lit up. Brings its own artwork rather than
    /// using `ShareCardView`, so it ignores the background picker.
    case poster
    case personality
    case summary
    case wonders
    case trip

    var id: String { rawValue }

    /// Short label for the template picker.
    var pickerTitle: String {
        switch self {
        case .poster:      return "Poster"
        case .personality: return "Personality"
        case .summary:     return "Summary"
        case .wonders:     return "Wonders"
        case .trip:        return "Trip"
        }
    }

    /// Templates that draw their own card instead of the shared `ShareCardView`, and so have
    /// no background choice to offer.
    var usesOwnArtwork: Bool { self == .poster }
}

/// How the card is rendered behind the content.
enum ShareCardBackground: String, CaseIterable, Identifiable, Sendable {
    case map          // branded gradient + a subtle constellation of your countries
    case transparent  // alpha around a panel — drop onto your own story
    case photo        // your own photo, blurred + dimmed

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .map:         return "Map"
        case .transparent: return "Transparent"
        case .photo:       return "Photo"
        }
    }

    var systemImage: String {
        switch self {
        case .map:         return "globe.europe.africa.fill"
        case .transparent: return "square.dashed"
        case .photo:       return "photo"
        }
    }
}
