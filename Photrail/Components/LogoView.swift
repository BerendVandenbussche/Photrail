import SwiftUI

/// Photrail brand mark — a flowing "trail" that starts at a journey dot, curves
/// upward, and ends in a location node. Geometric, monochrome-safe, and readable
/// down to ~24px. Drawn entirely as vectors so it scales without raster artifacts.
///
/// The shape is defined in a unit square and stroked relative to the frame, so the
/// same component works for the in-app header, share cards, widgets, and the icon.

/// The curved trail path (just the line — dots are drawn by `LogoMark`).
struct LogoTrail: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: p(0.22, 0.80))
        path.addCurve(to: p(0.78, 0.24),
                      control1: p(0.30, 0.30),
                      control2: p(0.70, 0.72))
        return path
    }
}

/// The full mark: trail + start dot + end (location) node. Tints with `color`.
struct LogoMark: View {
    var color: Color = .white
    /// When true, the trail is slightly lighter than the node for a 2-tone look.
    var twoTone: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let lineWidth = side * 0.12
            let startR = side * 0.05
            let nodeR = side * 0.095

            ZStack {
                LogoTrail()
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .foregroundStyle(color.opacity(twoTone ? 0.55 : 1))

                Circle()
                    .fill(color.opacity(twoTone ? 0.55 : 1))
                    .frame(width: startR * 2, height: startR * 2)
                    .position(x: 0.22 * side, y: 0.80 * side)

                Circle()
                    .fill(color)
                    .frame(width: nodeR * 2, height: nodeR * 2)
                    .position(x: 0.78 * side, y: 0.24 * side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Brand mark inside the gradient "tile" — matches the app icon. Use for headers
/// and watermarks where a self-contained badge looks better than a bare mark.
struct LogoBadge: View {
    var size: CGFloat = 32
    var cornerRadiusRatio: CGFloat = 0.26

    private static let top = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let bottom = Color(red: 0.22, green: 0.13, blue: 0.42)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * cornerRadiusRatio, style: .continuous)
                .fill(LinearGradient(colors: [Self.top, Self.bottom],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            LogoMark(color: .white)
                .padding(size * 0.22)
        }
        .frame(width: size, height: size)
    }
}

/// Mark + wordmark, for headers and onboarding.
struct LogoLockup: View {
    var size: CGFloat = 30
    var color: Color = .primary

    var body: some View {
        HStack(spacing: size * 0.32) {
            LogoBadge(size: size)
            Text("Photrail")
                .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

#Preview("Mark scales") {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            LogoBadge(size: 24)
            LogoBadge(size: 32)
            LogoBadge(size: 64)
            LogoBadge(size: 96)
        }
        LogoLockup(size: 34)
        HStack(spacing: 24) {
            LogoMark(color: .primary).frame(width: 60, height: 60)
            LogoMark(color: .white).frame(width: 60, height: 60)
                .padding(12).background(Color.black)
        }
        LogoLockup(size: 30, color: .white)
            .padding()
            .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
    }
    .padding()
}
