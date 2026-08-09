import SwiftUI

/// The shared look for anything celebrating an achievement — the unlock toast and the
/// shareable video card. Defined once so the two can't drift apart.
enum AchievementTheme {
    static let indigo = Color(red: 0.31, green: 0.27, blue: 0.9)
    static let purple = Color(red: 0.55, green: 0.3, blue: 0.85)
    /// Near-black base the card fades down into, so text sits on a calm field.
    static let deep = Color(red: 0.05, green: 0.04, blue: 0.14)

    static let gradient = LinearGradient(colors: [indigo, purple],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing)
}
