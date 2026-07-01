import SwiftUI

/// The app's single card surface: a translucent material with a consistent,
/// continuous corner radius. Use everywhere a "card" is drawn so the UI feels
/// coherent instead of a stack of one-off backgrounds.
extension View {
    /// Standard content card (rounded material background).
    func card(cornerRadius: CGFloat = AppCard.radius) -> some View {
        background(.regularMaterial,
                   in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

enum AppCard {
    /// Corner radius for standard cards.
    static let radius: CGFloat = 16
    /// Corner radius for small chips / thumbnails.
    static let chipRadius: CGFloat = 12
    /// Standard inner padding for a card.
    static let padding: CGFloat = 16
    /// Standard horizontal inset from the screen edge.
    static let inset: CGFloat = 20
}
