import SwiftUI

/// A shareable animated card for an unlocked achievement — a tilted badge drifting slowly
/// behind a specular highlight, the way Apple's own share cards move.
///
/// **This view must stay a pure function of `progress`.** No `@State`, no `Date()`, no
/// unseeded randomness, and none of SwiftUI's implicit animation constructs (`TimelineView`,
/// `.phaseAnimator`, `withAnimation`, `matchedGeometryEffect`) — `ImageRenderer` can't sample
/// any of them, and the exported video would freeze on one arbitrary phase. Every animated
/// property is derived from `progress` through a `Ramp`.
///
/// Also avoided for the same reason: `Material` (renders flat grey), `.blur()` and
/// `.drawingGroup()` (unreliable inside `ImageRenderer`).
struct AchievementVideoCardView: View {
    let achievement: Achievement
    /// 0…1 across the whole clip.
    let progress: Double

    /// Same canvas as every other share card, so the standard 3× path gives 1080×1920.
    static let canvasSize = CGSize(width: 360, height: 640)

    // Choreography. Nothing overlaps by accident — the badge lands, then the words arrive
    // one at a time, then the brand resolves last.
    private static let badgeIn   = Ramp(0.00, 0.45, easing: .spring)
    private static let drift     = Ramp(0.00, 1.00, easing: .linear)
    private static let shine     = Ramp(0.22, 0.68, easing: .easeInOut)
    private static let emojiIn   = Ramp(0.08, 0.50, easing: .spring)
    private static let eyebrowIn = Ramp(0.30, 0.46)
    private static let titleIn   = Ramp(0.38, 0.56)
    private static let detailIn  = Ramp(0.46, 0.64)
    private static let brandIn   = Ramp(0.70, 0.88)

    private var badgeSide: CGFloat { 200 }

    var body: some View {
        ZStack {
            backdrop
            badge
            textBlock
            branding
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        // Share cards stay English, matching every other card in the app — and the achievement
        // title and detail are `LocalizedStringKey`, so without this a Dutch user would get a
        // Dutch card.
        .environment(\.locale, Locale(identifier: "en_US"))
        // The card is designed dark; pinning stops semantic colours flipping with the device.
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            AchievementTheme.gradient
            // Fades the lower half toward black so the type has a calm field to sit on.
            LinearGradient(colors: [.clear, AchievementTheme.deep.opacity(0.75), AchievementTheme.deep],
                           startPoint: .center, endPoint: .bottom)
            // A soft vignette, drawn as a radial gradient rather than a blur.
            RadialGradient(colors: [.clear, .black.opacity(0.35)],
                           center: .center, startRadius: 140, endRadius: 420)
        }
    }

    // MARK: - Badge

    /// The slab drifts for the whole three seconds — slower than anything else on the card,
    /// which is what makes it read as designed rather than bouncy.
    private var badge: some View {
        let entrance = Self.badgeIn.value(at: progress)
        let tilt = Self.drift.interpolate(-3.5, 3.5, at: progress)
        let float = Self.drift.interpolate(6, -6, at: progress)
        let shape = RoundedRectangle(cornerRadius: 52, style: .continuous)

        return ZStack {
            shape
                .fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.06)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            shape
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            specularHighlight
            Text(achievement.emoji)
                .font(.system(size: 96))
                .scaleEffect(0.6 + 0.4 * Self.emojiIn.value(at: progress))
                .opacity(Self.emojiIn.value(at: progress))
        }
        .frame(width: badgeSide, height: badgeSide)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .rotationEffect(.degrees(tilt))
        .scaleEffect(0.86 + 0.14 * entrance)
        .opacity(entrance)
        .offset(y: float)
        .position(x: Self.canvasSize.width / 2, y: 232)
    }

    /// A hard-edged gradient band sweeping across the slab once. A masked gradient rather
    /// than a blurred shape, because `.blur()` doesn't survive `ImageRenderer`.
    private var specularHighlight: some View {
        let sweep = Self.shine.interpolate(-1.6, 1.6, at: progress)
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0.30),
                .init(color: .white.opacity(0.45), location: 0.50),
                .init(color: .clear, location: 0.70)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: badgeSide * 1.6, height: badgeSide * 2.2)
            .rotationEffect(.degrees(20))
            .offset(x: sweep * badgeSide)
    }

    // MARK: - Type

    private var textBlock: some View {
        VStack(spacing: 10) {
            Text("Achievement unlocked")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(2.4)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.65))
                .opacity(Self.eyebrowIn.value(at: progress))
                .offset(y: Self.eyebrowIn.interpolate(12, 0, at: progress))

            Text(achievement.title)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .opacity(Self.titleIn.value(at: progress))
                .offset(y: Self.titleIn.interpolate(16, 0, at: progress))

            Text(achievement.detail)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .opacity(Self.detailIn.value(at: progress))
                .offset(y: Self.detailIn.interpolate(14, 0, at: progress))
        }
        .padding(.horizontal, 34)
        .frame(width: Self.canvasSize.width)
        .position(x: Self.canvasSize.width / 2, y: 452)
    }

    // MARK: - Branding

    /// One mark, one place, resolving last — the card should deliver the moment before it
    /// credits the app.
    ///
    /// Sits ~96pt above the bottom edge. Instagram and TikTok lay their caption and action
    /// bars over roughly the bottom 250px of a 1080×1920 story (≈83pt here), so anything
    /// flush to the edge gets covered — which is the most common way a share card wastes its
    /// branding entirely.
    private var branding: some View {
        HStack(spacing: 7) {
            LogoMark(color: .white.opacity(0.7))
                .frame(width: 14, height: 14)
            Text("Photrail")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text("· travel history, automatically")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
        .opacity(Self.brandIn.value(at: progress))
        .position(x: Self.canvasSize.width / 2, y: Self.canvasSize.height - 96)
    }
}

#Preview("Scrub") {
    struct Scrubber: View {
        @State private var progress: Double = 1

        var body: some View {
            VStack(spacing: 20) {
                AchievementVideoCardView(achievement: AchievementCatalog.all[2], progress: progress)
                    .scaleEffect(0.6)
                    .frame(width: 216, height: 384)
                Slider(value: $progress)
                Text(progress, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
            }
            .padding(40)
        }
    }
    return Scrubber()
}
