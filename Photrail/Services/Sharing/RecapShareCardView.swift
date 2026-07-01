import SwiftUI

enum RecapTheme: String, CaseIterable, Identifiable, Sendable {
    case dark, light, transparent
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Which aspect of the recap a share card emphasizes (per-slide sharing).
enum RecapCardFocus: Sendable {
    case snapshot, route, personality, newCountries, distance, wonders, biggestTrip, highestPeak
}

/// The premium, exportable "Year in Travel" share card. 9:16, render-ready.
/// This is the primary marketing asset — branded, glanceable, beautiful. Every
/// card follows the same rhythm: header → eyebrow → hero → visual → stat band → CTA,
/// so no shared card ever looks empty.
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
    private var panelFill: Color { primaryText.opacity(onDark ? 0.08 : 0.05) }

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: theme == .transparent ? 0 : 36, style: .continuous))
    }

    // MARK: - Chrome

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
            Spacer(minLength: 14)
            focusBody
            Spacer(minLength: 16)
            footer
        }
        .padding(theme == .transparent ? 26 : 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(transparentPanel)
        .padding(theme == .transparent ? 18 : 0)
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

    private var footer: some View {
        HStack(spacing: 6) {
            LogoMark(color: accent).frame(width: 13, height: 13)
            Text("Made with Photrail")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(primaryText)
            Text("· travel history, automatically")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(secondaryText)
        }
    }

    @ViewBuilder
    private var transparentPanel: some View {
        if theme == .transparent {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(red: 0.06, green: 0.07, blue: 0.18).opacity(0.92))
        }
    }

    // MARK: - Focus router

    @ViewBuilder
    private var focusBody: some View {
        switch focus {
        case .snapshot:     snapshotBody
        case .route:        routeBody
        case .personality:  personalityBody
        case .newCountries: newCountriesBody
        case .distance:     distanceBody
        case .wonders:      wondersBody
        case .biggestTrip:  biggestTripBody
        case .highestPeak:  highestPeakBody
        }
    }

    // MARK: - Shared building blocks

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold)).tracking(1.6)
            .foregroundStyle(accent)
    }

    private func bigHeadline(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 42, weight: .black, design: .rounded))
            .foregroundStyle(primaryText)
            .lineLimit(3).minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A giant single number for "one big flex" cards.
    private func hugeNumber(_ value: String, unit: String? = nil) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: 68, weight: .black, design: .rounded))
                .foregroundStyle(primaryText)
                .minimumScaleFactor(0.4).lineLimit(1)
            if let unit {
                Text(unit)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(secondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A row of 2–3 headline stats, on a subtle panel — keeps every card full.
    private func statBand(_ items: [(String, String)]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 3) {
                    Text(item.0)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText)
                        .minimumScaleFactor(0.5).lineLimit(1)
                    Text(item.1.uppercased())
                        .font(.system(size: 9, weight: .semibold)).tracking(0.6)
                        .foregroundStyle(secondaryText)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                if index < items.count - 1 {
                    Rectangle().fill(primaryText.opacity(0.15)).frame(width: 1, height: 30)
                }
            }
        }
        .padding(.vertical, 16).padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(panelFill))
    }

    // MARK: - Snapshot (hero / summary / finale)

    private var snapshotBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
            Spacer(minLength: 16)
            statsGrid
            if !recap.topSlices.isEmpty {
                Spacer(minLength: 14)
                topStyles
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow("\(String(recap.year)) at a glance")
            Text(recap.title)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(primaryText)
                .lineLimit(2).minimumScaleFactor(0.5)
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

    /// Year-specific, share-worthy metrics; capped at 6 (3×2).
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
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(panelFill))
            }
        }
    }

    private var topStyles: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("TOP STYLES")
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(secondaryText)
            ForEach(recap.topSlices) { slice in compactBar(slice) }
        }
    }

    private func compactBar(_ slice: TravelPersonalityProfile.Slice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(slice.category.emoji).font(.system(size: 14))
                Text(slice.category.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                Text("\(Int(slice.percentage.rounded()))%")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(primaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(primaryText.opacity(0.12))
                    Capsule().fill(accent)
                        .frame(width: max(4, geo.size.width * CGFloat(slice.percentage / 100)))
                }
            }
            .frame(height: 7)
        }
    }

    // MARK: - Route

    private var routeBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("My year on the map")
            bigHeadline(recap.journey.count == 1
                        ? "1 country,\none journey"
                        : "\(recap.journey.count) countries,\none journey")
            JourneyMapView(stops: recap.journey,
                           lineColor: primaryText.opacity(0.5), dotColor: primaryText)
                .frame(height: 190)
            FlowLayout(spacing: 10, rowSpacing: 8) {
                ForEach(recap.journey.prefix(24)) { stop in
                    Text(stop.flag).font(.system(size: 24))
                }
            }
            Spacer(minLength: 0)
            statBand(routeStats)
        }
    }

    private var routeStats: [(String, String)] {
        var items: [(String, String)] = [("\(recap.countries)", "Countries"),
                                         ("\(recap.continents)", "Continents")]
        if recap.distanceKm >= 100 { items.append((recap.distanceText, "Traveled")) }
        else { items.append(("\(recap.trips)", "Trips")) }
        return items
    }

    // MARK: - Distance (one big flex)

    private var distanceBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("Distance traveled")
            hugeNumber(recap.distanceText)
            if let comparison = recap.distanceComparison {
                Text(comparison)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(2).minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            JourneyMapView(stops: recap.journey,
                           lineColor: primaryText.opacity(0.5), dotColor: primaryText)
                .frame(height: 150)
            Spacer(minLength: 0)
            statBand([("\(recap.countries)", "Countries"),
                      ("\(recap.trips)", "Trips"),
                      ("\(recap.continents)", "Continents")])
        }
    }

    // MARK: - Personality (visual bars)

    private var personalityBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            eyebrow("My travel personality")
            bigHeadline(personalityHeadline)
            VStack(spacing: 14) {
                ForEach(recap.topSlices) { slice in personalityBar(slice) }
            }
            Spacer(minLength: 0)
        }
    }

    private func personalityBar(_ slice: TravelPersonalityProfile.Slice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(slice.category.emoji).font(.system(size: 18))
                Text(slice.category.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                Text("\(Int(slice.percentage.rounded()))%")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(primaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(primaryText.opacity(0.12))
                    Capsule().fill(accent)
                        .frame(width: max(6, geo.size.width * CGFloat(slice.percentage / 100)))
                }
            }
            .frame(height: 10)
        }
    }

    private var personalityHeadline: String {
        guard let slice = recap.topSlices.first else { return recap.title }
        return "\(Int(slice.percentage.rounded()))%\n\(slice.category.title)"
    }

    // MARK: - New countries

    private var newCountriesBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("New in \(String(recap.year))")
            bigHeadline(recap.newCountries.count == 1
                        ? "1 new country\nunlocked"
                        : "\(recap.newCountries.count) new countries\nunlocked")
            FlowLayout(spacing: 12, rowSpacing: 12) {
                ForEach(recap.newCountries.prefix(15)) { badge in
                    VStack(spacing: 3) {
                        Text(badge.flag).font(.system(size: 32))
                        Text(badge.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(secondaryText)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: 74)
                }
            }
            Spacer(minLength: 0)
            statBand([("\(recap.newCountries.count)", "New"),
                      ("\(recap.countries)", "Countries"),
                      ("\(recap.continents)", "Continents")])
        }
    }

    // MARK: - Wonders

    private var wondersBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("World wonders")
            bigHeadline(wondersHeadline)
            VStack(spacing: 10) {
                ForEach(recap.seenWonders.prefix(6)) { wonder in
                    HStack(spacing: 12) {
                        Text(wonder.emoji).font(.system(size: 24))
                        Text(wonder.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(primaryText).lineLimit(1)
                        Spacer()
                        if wonder.isOfficial {
                            Text("WONDER")
                                .font(.system(size: 9, weight: .heavy)).tracking(0.8)
                                .foregroundStyle(accent)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(accent.opacity(0.18)))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var wondersHeadline: String {
        let official = recap.seenWonders.filter(\.isOfficial).count
        if official > 0 { return "\(official) of the\n7 Wonders" }
        let n = recap.seenWonders.count
        return n == 1 ? "1 famous\nlandmark" : "\(n) famous\nlandmarks"
    }

    // MARK: - Biggest trip

    private var biggestTripBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("My biggest adventure")
            bigHeadline(recap.biggestTripTitle ?? recap.favoriteCountryName ?? "My biggest trip")
            if let subtitle = recap.biggestTripSubtitle {
                Text(subtitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(secondaryText)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            if let longest = recap.longestTripText {
                Text("🧳 Longest · \(longest)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.7)
            }
            if let month = recap.busiestMonth {
                Text("📅 Busiest month · \(month)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(secondaryText).lineLimit(1)
            }
            Spacer(minLength: 0)
            statBand([("\(recap.countries)", "Countries"),
                      ("\(recap.trips)", "Trips"),
                      ("\(recap.photos)", "Photos")])
        }
    }

    // MARK: - Highest peak

    private var highestPeakBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow("Highest point reached")
            Text("⛰️").font(.system(size: 56))
            hugeNumber(recap.highestAltitudeText ?? "—")
            if let place = recap.highestAltitudePlace {
                Text(place)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(2).minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            statBand([("\(recap.countries)", "Countries"),
                      ("\(recap.trips)", "Trips"),
                      ("\(recap.continents)", "Continents")])
        }
    }
}
