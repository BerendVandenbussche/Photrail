import Foundation

/// The share templates a user can export. Ordered by viral priority.
enum ShareCardType: String, CaseIterable, Identifiable, Sendable {
    case personality
    case summary
    case wonders
    case trip

    var id: String { rawValue }

    /// Short label for the template picker.
    var pickerTitle: String {
        switch self {
        case .personality: return "Personality"
        case .summary:     return "Summary"
        case .wonders:     return "Wonders"
        case .trip:        return "Trip"
        }
    }
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
