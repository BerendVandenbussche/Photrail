import SwiftUI
import CoreLocation

/// A shareable poster of the whole world with every country you've visited lit up.
///
/// Built as layers, back to front — night sky, stars, graticule, ghosted coastline, then your
/// countries glowing on top — so the places you've been are the only bright thing on the card.
///
/// Takes plain data and does no loading of its own: `ImageRenderer` snapshots a view
/// synchronously, so everything must already be in memory by the time this is drawn.
struct WorldPosterCardView: View {
    /// Visited countries, by ISO code — used to pick which borders to fill and in what colour.
    let visitedCodes: [String]
    /// Coastline polylines in raw lon/lat (`CGPoint(x: lon, y: lat)`), from `WorldOutline`.
    let coastline: [[CGPoint]]
    /// Border rings per visited country, already simplified and split at the antimeridian.
    let borderRings: [String: [[CLLocationCoordinate2D]]]
    let profileEmoji: String
    let title: String

    /// Same 9:16 canvas as every other share card, so the standard 3× render path gives
    /// 1080×1920.
    static let canvasSize = CGSize(width: 360, height: 640)

    private static let skyTop = Color(red: 0.03, green: 0.04, blue: 0.10)
    private static let skyMid = Color(red: 0.08, green: 0.05, blue: 0.18)
    private static let accent = Color(red: 0.6, green: 0.55, blue: 1.0)

    private let band = PosterMapGeometry.CropBand.populated

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.skyTop, Self.skyMid, .black],
                           startPoint: .top, endPoint: .bottom)

            PosterStarField()
                .opacity(0.7)

            mapLayer
                // The map sits a little above centre, leaving the lower third for the title.
                .offset(y: -40)

            // Keeps the type off the busiest part of the map.
            LinearGradient(colors: [.clear, .black.opacity(0.55), .black.opacity(0.85)],
                           startPoint: .center, endPoint: .bottom)

            VStack {
                Spacer()
                titleBlock
                footer
            }
            .padding(28)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        // Share cards stay English, matching every other card in the app.
        .environment(\.locale, Locale(identifier: "en_US"))
    }

    /// Blows the map up beyond the card width so it bleeds off both edges — a full-bleed map
    /// reads as a poster, a letterboxed one reads as a screenshot.
    private var mapScale: CGFloat { 1.35 }

    // MARK: - Map

    private var mapLayer: some View {
        Canvas { context, size in
            drawGraticule(in: &context, size: size)
            drawCoastline(in: &context, size: size)
            drawVisitedCountries(in: &context, size: size)
        }
        // Laid out at the card's own width, then scaled up purely visually. `scaleEffect`
        // doesn't change the reported size, so the bleed can't widen the enclosing ZStack
        // and drag the title text off the card with it.
        .frame(width: Self.canvasSize.width,
               height: Self.canvasSize.width * band.aspectRatio)
        .scaleEffect(mapScale)
        // NB: no `.drawingGroup()` — it is Metal-backed and can rasterise blank inside
        // `ImageRenderer`, which is exactly how this card gets exported.
    }

    private func point(lat: Double, lon: Double, size: CGSize) -> CGPoint {
        PosterMapGeometry.project(latitude: lat, longitude: lon, in: size, band: band)
    }

    /// Faint lat/lon lines. Cheap, and they make the card read as cartography rather than
    /// a random blob of shapes.
    private func drawGraticule(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        for lon in stride(from: -180.0, through: 180.0, by: 30) {
            path.move(to: point(lat: band.maxLat, lon: lon, size: size))
            path.addLine(to: point(lat: band.minLat, lon: lon, size: size))
        }
        for lat in stride(from: -60.0, through: 80.0, by: 30) {
            path.move(to: point(lat: lat, lon: -180, size: size))
            path.addLine(to: point(lat: lat, lon: 180, size: size))
        }
        context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.4)
    }

    /// Every coastline in the world, ghosted — the unvisited world is present but quiet.
    /// Same two-pass treatment as the reveal animation: a wide cyan glow under a crisp line.
    private func drawCoastline(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        for line in coastline {
            var drawing = false
            var previousLon = 0.0
            for coord in line {
                let projected = point(lat: coord.y, lon: coord.x, size: size)
                // A jump across the antimeridian must break the stroke, not cross the map.
                if drawing && abs(coord.x - previousLon) > 180 { drawing = false }
                if drawing {
                    path.addLine(to: projected)
                } else {
                    path.move(to: projected)
                    drawing = true
                }
                previousLon = coord.x
            }
        }
        context.stroke(path, with: .color(.cyan.opacity(0.10)), lineWidth: 2.0)
        context.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 0.5)
    }

    /// The countries you've been to, filled and glowing.
    ///
    /// The glow is faked with concentric strokes rather than `.blur()`, which is unreliable
    /// inside `ImageRenderer` — and this way it costs nothing and renders identically on
    /// screen and in the export.
    private func drawVisitedCountries(in context: inout GraphicsContext, size: CGSize) {
        for code in visitedCodes {
            guard let rings = borderRings[code], !rings.isEmpty else { continue }
            let color = CountryPalette.color(for: code)

            var path = Path()
            for ring in rings {
                guard let first = ring.first else { continue }
                path.move(to: point(lat: first.latitude, lon: first.longitude, size: size))
                for coord in ring.dropFirst() {
                    path.addLine(to: point(lat: coord.latitude, lon: coord.longitude, size: size))
                }
                path.closeSubpath()
            }

            // Outer glow → fill → crisp edge.
            context.stroke(path, with: .color(color.opacity(0.18)), lineWidth: 5)
            context.stroke(path, with: .color(color.opacity(0.30)), lineWidth: 2.5)
            context.fill(path, with: .color(color.opacity(0.55)))
            context.stroke(path, with: .color(color.opacity(0.95)), lineWidth: 0.7)
        }
    }

    // MARK: - Type

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(profileEmoji)
                .font(.system(size: 40))

            Text(title)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            LogoMark(color: Self.accent)
                .frame(width: 13, height: 13)
            Text("Made with Photrail")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("· travel history, automatically")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
        .padding(.top, 18)
    }
}

// MARK: - Stars

/// Deterministic starfield — the same positions every render, so a re-share produces an
/// identical image rather than a subtly different one.
private struct PosterStarField: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<140 {
                let hx = Double((i &* 73 &+ 17) % 1000) / 1000
                let hy = Double((i &* 149 &+ 41) % 1000) / 1000
                let hr = Double((i &* 37 &+ 7) % 100) / 100
                let radius = 0.4 + hr * 1.3
                let rect = CGRect(x: hx * size.width, y: hy * size.height,
                                  width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect),
                             with: .color(.white.opacity(0.25 + hr * 0.5)))
            }
        }
    }
}
