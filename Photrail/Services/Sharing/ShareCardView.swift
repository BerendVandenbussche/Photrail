import SwiftUI

/// The premium, render-ready share card. Designed in a fixed 360×640 (9:16) space
/// so it exports cleanly to an Instagram-story-sized image. Shares the same visual
/// language as the Year-in-Travel recap cards: header → eyebrow → hero → stat band → CTA.
struct ShareCardView: View {
    let model: ShareCardModel
    var background: ShareCardBackground = .map
    var photo: UIImage? = nil

    static let canvasSize = CGSize(width: 360, height: 640)

    // Brand palette
    private static let brandTop = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let brandBottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private let accent = Color(red: 0.6, green: 0.55, blue: 1.0)
    private var primaryText: Color { .white }
    private var secondaryText: Color { .white.opacity(0.6) }
    private var panelFill: Color { .white.opacity(0.1) }

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
                Constellation(pins: model.pins).opacity(0.9)
                RadialGradient(colors: [accent.opacity(0.35), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 360)
            }
        case .photo:
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                    .clipped()
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
            header
            Spacer(minLength: 14)
            VStack(alignment: .leading, spacing: 16) {
                eyebrow(eyebrowText)
                cardContent
            }
            Spacer(minLength: 16)
            footer
        }
        .padding(background == .transparent ? 28 : 32)
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

    private var header: some View {
        HStack(spacing: 7) {
            LogoMark(color: primaryText).frame(width: 18, height: 18)
            Text("Photrail")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            Spacer()
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

    // MARK: - Shared building blocks

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold)).tracking(1.6)
            .foregroundStyle(accent)
    }

    private var headlineText: some View {
        Text(model.headline)
            .font(.system(size: 52, weight: .black, design: .rounded))
            .foregroundStyle(primaryText)
            .lineLimit(3).minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func statBand(_ items: [ShareCardModel.Stat]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 3) {
                    Text(item.value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText)
                        .minimumScaleFactor(0.5).lineLimit(1)
                    Text(item.label.uppercased())
                        .font(.system(size: 9, weight: .semibold)).tracking(0.6)
                        .foregroundStyle(secondaryText)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                if index < items.count - 1 {
                    Rectangle().fill(primaryText.opacity(0.15)).frame(width: 1, height: 32)
                }
            }
        }
        .padding(.vertical, 18).padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(panelFill))
    }

    private func bar(_ slice: TravelPersonalityProfile.Slice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(slice.category.emoji).font(.system(size: 18))
                Text(slice.category.title)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(primaryText)
                Spacer()
                Text("\(Int(slice.percentage.rounded()))%")
                    .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(primaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(primaryText.opacity(0.14))
                    Capsule().fill(accent)
                        .frame(width: max(6, geo.size.width * CGFloat(slice.percentage / 100)))
                }
            }
            .frame(height: 10)
        }
    }

    private var eyebrowText: String {
        switch model.type {
        case .summary:     return "My travel map"
        case .personality: return model.subheadline ?? "My travel personality"
        case .wonders:     return "World wonders"
        case .trip:        return "My trip"
        }
    }

    // MARK: - Per-type content

    @ViewBuilder
    private var cardContent: some View {
        switch model.type {
        case .summary:     summaryContent
        case .personality: personalityContent
        case .wonders:     wondersContent
        case .trip:        tripContent
        }
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            headlineText
            if !model.supporting.isEmpty { statBand(model.supporting) }
            Spacer(minLength: 0)
        }
    }

    private var personalityContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            headlineText
            VStack(spacing: 14) {
                ForEach(model.slices) { bar($0) }
            }
            Spacer(minLength: 0)
        }
    }

    private var wondersContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            headlineText
            VStack(spacing: 10) {
                ForEach(model.wonders) { badge in
                    HStack(spacing: 10) {
                        Text(badge.emoji)
                            .font(.system(size: 22))
                            .grayscale(badge.seen ? 0 : 1)
                            .opacity(badge.seen ? 1 : 0.4)
                        Text(badge.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(primaryText.opacity(badge.seen ? 0.95 : 0.5))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: badge.seen ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(badge.seen ? accent : primaryText.opacity(0.3))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var tripContent: some View {
        if let trip = model.trip {
            VStack(alignment: .leading, spacing: 18) {
                headlineText
                Text(trip.dateRange)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(secondaryText)
                statBand([
                    .init(value: "\(trip.photoCount)", label: "Photos"),
                    .init(value: "\(trip.cities.count)", label: trip.cities.count == 1 ? "City" : "Cities")
                ])
                if !trip.cities.isEmpty {
                    Text(trip.cities.prefix(5).joined(separator: " · "))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
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
