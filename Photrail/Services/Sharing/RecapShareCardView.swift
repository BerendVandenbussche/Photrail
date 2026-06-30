import SwiftUI

enum RecapTheme: String, CaseIterable, Identifiable, Sendable {
    case dark, light, transparent
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Which aspect of the recap a share card emphasizes (per-slide sharing).
enum RecapCardFocus: Sendable { case snapshot, route, personality, newCountries }

/// The premium, exportable "Year in Travel" share card. 9:16, render-ready.
/// This is the primary marketing asset — branded, glanceable, beautiful.
struct RecapShareCardView: View {
    let recap: RecapModel
    var theme: RecapTheme = .dark
    var focus: RecapCardFocus = .snapshot

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
            focusBody
            Spacer(minLength: 14)
            footer
        }
        .padding(theme == .transparent ? 26 : 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(transparentPanel)
        .padding(theme == .transparent ? 18 : 0)
    }

    @ViewBuilder
    private var focusBody: some View {
        switch focus {
        case .snapshot:     snapshotBody
        case .route:        routeBody
        case .personality:  personalityBody
        case .newCountries: newCountriesBody
        }
    }

    private var snapshotBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
            Spacer(minLength: 16)
            statsGrid
            if !recap.topSlices.isEmpty {
                Spacer(minLength: 16)
                personality
            }
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold)).tracking(1.6)
            .foregroundStyle(accent)
    }

    private func bigHeadline(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 44, weight: .black, design: .rounded))
            .foregroundStyle(primaryText)
            .lineLimit(2).minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var routeBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            eyebrow("Where I went")
            bigHeadline("\(recap.journey.count) countries,\none journey")
            JourneyMapView(stops: recap.journey,
                           lineColor: primaryText.opacity(0.5), dotColor: primaryText)
                .frame(height: 230)
            FlowLayout(spacing: 12, rowSpacing: 10) {
                ForEach(recap.journey) { stop in
                    Text(stop.flag).font(.system(size: 26))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var personalityBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            eyebrow("My travel personality")
            bigHeadline(personalityHeadline)
            VStack(spacing: 12) {
                ForEach(recap.topSlices) { slice in
                    HStack(spacing: 10) {
                        Text(slice.category.emoji).font(.system(size: 20))
                        Text(slice.category.title)
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(primaryText.opacity(0.9))
                        Spacer()
                        Text("\(Int(slice.percentage.rounded()))%")
                            .font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(primaryText)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var personalityHeadline: String {
        guard let slice = recap.topSlices.first else { return recap.title }
        return "\(Int(slice.percentage.rounded()))%\n\(slice.category.title)"
    }

    private var newCountriesBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            eyebrow("New in \(String(recap.year))")
            bigHeadline(recap.newCountries.count == 1 ? "1 new country" : "\(recap.newCountries.count) new countries")
            FlowLayout(spacing: 12, rowSpacing: 12) {
                ForEach(recap.newCountries) { badge in
                    VStack(spacing: 3) {
                        Text(badge.flag).font(.system(size: 30))
                        Text(badge.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 76)
                }
            }
            Spacer(minLength: 0)
        }
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
                Text("\(recap.score)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(accent))
                Text(recap.scoreTier)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)
                Text("· Travel Score")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(secondaryText)
            }
        }
    }

    /// Year-specific, share-worthy metrics. Interesting "this year" stats come first;
    /// always-available totals backfill so the grid is full. Capped at 6 (3×2).
    private var statItems: [(String, String, String)] {
        var items: [(String, String, String)] = []
        items.append(("🌍", "\(recap.countries)", recap.countries == 1 ? "Country" : "Countries"))
        if !recap.newCountries.isEmpty {
            items.append(("🆕", "\(recap.newCountries.count)",
                          recap.newCountries.count == 1 ? "New country" : "New countries"))
        }
        items.append(("✈️", "\(recap.trips)", recap.trips == 1 ? "Trip" : "Trips"))
        if recap.wonders > 0 {
            items.append(("🏛", "\(recap.wonders)", recap.wonders == 1 ? "Wonder" : "Wonders"))
        }
        if let peak = recap.highestAltitudeText {
            items.append(("🏔", peak, "Highest peak"))
        }
        if recap.distanceKm >= 100 {
            items.append(("📏", recap.distanceText, "Traveled"))
        }
        items.append(("📸", "\(recap.photos)", "Photos"))
        items.append(("🌎", "\(recap.continents)", recap.continents == 1 ? "Continent" : "Continents"))
        return Array(items.prefix(6))
    }

    private var statsGrid: some View {
        let items = statItems
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
