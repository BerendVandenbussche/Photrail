import SwiftUI

/// A wall socket of one plug type (IEC letters A–O), drawn from the front: the face with its
/// holes where the prongs go, so "type G" means something to people who don't know the letters.
/// With `plug: true`, the matching plug seen from its pin side instead: metal pins where the
/// socket has holes. Simplified shapes, recognisable at icon size; not to scale.
struct SocketIcon: View {
    let type: String
    var size: CGFloat = 44
    var plug = false

    var body: some View {
        Canvas { context, canvas in
            let layout = Self.layout(for: type)
            let s = min(canvas.width, canvas.height)
            let rect = CGRect(x: (canvas.width - s) / 2, y: (canvas.height - s) / 2, width: s, height: s)
                .insetBy(dx: 1, dy: 1)

            // The Europlug (C) is a flat, narrow plug, not a round one.
            let face = (plug && type.uppercased() == "C" ? Face.capsule : layout.face).path(in: rect)
            // Light face and dark holes in both appearances, like a real (white) socket.
            context.fill(face, with: .color(Color(white: 0.94)))
            context.stroke(face, with: .color(Color(white: 0.55)), lineWidth: 1.2)

            for hole in layout.holes {
                let path = hole.path(in: rect)
                if plug {
                    switch hole.kind {
                    case .hole: // a metal pin
                        context.fill(path, with: .color(Color(white: 0.72)))
                        context.stroke(path, with: .color(Color(white: 0.3)), lineWidth: 1)
                    case .pin: // the socket's earth pin goes into a hole in the plug
                        context.fill(path, with: .color(Color(white: 0.15)))
                    case .clip:
                        context.fill(path, with: .color(Color(white: 0.55)))
                    }
                    continue
                }
                switch hole.kind {
                case .hole: context.fill(path, with: .color(Color(white: 0.15)))
                case .pin: // a prong sticking out of the socket (type E's earth pin)
                    context.fill(path, with: .color(.white))
                    context.stroke(path, with: .color(Color(white: 0.15)), lineWidth: 1.2)
                case .clip: context.fill(path, with: .color(Color(white: 0.55)))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(verbatim: "Type \(type)"))
    }

    // MARK: - Shapes

    enum Face {
        case circle, roundedSquare, hexagon, capsule

        func path(in r: CGRect) -> Path {
            switch self {
            case .circle:
                return Path(ellipseIn: r)
            case .roundedSquare:
                return Path(roundedRect: r.insetBy(dx: r.width * 0.04, dy: r.height * 0.04),
                            cornerRadius: r.width * 0.2)
            case .capsule:
                let h = r.height * 0.5
                return Path(roundedRect: CGRect(x: r.minX + r.width * 0.06, y: r.midY - h / 2,
                                                width: r.width * 0.88, height: h),
                            cornerRadius: h / 2)
            case .hexagon:
                var path = Path()
                for i in 0..<6 {
                    let angle = Double(i) * .pi / 3
                    let point = CGPoint(x: r.midX + cos(angle) * r.width / 2,
                                        y: r.midY + sin(angle) * r.height / 2)
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
                return path
            }
        }
    }

    /// One opening, in unit coordinates (0…1 across the face).
    struct Hole {
        enum Kind { case hole, pin, clip }
        enum Shape { case round(radius: Double), slot(width: Double, height: Double, degrees: Double) }

        let x: Double
        let y: Double
        let shape: Shape
        var kind: Kind = .hole

        static func round(_ x: Double, _ y: Double, _ r: Double = 0.06, kind: Kind = .hole) -> Hole {
            Hole(x: x, y: y, shape: .round(radius: r), kind: kind)
        }

        static func slot(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ degrees: Double = 0,
                         kind: Kind = .hole) -> Hole {
            Hole(x: x, y: y, shape: .slot(width: w, height: h, degrees: degrees), kind: kind)
        }

        func path(in r: CGRect) -> Path {
            let center = CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
            switch shape {
            case let .round(radius):
                let d = radius * 2 * r.width
                return Path(ellipseIn: CGRect(x: center.x - d / 2, y: center.y - d / 2, width: d, height: d))
            case let .slot(w, h, degrees):
                let size = CGSize(width: w * r.width, height: h * r.height)
                let slot = Path(roundedRect: CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size),
                                cornerRadius: min(size.width, size.height) * 0.3)
                return slot
                    .applying(CGAffineTransform(rotationAngle: degrees * .pi / 180))
                    .applying(CGAffineTransform(translationX: center.x, y: center.y))
            }
        }
    }

    struct Layout {
        let face: Face
        let holes: [Hole]
    }

    static func layout(for type: String) -> Layout {
        switch type.uppercased() {
        case "A": // two flat parallel blades, one wider (polarised)
            return Layout(face: .roundedSquare, holes: [.slot(0.37, 0.5, 0.06, 0.28), .slot(0.63, 0.5, 0.06, 0.22)])
        case "B": // A plus a round earth below
            return Layout(face: .roundedSquare, holes: [.slot(0.37, 0.4, 0.06, 0.26), .slot(0.63, 0.4, 0.06, 0.2),
                                                        .round(0.5, 0.7, 0.065)])
        case "C": // two round pins
            return Layout(face: .circle, holes: [.round(0.34, 0.5), .round(0.66, 0.5)])
        case "D", "M": // a big earth on top, two smaller below (M is the larger version)
            return Layout(face: .circle, holes: [.round(0.5, 0.3, 0.08), .round(0.3, 0.66, 0.06), .round(0.7, 0.66, 0.06)])
        case "E": // two round pins and an earth pin sticking out on top
            return Layout(face: .circle, holes: [.round(0.34, 0.52), .round(0.66, 0.52), .round(0.5, 0.24, 0.065, kind: .pin)])
        case "F": // two round pins and earth clips at the top and bottom edge
            return Layout(face: .circle, holes: [.round(0.34, 0.5), .round(0.66, 0.5),
                                                 .slot(0.5, 0.08, 0.2, 0.07, kind: .clip),
                                                 .slot(0.5, 0.92, 0.2, 0.07, kind: .clip)])
        case "G": // three rectangular blades: earth on top, two flat below
            return Layout(face: .roundedSquare, holes: [.slot(0.5, 0.3, 0.08, 0.22),
                                                        .slot(0.28, 0.66, 0.2, 0.08), .slot(0.72, 0.66, 0.2, 0.08)])
        case "H": // three round pins in a triangle
            return Layout(face: .circle, holes: [.round(0.32, 0.4), .round(0.68, 0.4), .round(0.5, 0.7)])
        case "I": // two angled blades like a roof, earth blade below
            return Layout(face: .roundedSquare, holes: [.slot(0.35, 0.38, 0.07, 0.24, 30), .slot(0.65, 0.38, 0.07, 0.24, -30),
                                                        .slot(0.5, 0.72, 0.07, 0.2)])
        case "J": // three round pins, earth a little below the middle
            return Layout(face: .hexagon, holes: [.round(0.3, 0.42), .round(0.7, 0.42), .round(0.5, 0.62)])
        case "K": // two round pins, earth below
            return Layout(face: .circle, holes: [.round(0.34, 0.42), .round(0.66, 0.42), .round(0.5, 0.7, 0.07)])
        case "L": // three round pins in a row
            return Layout(face: .roundedSquare, holes: [.round(0.28, 0.5, 0.05), .round(0.5, 0.5, 0.05), .round(0.72, 0.5, 0.05)])
        case "N": // two round pins, earth a little above
            return Layout(face: .hexagon, holes: [.round(0.32, 0.58), .round(0.68, 0.58), .round(0.5, 0.36)])
        case "O": // two round pins, earth below
            return Layout(face: .circle, holes: [.round(0.32, 0.4), .round(0.68, 0.4), .round(0.5, 0.7)])
        default:
            return Layout(face: .circle, holes: [])
        }
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(60)), count: 5), spacing: 16) {
        ForEach(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"], id: \.self) { type in
            VStack(spacing: 4) {
                SocketIcon(type: type)
                SocketIcon(type: type, plug: true)
                Text(verbatim: type).font(.caption)
            }
        }
    }
    .padding()
}
