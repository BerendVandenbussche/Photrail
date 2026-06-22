import SwiftUI

/// Draws the year's trips as a connected route — dots in chronological order joined
/// by a line. Equirectangular projection; decorative, not interactive.
struct JourneyMapView: View {
    let stops: [RecapModel.JourneyStop]
    var lineColor: Color = .white.opacity(0.55)
    var dotColor: Color = .white

    private func point(_ stop: RecapModel.JourneyStop, in size: CGSize) -> CGPoint {
        CGPoint(x: (stop.longitude + 180) / 360 * size.width,
                y: (90 - stop.latitude) / 180 * size.height)
    }

    var body: some View {
        GeometryReader { geo in
            let pts = stops.map { point($0, in: geo.size) }
            ZStack {
                // faint backdrop of all countries for context
                MiniMapDots(pins: stops.map { .init(latitude: $0.latitude, longitude: $0.longitude) },
                            color: dotColor.opacity(0.18), dotSize: 3)

                // connecting route
                if pts.count > 1 {
                    Path { path in
                        path.move(to: pts[0])
                        for p in pts.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 4]))
                    .foregroundStyle(lineColor)
                }

                // stop dots
                ForEach(Array(pts.enumerated()), id: \.offset) { idx, p in
                    Circle()
                        .fill(dotColor)
                        .frame(width: idx == 0 || idx == pts.count - 1 ? 9 : 6,
                               height: idx == 0 || idx == pts.count - 1 ? 9 : 6)
                        .position(p)
                }
            }
        }
    }
}
