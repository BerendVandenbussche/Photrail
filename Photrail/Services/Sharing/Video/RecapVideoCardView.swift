import SwiftUI

/// The animated "Year in Travel" finale — the recap's snapshot card, choreographed.
///
/// This is the artifact the Lifetime paywall promises ("your animated recap of the year,
/// ready to share"), and it's the one card in the app worth exporting as motion: a feed
/// autoplays a video and sits still on a PNG.
///
/// **This view must stay a pure function of `progress`.** No `@State`, no `Date()`, no
/// unseeded randomness, and none of SwiftUI's implicit animation constructs (`TimelineView`,
/// `.phaseAnimator`, `withAnimation`, `matchedGeometryEffect`) — `ImageRenderer` can't sample
/// any of them, and the exported video would freeze on one arbitrary phase. Every animated
/// property is derived from `progress` through a `Ramp`.
///
/// Also avoided for the same reason: `Material` (renders flat grey), `.blur()` and
/// `.drawingGroup()` (unreliable inside `ImageRenderer`), and `LazyVGrid` (a lazy container
/// can decline to build content that isn't on screen yet).
///
/// The layout deliberately mirrors `RecapShareCardView`'s `.snapshot` focus, so the video and
/// the still image a user shares from the same screen are recognisably the same card.
struct RecapVideoCardView: View {
    let recap: RecapModel
    /// `.transparent` is rendered as `.dark` — H.264 has no alpha channel.
    var theme: RecapTheme = .dark
    /// 0…1 across the whole clip.
    let progress: Double

    /// Same canvas as every other share card, so the standard 3× path gives 1080×1920.
    static let canvasSize = CGSize(width: 360, height: 640)
    /// Longer than the achievement clip: this card has a hero, six counting stats and the
    /// personality bars to get through, and rushing them reads as a glitch rather than a beat.
    static let duration: Double = 4.5

    // Palette — matched to `RecapShareCardView` so the video and the still card agree.
    private static let darkTop = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let darkBottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private static let lightTop = Color(red: 0.96, green: 0.96, blue: 1.0)
    private static let lightBottom = Color(red: 0.90, green: 0.89, blue: 0.99)
    private static let lightAccent = Color(red: 0.42, green: 0.36, blue: 0.95)

    private var onDark: Bool { theme != .light }
    private var primaryText: Color { onDark ? .white : Color(red: 0.08, green: 0.08, blue: 0.16) }
    private var secondaryText: Color { primaryText.opacity(0.6) }
    private var accent: Color { onDark ? Color(red: 0.6, green: 0.55, blue: 1.0) : Self.lightAccent }
    private var panelFill: Color { primaryText.opacity(onDark ? 0.08 : 0.05) }

    // MARK: - Choreography
    //
    // Nothing overlaps by accident: the map settles, the title lands, the score pops and
    // counts, the stats deal in one at a time, the bars fill, and the brand resolves last.

    private static let backdropIn = Ramp(0.00, 0.30, easing: .easeOut)
    private static let headerIn   = Ramp(0.02, 0.14)
    private static let eyebrowIn  = Ramp(0.07, 0.19)
    private static let titleIn    = Ramp(0.11, 0.30, easing: .spring)
    private static let scoreIn    = Ramp(0.24, 0.38, easing: .spring)
    private static let scoreCount = Ramp(0.26, 0.46, easing: .easeOut)
    private static let stylesIn   = Ramp(0.66, 0.76)
    private static let footerIn   = Ramp(0.86, 0.97)

    /// Stat tile `index` deals in, staggered.
    private static func tileIn(_ index: Int) -> Ramp {
        let start = 0.40 + Double(index) * 0.035
        return Ramp(start, start + 0.14, easing: .spring)
    }
    /// Its number counts up just behind the tile itself.
    private static func tileCount(_ index: Int) -> Ramp {
        let start = 0.42 + Double(index) * 0.035
        return Ramp(start, start + 0.24, easing: .easeOut)
    }
    /// Personality bar `index` fills.
    private static func barIn(_ index: Int) -> Ramp {
        let start = 0.70 + Double(index) * 0.06
        return Ramp(start, start + 0.16, easing: .easeOut)
    }

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        // Share cards stay English, matching every other card in the app.
        .environment(\.locale, Locale(identifier: "en_US"))
        // Pinned so semantic colours can't flip with the device while the card is exported.
        .environment(\.colorScheme, onDark ? .dark : .light)
    }

    // MARK: - Backdrop

    private var background: some View {
        // The gradient is never animated — a card that fades up from black would spend its
        // first frames, the ones a feed shows as the thumbnail, on nothing.
        ZStack {
            LinearGradient(colors: onDark ? [Self.darkTop, Self.darkBottom]
                                          : [Self.lightTop, Self.lightBottom],
                           startPoint: .top, endPoint: .bottom)
            MiniMapDots(pins: recap.pins,
                        color: onDark ? .white.opacity(0.22) : Self.lightAccent.opacity(0.18),
                        dotSize: 4)
                .opacity(Self.backdropIn.value(at: progress))
                .scaleEffect(Self.backdropIn.interpolate(1.06, 1.0, at: progress))
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 14)
            hero
            Spacer(minLength: 16)
            statsGrid
            if !recap.topSlices.isEmpty {
                Spacer(minLength: 14)
                topStyles
            }
            Spacer(minLength: 16)
            footer
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        .opacity(Self.headerIn.value(at: progress))
        .offset(y: Self.headerIn.interpolate(-8, 0, at: progress))
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(String(recap.year)) at a glance".uppercased())
                .font(.system(size: 12, weight: .bold)).tracking(1.6)
                .foregroundStyle(accent)
                .opacity(Self.eyebrowIn.value(at: progress))
                .offset(y: Self.eyebrowIn.interpolate(10, 0, at: progress))

            Text(recap.title)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(primaryText)
                .lineLimit(2).minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(Ramp(0.11, 0.24).value(at: progress))
                .offset(y: Self.titleIn.interpolate(18, 0, at: progress))

            HStack(spacing: 8) {
                // Monospaced so counting up can't make the capsule breathe.
                Text("\(counted(recap.score, at: Self.scoreCount))")
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
            .opacity(Ramp(0.24, 0.34).value(at: progress))
            .scaleEffect(Self.scoreIn.interpolate(0.72, 1.0, at: progress), anchor: .leading)
        }
    }

    // MARK: - Stats

    /// A stat tile. Every value is numeric so it can count up; `suffix` carries the unit.
    private struct Stat {
        let emoji: String
        let value: Int
        var suffix: String = ""
        let label: String
    }

    /// Year-specific, share-worthy metrics; capped at 6 (3×2). Mirrors
    /// `RecapShareCardView.statItems` so the video and the still card show the same numbers.
    private var stats: [Stat] {
        var items: [Stat] = []
        items.append(Stat(emoji: "🌍", value: recap.countries,
                          label: recap.countries == 1 ? "Country" : "Countries"))
        if !recap.newCountries.isEmpty {
            items.append(Stat(emoji: "🆕", value: recap.newCountries.count,
                              label: recap.newCountries.count == 1 ? "New country" : "New countries"))
        }
        items.append(Stat(emoji: "✈️", value: recap.trips,
                          label: recap.trips == 1 ? "Trip" : "Trips"))
        if recap.wonders > 0 {
            items.append(Stat(emoji: "🏛", value: recap.wonders,
                              label: recap.wonders == 1 ? "Wonder" : "Wonders"))
        }
        if let altitude = recap.highestAltitude {
            items.append(Stat(emoji: "🏔", value: Int(altitude), suffix: " m", label: "Highest peak"))
        }
        if recap.distanceKm >= 100 {
            items.append(Stat(emoji: "📏", value: Int(recap.distanceKm), suffix: " km", label: "Traveled"))
        }
        items.append(Stat(emoji: "📸", value: recap.photos, label: "Photos"))
        items.append(Stat(emoji: "🌎", value: recap.continents,
                          label: recap.continents == 1 ? "Continent" : "Continents"))
        return Array(items.prefix(6))
    }

    /// Laid out as explicit rows rather than a `LazyVGrid` — a lazy container can decline to
    /// build a tile that hasn't scrolled into view, which `ImageRenderer` would capture as a
    /// hole in the frame.
    private var statsGrid: some View {
        let items = stats
        let rows = stride(from: 0, to: items.count, by: 3).map {
            Array(items[$0..<min($0 + 3, items.count)])
        }
        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 10) {
                    ForEach(Array(row.enumerated()), id: \.offset) { column, item in
                        tile(item, index: rowIndex * 3 + column)
                    }
                    // Keeps a short final row aligned with the one above it instead of
                    // stretching two tiles across the full width.
                    if row.count < 3 {
                        ForEach(0..<(3 - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func tile(_ item: Stat, index: Int) -> some View {
        let ramp = Self.tileIn(index)
        return VStack(spacing: 3) {
            Text(item.emoji).font(.system(size: 18))
            Text("\(counted(item.value, at: Self.tileCount(index)))\(item.suffix)")
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(primaryText)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(item.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(secondaryText)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(panelFill))
        .opacity(Ramp(ramp.start, ramp.start + 0.07).value(at: progress))
        .scaleEffect(ramp.interpolate(0.92, 1.0, at: progress))
        .offset(y: ramp.interpolate(14, 0, at: progress))
    }

    // MARK: - Top styles

    private var topStyles: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("TOP STYLES")
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(secondaryText)
                .opacity(Self.stylesIn.value(at: progress))
            ForEach(Array(recap.topSlices.enumerated()), id: \.element.id) { index, slice in
                bar(slice, index: index)
            }
        }
    }

    private func bar(_ slice: TravelPersonalityProfile.Slice, index: Int) -> some View {
        let ramp = Self.barIn(index)
        let fill = ramp.value(at: progress)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(slice.category.emoji).font(.system(size: 14))
                Text(slice.category.englishTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                // Counts to the real share alongside the track filling, so the number and
                // the bar always agree.
                Text("\(Int((slice.percentage * fill).rounded()))%")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(primaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(primaryText.opacity(0.12))
                    Capsule().fill(accent)
                        .frame(width: max(4, geo.size.width * CGFloat(slice.percentage / 100) * fill))
                }
            }
            .frame(height: 7)
        }
        .opacity(Ramp(ramp.start - 0.04, ramp.start + 0.04).value(at: progress))
    }

    // MARK: - Footer

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
        .opacity(Self.footerIn.value(at: progress))
        .offset(y: Self.footerIn.interpolate(8, 0, at: progress))
    }

    // MARK: - Helpers

    /// `target` counted up along `ramp`, grouped the way the still card formats it.
    private func counted(_ target: Int, at ramp: Ramp) -> String {
        Int((Double(target) * ramp.value(at: progress)).rounded()).formatted()
    }
}

#Preview {
    TimelineView(.animation) { timeline in
        let t = timeline.date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: RecapVideoCardView.duration + 1.2)
        RecapVideoCardView(recap: .empty(year: 2025),
                           progress: min(t / RecapVideoCardView.duration, 1))
    }
}
