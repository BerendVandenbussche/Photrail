import SwiftUI

/// A story-size (9:16) postcard of one travel day: the day's best photos, a stamp with the flag,
/// a postmark with the place and date, "Day 3", and the day's route on a small map.
/// Render-ready, like the other share cards, and English like all of them.
struct PostcardCardView: View {
    let content: PostcardContent

    static let canvasSize = CGSize(width: 360, height: 640)

    private var postcard: DayPostcard { content.postcard }

    private static let paper = Color(red: 0.97, green: 0.94, blue: 0.88)
    private static let ink = Color(red: 0.16, green: 0.15, blue: 0.24)
    private static let stampRed = Color(red: 0.78, green: 0.22, blue: 0.24)
    private static let accent = Color(red: 0.31, green: 0.27, blue: 0.9)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Self.paper
            VStack(alignment: .leading, spacing: 0) {
                header
                photos.padding(.top, 16)
                Spacer(minLength: 12)
                message
                Spacer(minLength: 12)
                footer
            }
            .padding(24)

            stampAndPostmark
                .offset(x: Self.canvasSize.width - 112, y: 56)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .environment(\.locale, Locale(identifier: "en_US"))   // share cards stay English
        .environment(\.timeZone, postcard.timeZone)            // the trip's date, not the phone's
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 7) {
            LogoMark(color: Self.ink).frame(width: 16, height: 16)
            Text(verbatim: "Photrail")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
            Spacer()
            Text(verbatim: "POSTCARD")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundStyle(Self.ink.opacity(0.5))
                .padding(.trailing, 70)   // leave the corner to the stamp
        }
        .foregroundStyle(Self.ink)
    }

    // MARK: - Photos

    /// The best photo large; the next two as small prints tucked over its bottom edge.
    @ViewBuilder
    private var photos: some View {
        ZStack(alignment: .bottomTrailing) {
            photoPrint(content.photos.first, width: 300, height: 290)
                .rotationEffect(.degrees(-1.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            if content.photos.count > 1 {
                HStack(spacing: -14) {
                    ForEach(Array(content.photos.dropFirst().prefix(2).enumerated()), id: \.offset) { index, image in
                        photoPrint(image, width: 92, height: 92)
                            .rotationEffect(.degrees(index == 0 ? -6 : 5))
                    }
                }
                .offset(x: 4, y: 34)
            }
        }
        .frame(height: 300)
    }

    /// A photo with a white print border and a soft shadow.
    private func photoPrint(_ image: UIImage?, width: CGFloat, height: CGFloat) -> some View {
        let border: CGFloat = width > 150 ? 9 : 5
        return ZStack {
            Rectangle().fill(.white)
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Self.accent.opacity(0.7), Self.stampRed.opacity(0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(width: width - border * 2, height: height - border * 2)
            .clipped()
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    // MARK: - Stamp & postmark

    private var stampAndPostmark: some View {
        ZStack(alignment: .bottomLeading) {
            stamp.rotationEffect(.degrees(4))
            postmark.offset(x: -38, y: 26)
        }
    }

    private var stamp: some View {
        VStack(spacing: 2) {
            Text(verbatim: postcard.flag).font(.system(size: 34))
            Text(verbatim: postcard.countryCode.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(Self.stampRed)
        }
        .frame(width: 64, height: 76)
        .background(Color.white)
        .overlay(
            Rectangle()
                .strokeBorder(Self.stampRed.opacity(0.8), lineWidth: 1.2)
                .padding(4)
        )
        // Perforated edge.
        .overlay(
            Rectangle()
                .strokeBorder(Self.paper, style: StrokeStyle(lineWidth: 3, dash: [2.5, 3]))
        )
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }

    private var postmark: some View {
        let place = (postcard.cities.first ?? postcard.countryName).uppercased()
        return ZStack {
            Circle().strokeBorder(Self.ink.opacity(0.55), lineWidth: 1.5)
            Circle().strokeBorder(Self.ink.opacity(0.35), lineWidth: 0.8).padding(5)
            VStack(spacing: 1) {
                Text(verbatim: place)
                    .font(.system(size: 8, weight: .heavy))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(postcard.day, format: .dateTime.day().month(.abbreviated).year())
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 10)
            .foregroundStyle(Self.ink.opacity(0.7))
        }
        .frame(width: 78, height: 78)
        .rotationEffect(.degrees(-12))
        // The wavy cancellation lines that run off to the left.
        .background(alignment: .leading) {
            VStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in Wave().stroke(Self.ink.opacity(0.35), lineWidth: 1.2) }
            }
            .frame(width: 70, height: 26)
            .offset(x: -58)
        }
    }

    // MARK: - Message

    private var message: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "Day \(postcard.dayNumber)")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                    if let total = postcard.totalDays {
                        Text(verbatim: "of \(total)")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(Self.ink.opacity(0.55))
                    }
                }
                Text(verbatim: "\(postcard.flag) \(placeLine)")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineLimit(2)
                Text(verbatim: statsLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Self.ink.opacity(0.6))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(Self.ink)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let map = content.map { mapCard(map) }
        }
    }

    /// "Lisbon & Sintra, Portugal" — up to two cities, then the country.
    private var placeLine: String {
        let cities = postcard.cities.prefix(2).joined(separator: " & ")
        return cities.isEmpty ? postcard.countryName : "\(cities), \(postcard.countryName)"
    }

    /// "3 cities · 42 photos · 8 km". English on purpose, like the rest of the card.
    private var statsLine: String {
        var parts: [String] = []
        if postcard.cities.count > 1 { parts.append("\(postcard.cities.count) cities") }
        parts.append(postcard.photoCount == 1 ? "1 photo" : "\(postcard.photoCount) photos")
        if postcard.distanceKm >= 1 { parts.append("\(Int(postcard.distanceKm.rounded())) km") }
        return parts.joined(separator: " · ")
    }

    private func mapCard(_ map: MapShot) -> some View {
        let size = PostcardContent.mapSize
        return ZStack {
            Image(uiImage: map.image).resizable().scaledToFill()
            // The day's route over the map.
            Path { path in
                let points = map.markers.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            ForEach(Array(map.markers.enumerated()), id: \.offset) { _, marker in
                Circle().fill(Color.white).frame(width: 6, height: 6)
                    .position(x: marker.x * size.width, y: marker.y * size.height)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(4)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
        .rotationEffect(.degrees(2))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            LogoMark(color: Self.ink.opacity(0.6)).frame(width: 12, height: 12)
            Text(verbatim: "Made with Photrail")
                .font(.system(size: 11, weight: .semibold))
            Text(verbatim: "· travel history, automatically")
                .font(.system(size: 11))
        }
        .foregroundStyle(Self.ink.opacity(0.55))
    }
}

/// One wavy cancellation line of the postmark.
private struct Wave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waves = 3
        let step = rect.width / CGFloat(waves * 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for i in 0..<(waves * 2) {
            let x = rect.minX + step * CGFloat(i + 1)
            let control = CGPoint(x: x - step / 2, y: rect.midY + (i.isMultiple(of: 2) ? -3 : 3))
            path.addQuadCurve(to: CGPoint(x: x, y: rect.midY), control: control)
        }
        return path
    }
}
