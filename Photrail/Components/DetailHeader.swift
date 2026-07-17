import SwiftUI

/// The shared hero header for emoji/flag-led detail pages (country, continent, wonder):
/// a large glyph, a title, and an optional subtitle.
struct DetailHeader: View {
    let glyph: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text(glyph).font(.system(size: 72))
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
