import SwiftUI

/// The premium, render-ready share card. Designed in a fixed 360×640 (9:16) space
/// so it exports cleanly to an Instagram-story-sized image. All visuals are solid
/// colors / gradients / blur (no Materials) so they render faithfully via ImageRenderer.
struct ShareCardView: View {
    let model: ShareCardModel
    var background: ShareCardBackground = .map
    var photo: UIImage? = nil

    static let canvasSize = CGSize(width: 360, height: 640)

    // Brand palette
    private static let brandTop = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let brandBottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private static let accent = Color(red: 0.55, green: 0.5, blue: 1.0)

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: background == .transparent ? 0 : 36, style: .continuous))
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        switch background {
        case .map:
            ZStack {
                LinearGradient(colors: [Self.brandTop, Self.brandBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Constellation(pins: model.pins)
                    .opacity(0.9)
                // soft glow
                RadialGradient(colors: [Self.accent.opacity(0.35), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 360)
            }
        case .photo:
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    // Pin to the canvas and clip: in fill mode the image's layout size
                    // overflows for landscape photos, which would widen the card and
                    // push the text content out of frame.
                    .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                    .clipped()
                    .blur(radius: 18)
                    .overlay(LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.65)],
                                            startPoint: .top, endPoint: .bottom))
            } else {
                LinearGradient(colors: [Self.brandTop, Self.brandBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        case .transparent:
            Color.clear
        }
    }

    // MARK: - Content

    private var contentLayer: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandMark
            Spacer(minLength: 12)
            cardContent
            Spacer(minLength: 12)
            footer
        }
        .padding(background == .transparent ? 28 : 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(transparentPanel)
        .padding(background == .transparent ? 20 : 0)
    }

    @ViewBuilder
    private var transparentPanel: some View {
        if background == .transparent {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(red: 0.06, green: 0.07, blue: 0.18).opacity(0.92))
        }
    }

    private var brandMark: some View {
        HStack(spacing: 7) {
            LogoMark(color: .white)
                .frame(width: 18, height: 18)
            Text("Photrail")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .tracking(0.5)
            Spacer()
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    private var footer: some View {
        Text(ShareCardModel.tagline)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.55))
    }

    @ViewBuilder
    private var cardContent: some View {
        switch model.type {
        case .summary:     summaryContent
        case .personality: personalityContent
        case .wonders:     wondersContent
        case .trip:        tripContent
        }
    }

    // MARK: - Per-type content

    private var headlineText: some View {
        Text(model.headline)
            .font(.system(size: 54, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            headlineText
            HStack(spacing: 22) {
                ForEach(model.supporting) { stat in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.value)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(stat.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
        }
    }

    private var personalityContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let sub = model.subheadline {
                Text(sub.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Self.accent)
            }
            headlineText
            VStack(spacing: 12) {
                ForEach(model.slices) { slice in
                    HStack(spacing: 10) {
                        Text(slice.category.emoji).font(.system(size: 20))
                        Text(slice.category.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text("\(Int(slice.percentage.rounded()))%")
                            .font(.system(size: 16, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var wondersContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            headlineText
            VStack(spacing: 10) {
                ForEach(model.wonders) { badge in
                    HStack(spacing: 10) {
                        Text(badge.emoji)
                            .font(.system(size: 20))
                            .grayscale(badge.seen ? 0 : 1)
                            .opacity(badge.seen ? 1 : 0.4)
                        Text(badge.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(badge.seen ? 0.95 : 0.5))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: badge.seen ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(badge.seen ? Self.accent : .white.opacity(0.3))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tripContent: some View {
        if let trip = model.trip {
            VStack(alignment: .leading, spacing: 18) {
                headlineText
                Text(trip.dateRange)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(trip.photoCount)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Photos").font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(trip.cities.count)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Cities").font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                if !trip.cities.isEmpty {
                    Text(trip.cities.prefix(5).joined(separator: " · "))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
    }
}

/// A faint constellation of the user's visited countries, equirectangular-projected.
private struct Constellation: View {
    let pins: [ShareCardModel.Coordinate]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(pins.enumerated()), id: \.offset) { _, pin in
                    let x = (pin.longitude + 180) / 360 * geo.size.width
                    let y = (90 - pin.latitude) / 180 * geo.size.height
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                }
            }
        }
    }
}
