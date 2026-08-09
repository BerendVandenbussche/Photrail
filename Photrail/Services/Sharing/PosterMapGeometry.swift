import Foundation
import CoreGraphics
import CoreLocation

/// Map maths for the shareable world poster: an equirectangular projection cropped to the
/// populated band, plus the two clean-ups a filled world map needs — simplifying huge border
/// rings, and splitting the ones that wrap around the antimeridian.
///
/// Pure and view-free so the heavy work can run off the main actor.
enum PosterMapGeometry {

    /// The slice of the globe the poster shows. Cropping off empty Antarctica and the
    /// stretched high Arctic makes the map taller relative to its width, so it fills a 9:16
    /// frame properly instead of floating in two dead bands.
    struct CropBand {
        var minLat: Double = -58
        var maxLat: Double = 84

        static let populated = CropBand()

        /// Height-to-width ratio of the cropped map, for laying the canvas out.
        var aspectRatio: Double { (maxLat - minLat) / 360 }
    }

    /// Equirectangular projection into `size`, honouring the crop band. Points outside the
    /// band still project (to negative / overflowing y) and are simply clipped by the canvas.
    static func project(latitude: Double, longitude: Double,
                        in size: CGSize, band: CropBand = .populated) -> CGPoint {
        let x = (longitude + 180) / 360 * size.width
        let y = (band.maxLat - latitude) / (band.maxLat - band.minLat) * size.height
        return CGPoint(x: x, y: y)
    }

    // MARK: - Antimeridian

    /// Split a ring wherever it jumps across ±180°, returning one or more runs.
    ///
    /// A country spanning the antimeridian (Russia, Fiji, the USA with Alaska) has vertices
    /// at both +179° and −179°. Drawn naively those connect straight across the map, smearing
    /// a filled band over the whole world. Splitting into runs keeps each side on its own
    /// side; each run is closed independently by the renderer.
    static func splitAtAntimeridian(_ ring: [CLLocationCoordinate2D])
        -> [[CLLocationCoordinate2D]] {
        guard ring.count >= 2 else { return ring.isEmpty ? [] : [ring] }

        var runs: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = [ring[0]]

        for point in ring.dropFirst() {
            if let previous = current.last, abs(point.longitude - previous.longitude) > 180 {
                if current.count >= 3 { runs.append(current) }
                current = [point]
            } else {
                current.append(point)
            }
        }
        if current.count >= 3 { runs.append(current) }
        return runs
    }

    // MARK: - Simplification

    /// Ramer–Douglas–Peucker simplification in degree space.
    ///
    /// The bundled border data carries far more detail than a poster can show: at 1080 px
    /// wide one pixel is about a third of a degree, so a small tolerance drops most vertices
    /// with no visible change.
    static func simplify(_ points: [CLLocationCoordinate2D],
                         tolerance: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 2, tolerance > 0 else { return points }

        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        simplifySegment(points, 0, points.count - 1, tolerance, &keep)

        return zip(points, keep).compactMap { $1 ? $0 : nil }
    }

    /// Marks the vertices worth keeping between `first` and `last`.
    /// Iterative (an explicit stack) rather than recursive: some rings run to tens of
    /// thousands of points and deep recursion would risk the stack.
    private static func simplifySegment(_ points: [CLLocationCoordinate2D],
                                        _ first: Int, _ last: Int,
                                        _ tolerance: Double, _ keep: inout [Bool]) {
        var stack: [(Int, Int)] = [(first, last)]

        while let (start, end) = stack.popLast() {
            guard end > start + 1 else { continue }

            var maxDistance = 0.0
            var farthest = start

            for i in (start + 1)..<end {
                let distance = perpendicularDistance(points[i], points[start], points[end])
                if distance > maxDistance {
                    maxDistance = distance
                    farthest = i
                }
            }

            if maxDistance > tolerance {
                keep[farthest] = true
                stack.append((start, farthest))
                stack.append((farthest, end))
            }
        }
    }

    /// Distance from `point` to the line through `a` and `b`, in degrees.
    private static func perpendicularDistance(_ point: CLLocationCoordinate2D,
                                              _ a: CLLocationCoordinate2D,
                                              _ b: CLLocationCoordinate2D) -> Double {
        let dx = b.longitude - a.longitude
        let dy = b.latitude - a.latitude

        // Degenerate segment: fall back to plain point distance.
        guard abs(dx) > 1e-12 || abs(dy) > 1e-12 else {
            return hypot(point.longitude - a.longitude, point.latitude - a.latitude)
        }

        let numerator = abs(dy * point.longitude - dx * point.latitude
                            + b.longitude * a.latitude - b.latitude * a.longitude)
        return numerator / hypot(dx, dy)
    }

    // MARK: - Preparation

    /// Everything a country's outline needs before it can be drawn: split at the
    /// antimeridian, then simplified. Rings too small to matter at poster scale are dropped.
    static func prepare(rings: [[CLLocationCoordinate2D]],
                        tolerance: Double = 0.05,
                        minimumPoints: Int = 3) -> [[CLLocationCoordinate2D]] {
        rings.flatMap { splitAtAntimeridian($0) }
            .map { simplify($0, tolerance: tolerance) }
            .filter { $0.count >= minimumPoints }
    }
}
