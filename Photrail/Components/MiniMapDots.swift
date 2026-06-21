import SwiftUI

/// A compact, decorative "map" — visited countries as equirectangular-projected dots.
/// Purely visual; communicates travel activity at a glance for slides and share cards.
struct MiniMapDots: View {
    let pins: [GeoPhoto.Coordinate]
    var color: Color = .white
    var dotSize: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(pins.enumerated()), id: \.offset) { _, pin in
                    let x = (pin.longitude + 180) / 360 * geo.size.width
                    let y = (90 - pin.latitude) / 180 * geo.size.height
                    Circle()
                        .fill(color)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: x, y: y)
                }
            }
        }
    }
}
