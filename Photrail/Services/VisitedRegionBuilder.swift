import Foundation
import CoreLocation

/// Turns the scattered points you've been photographed at into a handful of closed
/// regions — so the map can shade "the parts of a country I actually saw" instead of
/// stacking one translucent circle per city (which reads as a heatmap rather than a
/// territory).
///
/// The pipeline is: group by country → cluster nearby points → convex hull per cluster →
/// push the hull outward for breathing room → clip it to the country's real borders, so
/// the shaded area stops at coastlines and frontiers instead of spilling into the sea or
/// the country next door.
enum VisitedRegionBuilder {

    /// One visited area. Usually a single shape, but clipping to a country's borders can
    /// break it into several pieces — a mainland plus the islands off it — which are still
    /// *one* region: one trip, one colour, one flag.
    struct Region: Identifiable, Sendable {
        let id: String
        /// The shapes to draw. Each is a closed ring ready for `MapPolygon`.
        let polygons: [[CLLocationCoordinate2D]]
        /// Where the cluster sits, before clipping — used to build a stable id.
        let center: CLLocationCoordinate2D
        /// The country this region belongs to, so the map can label it.
        let countryCode: String
        /// Where to put that label: the middle of this drawn shape, which after clipping
        /// can be far from the cluster's centre (e.g. a region trimmed to one coastline).
        let labelCoordinate: CLLocationCoordinate2D
        /// Rough size of the drawn shape in degrees — lets the map hide labels on slivers
        /// too small to hold one.
        let extentDegrees: Double

        // Colour comes from `CountryPalette.color(for: countryCode)` — keyed on the country
        // so every region of the same country shares one colour, on the map and the poster.
    }

    /// A visited place, tagged with the country it belongs to.
    struct Place: Sendable {
        let coordinate: CLLocationCoordinate2D
        let countryCode: String
    }

    /// Build the regions for a set of visited places.
    /// - Parameters:
    ///   - places: visited places (city coordinates + their country).
    ///   - borderRings: outer border ring(s) per ISO country code — mainland plus islands.
    ///     A country missing here is drawn unclipped.
    ///   - linkDistanceKm: places closer than this join the same region.
    ///   - paddingKm: how far the outline sits beyond the outermost points.
    ///   - mergeGapKm: regions whose *padded outlines* end up closer than this are merged
    ///     into one. Without this, two clusters can sit just past `linkDistanceKm` apart
    ///     yet render as near-touching shapes once padding is applied, which looks like a
    ///     seam rather than two territories.
    static func regions(from places: [Place],
                        borderRings: [String: [[CLLocationCoordinate2D]]] = [:],
                        linkDistanceKm: Double = 250,
                        paddingKm: Double = 60,
                        mergeGapKm: Double = 100) -> [Region] {
        // Cluster within a country, never across one: a region that spanned a border
        // couldn't be clipped to either country's shape.
        let byCountry = Dictionary(grouping: places, by: \.countryCode)

        return byCountry.flatMap { code, countryPlaces -> [Region] in
            let points = countryPlaces.map(\.coordinate)
            var clusters = cluster(points, linkDistanceKm: linkDistanceKm)
            clusters = mergeNearby(clusters, paddingKm: paddingKm, mergeGapKm: mergeGapKm)

            return clusters.flatMap { cluster -> [Region] in
                let outline = hull(cluster)
                guard !outline.isEmpty, let center = centroid(of: cluster) else { return [] }
                let padded = expand(outline, byKm: paddingKm)
                guard padded.count >= 3 else { return [] }

                // Clip the (convex) padded hull against each of the country's landmasses.
                // One cluster can yield several shapes — e.g. a coastal trip covering both
                // the mainland and an offshore island.
                let rings = borderRings[code] ?? []
                let shapes: [[CLLocationCoordinate2D]]
                if rings.isEmpty {
                    shapes = [padded]
                } else {
                    let clipped = rings.compactMap { ring -> [CLLocationCoordinate2D]? in
                        let piece = clip(subject: ring, toConvex: padded)
                        return piece.count >= 3 ? piece : nil
                    }
                    // If the hull somehow misses every landmass (bad data, tiny island),
                    // fall back to the unclipped shape rather than dropping the region.
                    shapes = clipped.isEmpty ? [padded] : clipped
                }

                // Label on the biggest piece — an island fragment shouldn't get the flag
                // while the mainland goes unlabelled.
                guard let main = shapes.max(by: { areaKm2(of: $0) < areaKm2(of: $1) }),
                      let label = centroid(of: main) else { return [] }
                let lats = main.map(\.latitude), lons = main.map(\.longitude)
                let extent = max((lats.max() ?? 0) - (lats.min() ?? 0),
                                 (lons.max() ?? 0) - (lons.min() ?? 0))

                // Position-based id: stable across rebuilds, so SwiftUI keeps each
                // region's identity (and colour) instead of reshuffling them.
                return [Region(id: String(format: "%@-%.2f-%.2f",
                                          code, center.latitude, center.longitude),
                               polygons: shapes,
                               center: center,
                               countryCode: code,
                               labelCoordinate: label,
                               extentDegrees: extent)]
            }
        }
    }

    // MARK: - Area

    /// What share of a country these regions cover, 0…1, or nil when the country's outline
    /// is unknown. Regions within a country are kept apart by the merge pass, so summing
    /// them doesn't double-count overlapping shapes.
    ///
    /// This is *the* coverage number: the Places grid's bar and the country page's readout
    /// both come through here, so they cannot drift apart.
    static func coverageShare(of regions: [Region],
                              countryRings: [[CLLocationCoordinate2D]]) -> Double? {
        let countryArea = countryRings.reduce(0) { $0 + areaKm2(of: $1) }
        guard countryArea > 0 else { return nil }
        let visitedArea = regions.reduce(0.0) { total, region in
            total + region.polygons.reduce(0) { $0 + areaKm2(of: $1) }
        }
        return min(1, visitedArea / countryArea)
    }

    /// Approximate area of a closed ring in km². Uses the shoelace formula with longitude
    /// scaled by cos(latitude), which is accurate enough for comparing a visited region to
    /// the country containing it (both shrink by the same factor).
    static func areaKm2(of ring: [CLLocationCoordinate2D]) -> Double {
        guard ring.count >= 3 else { return 0 }
        let meanLat = ring.map(\.latitude).reduce(0, +) / Double(ring.count)
        let lonScale = cos(meanLat * .pi / 180)
        let kmPerDegreeLat = 110.574
        let kmPerDegreeLon = 111.320 * lonScale

        var sum = 0.0
        var j = ring.count - 1
        for i in 0..<ring.count {
            let xi = ring[i].longitude * kmPerDegreeLon, yi = ring[i].latitude * kmPerDegreeLat
            let xj = ring[j].longitude * kmPerDegreeLon, yj = ring[j].latitude * kmPerDegreeLat
            sum += (xj * yi) - (xi * yj)
            j = i
        }
        return abs(sum) / 2
    }

    // MARK: - Clipping

    /// Sutherland–Hodgman polygon clipping: returns the part of `subject` that lies inside
    /// the **convex** polygon `clipPolygon`. Our padded hulls are convex by construction,
    /// which is exactly the case this algorithm requires — so we clip the country's border
    /// (arbitrarily shaped) against the hull, giving the visited slice of that country.
    private static func clip(subject: [CLLocationCoordinate2D],
                             toConvex clipPolygon: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard subject.count >= 3, clipPolygon.count >= 3 else { return [] }

        // Orient the clip polygon counter-clockwise so "inside" is consistently to the left
        // of each edge.
        let clipper = signedArea(clipPolygon) < 0 ? clipPolygon.reversed().map { $0 } : clipPolygon

        var output = subject
        var i = clipper.count - 1
        for j in 0..<clipper.count {
            guard !output.isEmpty else { return [] }
            let edgeStart = clipper[i], edgeEnd = clipper[j]
            i = j

            let input = output
            output = []
            var previous = input[input.count - 1]
            var previousInside = isLeft(previous, edgeStart, edgeEnd) >= 0

            for current in input {
                let currentInside = isLeft(current, edgeStart, edgeEnd) >= 0
                if currentInside {
                    if !previousInside,
                       let x = intersection(previous, current, edgeStart, edgeEnd) {
                        output.append(x)
                    }
                    output.append(current)
                } else if previousInside,
                          let x = intersection(previous, current, edgeStart, edgeEnd) {
                    output.append(x)
                }
                previous = current
                previousInside = currentInside
            }
        }
        return output
    }

    /// > 0 when `point` is left of the directed edge a→b.
    private static func isLeft(_ point: CLLocationCoordinate2D,
                               _ a: CLLocationCoordinate2D,
                               _ b: CLLocationCoordinate2D) -> Double {
        (b.longitude - a.longitude) * (point.latitude - a.latitude)
            - (b.latitude - a.latitude) * (point.longitude - a.longitude)
    }

    /// Where segment p→q crosses the infinite line a→b. Nil when they're parallel.
    private static func intersection(_ p: CLLocationCoordinate2D, _ q: CLLocationCoordinate2D,
                                     _ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D)
        -> CLLocationCoordinate2D? {
        let dxSegment = q.longitude - p.longitude, dySegment = q.latitude - p.latitude
        let dxEdge = b.longitude - a.longitude, dyEdge = b.latitude - a.latitude
        let denominator = dxSegment * dyEdge - dySegment * dxEdge
        guard abs(denominator) > 1e-12 else { return nil }
        let t = ((a.longitude - p.longitude) * dyEdge - (a.latitude - p.latitude) * dxEdge) / denominator
        return CLLocationCoordinate2D(latitude: p.latitude + t * dySegment,
                                      longitude: p.longitude + t * dxSegment)
    }

    /// Shoelace signed area — used only to detect winding direction.
    private static func signedArea(_ ring: [CLLocationCoordinate2D]) -> Double {
        var sum = 0.0
        var j = ring.count - 1
        for i in 0..<ring.count {
            sum += (ring[j].longitude * ring[i].latitude) - (ring[i].longitude * ring[j].latitude)
            j = i
        }
        return sum / 2
    }

    // MARK: - Clustering

    /// Single-linkage clustering: a point joins a cluster if it's within `linkDistanceKm`
    /// of any member, so a chain of towns along a route becomes one region.
    private static func cluster(_ points: [CLLocationCoordinate2D],
                                linkDistanceKm: Double) -> [[CLLocationCoordinate2D]] {
        var remaining = points
        var clusters: [[CLLocationCoordinate2D]] = []

        while let seed = remaining.popLast() {
            var current = [seed]
            var grew = true
            while grew {
                grew = false
                var stillRemaining: [CLLocationCoordinate2D] = []
                for candidate in remaining {
                    let near = current.contains { distanceKm($0, candidate) <= linkDistanceKm }
                    if near {
                        current.append(candidate)
                        grew = true
                    } else {
                        stillRemaining.append(candidate)
                    }
                }
                remaining = stillRemaining
            }
            clusters.append(current)
        }
        return clusters
    }

    /// Fold together clusters whose finished (padded) outlines would sit within
    /// `mergeGapKm` of each other. Each cluster grows by roughly `paddingKm` in every
    /// direction, so the visible gap is the point-to-point distance minus both paddings.
    ///
    /// Runs until nothing more merges, so a chain of near-misses collapses into a single
    /// region rather than only merging pairwise once.
    private static func mergeNearby(_ clusters: [[CLLocationCoordinate2D]],
                                    paddingKm: Double,
                                    mergeGapKm: Double) -> [[CLLocationCoordinate2D]] {
        var result = clusters
        var merged = true
        while merged {
            merged = false
            outer: for i in 0..<result.count {
                for j in (i + 1)..<result.count {
                    let gap = minDistanceKm(result[i], result[j]) - 2 * paddingKm
                    if gap <= mergeGapKm {
                        result[i].append(contentsOf: result[j])
                        result.remove(at: j)
                        merged = true
                        break outer
                    }
                }
            }
        }
        return result
    }

    /// Closest distance between any two points of the two clusters.
    private static func minDistanceKm(_ a: [CLLocationCoordinate2D],
                                      _ b: [CLLocationCoordinate2D]) -> Double {
        var best = Double.greatestFiniteMagnitude
        for p in a {
            for q in b {
                best = min(best, distanceKm(p, q))
            }
        }
        return best
    }

    // MARK: - Hull

    /// Convex hull (Andrew's monotone chain). Returns the points unchanged when there are
    /// fewer than three — `expand` gives those an area.
    private static func hull(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard points.count >= 3 else { return points }
        let sorted = points.sorted {
            $0.longitude == $1.longitude ? $0.latitude < $1.latitude : $0.longitude < $1.longitude
        }

        func cross(_ o: CLLocationCoordinate2D, _ a: CLLocationCoordinate2D,
                   _ b: CLLocationCoordinate2D) -> Double {
            (a.longitude - o.longitude) * (b.latitude - o.latitude)
                - (a.latitude - o.latitude) * (b.longitude - o.longitude)
        }

        var lower: [CLLocationCoordinate2D] = []
        for p in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }
        var upper: [CLLocationCoordinate2D] = []
        for p in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }
        lower.removeLast()
        upper.removeLast()
        let combined = lower + upper
        return combined.count >= 3 ? combined : points
    }

    // MARK: - Padding

    /// Grow an outline outward from its centroid by roughly `paddingKm`. Clusters of one or
    /// two points have no area of their own, so they're replaced by a rounded blob centred
    /// on the cluster — the polygon equivalent of the old circle, but merged with its
    /// neighbours rather than stacked on them.
    private static func expand(_ outline: [CLLocationCoordinate2D],
                               byKm paddingKm: Double) -> [CLLocationCoordinate2D] {
        guard let centroid = centroid(of: outline) else { return [] }

        if outline.count < 3 {
            // Radius covers the spread of the points plus the padding.
            let spread = outline.map { distanceKm(centroid, $0) }.max() ?? 0
            return circle(around: centroid, radiusKm: spread + paddingKm)
        }

        let latPad = paddingKm / 111.0
        return outline.map { point in
            let dLat = point.latitude - centroid.latitude
            let dLon = point.longitude - centroid.longitude
            let length = max(sqrt(dLat * dLat + dLon * dLon), 0.0001)
            let lonScale = max(cos(centroid.latitude * .pi / 180), 0.15)
            return CLLocationCoordinate2D(
                latitude: clampLat(point.latitude + (dLat / length) * latPad),
                longitude: point.longitude + (dLon / length) * (latPad / lonScale)
            )
        }
    }

    /// A smooth ring approximating a circle, used for clusters too small to have a hull.
    private static func circle(around center: CLLocationCoordinate2D,
                               radiusKm: Double,
                               segments: Int = 24) -> [CLLocationCoordinate2D] {
        let latRadius = radiusKm / 111.0
        let lonScale = max(cos(center.latitude * .pi / 180), 0.15)
        return (0..<segments).map { i in
            let angle = 2 * Double.pi * Double(i) / Double(segments)
            return CLLocationCoordinate2D(
                latitude: clampLat(center.latitude + latRadius * sin(angle)),
                longitude: center.longitude + (latRadius / lonScale) * cos(angle)
            )
        }
    }

    // MARK: - Geometry helpers

    private static func centroid(of points: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !points.isEmpty else { return nil }
        let count = Double(points.count)
        return CLLocationCoordinate2D(
            latitude: points.map(\.latitude).reduce(0, +) / count,
            longitude: points.map(\.longitude).reduce(0, +) / count
        )
    }

    private static func distanceKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) / 1000
    }

    private static func clampLat(_ value: Double) -> Double { min(85, max(-85, value)) }
}
