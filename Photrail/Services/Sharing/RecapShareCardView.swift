import SwiftUI

enum RecapTheme: String, CaseIterable, Identifiable, Sendable {
    case dark, light, transparent
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// The premium, exportable "Year in Travel" finale card. 9:16, render-ready.
/// This is the primary marketing asset — branded, glanceable, beautiful.
struct RecapShareCardView: View {
    let recap: RecapModel
    var theme: RecapTheme = .dark

    static let canvasSize = CGSize(width: 360, height: 640)

    // Palette
    private static let darkTop = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let darkBottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private static let lightTop = Color(red: 0.96, green: 0.96, blue: 1.0)
    private static let lightBottom = Color(red: 0.90, green: 0.89, blue: 0.99)
    private static let accent = Color(red: 0.42, green: 0.36, blue: 0.95)

    private var onDark: Bool { theme != .light }
    private var primaryText: Color { onDark ? .white : Color(red: 0.08, green: 0.08, blue: 0.16) }
    private var secondaryText: Color { primaryText.opacity(0.6) }
    private var accent: Color { onDark ? Color(red: 0.6, green: 0.55, blue: 1.0) : Self.accent }

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: theme == .transparent ? 0 : 36, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        switch theme {
        case .dark:
            ZStack {
                LinearGradient(colors: [Self.darkTop, Self.darkBottom], startPoint: .top, endPoint: .bottom)
                MiniMapDots(pins: recap.pins, color: .white.opacity(0.22), dotSize: 4)
            }
        case .light:
            ZStack {
                LinearGradient(colors: [Self.lightTop, Self.lightBottom], startPoint: .top, endPoint: .bottom)
                MiniMapDots(pins: recap.pins, color: Self.accent.opacity(0.18), dotSize: 4)
            }
        case .transparent:
            Color.clear
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 10)
            hero
            Spacer(minLength: 16)
            statsGrid
            if !recap.topSlices.isEmpty {
                Spacer(minLength: 16)
                personality
            }
            Spacer(minLength: 14)
            footer
        }
        .padding(theme == .transparent ? 26 : 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(transparentPanel)
        .padding(theme == .transparent ? 18 : 0)
    }

    @ViewBuilder
    private var transparentPanel: some View {
        if theme == .transparent {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(red: 0.06, green: 0.07, blue: 0.18).opacity(0.92))
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            LogoMark(color: primaryText).frame(width: 18, height: 18)
            Text("Photrail")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            Spacer()
            Text(String(recap.year))
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(secondaryText)
        }
        .foregroundStyle(primaryText)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(String(recap.year)) AT A GLANCE")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(accent)
            Text(recap.title)
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text("Travel Score")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(secondaryText)
                Text("\(recap.score)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(accent))
            }
        }
    }

    private var statsGrid: some View {
        let items: [(String, String, String)] = [
            ("🌍", "\(recap.countries)", "Countries"),
            ("🏙", "\(recap.cities)", "Cities"),
            ("✈️", "\(recap.trips)", "Trips"),
            ("📸", "\(recap.photos)", "Photos"),
            ("🏛", "\(recap.wonders)", "Wonders"),
            ("🌎", "\(recap.continents)", "Continents")
        ]
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items, id: \.2) { emoji, value, label in
                VStack(spacing: 3) {
                    Text(emoji).font(.system(size: 18))
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(primaryText.opacity(onDark ? 0.08 : 0.05)))
            }
        }
    }

    private var personality: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(recap.topSlices) { slice in
                HStack(spacing: 8) {
                    Text(slice.category.emoji).font(.system(size: 15))
                    Text(slice.category.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(primaryText.opacity(0.9))
                    Spacer()
                    Text("\(Int(slice.percentage.rounded()))%")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(primaryText)
                }
            }
        }
    }

    private var footer: some View {
        Text("Your travel history, automatically")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(secondaryText)
    }
}
