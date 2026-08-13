import MapKit
import UIKit

/// A pre-rendered piece of map, plus the positions of the places drawn on it.
///
/// `ImageRenderer` can't capture a live `Map` — map tiles are composited by a separate layer and
/// come out blank, the same way `Material` comes out flat grey. So the film never shows a map
/// *view*; it shows a picture of one, fetched before rendering starts exactly like the photos in
/// `TripFilmAssets`. The camera never moves — only the transform over the picture does, which is
/// what keeps the card a pure function of progress.
///
/// `markers` are stored **normalised to 0…1** rather than as raw points. The API that maps a
/// coordinate onto the raster, `MKMapSnapshotter.Snapshot.point(for:)`, lives on the snapshot
/// object and answers in that snapshot's own point space; normalising here means the film never
/// has to retain a `Snapshot` or reason about `displayScale`, and can place a pin with a plain
/// `.position(x: marker.x * width, y: marker.y * height)`.
///
/// `@unchecked Sendable` because `UIImage` is immutable once created and this value is produced in
/// one task and read in another, never mutated.
struct MapShot: @unchecked Sendable {
    let image: UIImage
    /// The requested coordinates, as 0…1 positions within the image. Same order as requested; a
    /// coordinate outside the region still resolves, to a value outside 0…1.
    let markers: [CGPoint]
}

enum MapShotLoader {

    /// How the map is drawn.
    enum Style {
        /// Flat, dark, buildings off — right for a route or a city card, where the job is to be
        /// legible rather than impressive.
        case flat
        /// A pitched camera with terrain and buildings on. This is what surfaces Apple's
        /// modelled landmarks — Christ the Redeemer, the Colosseum, the Eiffel Tower — which
        /// only exist in 3D and are simply absent from a flat map.
        ///
        /// Coverage is the catch: Apple models a limited set of famous places, and everywhere
        /// else this renders as pitched terrain with generic buildings. That still reads as a
        /// dramatic view of the site rather than as something broken, which is why the scene
        /// uses it either way.
        case landmark(pitch: Double, distance: Double)
    }

    /// Renders one map image. Returns `nil` rather than throwing — a missing map is a scene that
    /// falls back to its vector treatment, which is a normal outcome (no cached tiles and no
    /// network means no snapshot) rather than a failure worth aborting the whole film for.
    ///
    /// - Parameter scale: pixels per point. Scenes that scale the image up during playback should
    ///   ask for more than the export's 3×, so the zoom has real pixels to show.
    static func shot(region: MKCoordinateRegion,
                     size: CGSize,
                     markers: [CLLocationCoordinate2D] = [],
                     scale: CGFloat = 3,
                     style: Style = .flat,
                     timeout: Double = 6) async -> MapShot? {

        await withTaskGroup(of: MapShot?.self) { group in
            // The snapshotter is created *inside* the child task so it's never shared across
            // tasks — the race below only ever passes the finished value between them.
            group.addTask {
                await withCheckedContinuation { continuation in
                    let options = MKMapSnapshotter.Options()
                    options.size = size
                    switch style {
                    case .flat:
                        // Dark, flat and unbuilt: the film is dark throughout, and 3D buildings
                        // at city zoom turn into visual noise at the size this plays back.
                        options.region = region
                        options.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
                        options.showsBuildings = false
                    case .landmark(let pitch, let distance):
                        // A camera replaces the region entirely — pitch is what makes the
                        // modelled landmark visible rather than a footprint seen from above.
                        options.camera = MKMapCamera(lookingAtCenter: region.center,
                                                     fromDistance: distance,
                                                     pitch: pitch,
                                                     heading: 0)
                        options.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
                        options.showsBuildings = true
                    }
                    options.traitCollection = UITraitCollection { traits in
                        traits.userInterfaceStyle = .dark
                        traits.displayScale = scale
                    }

                    let snapshotter = MKMapSnapshotter(options: options)
                    snapshotter.start(with: .global(qos: .userInitiated)) { snapshot, _ in
                        guard let snapshot else {
                            continuation.resume(returning: nil)
                            return
                        }
                        let points = markers.map { coordinate -> CGPoint in
                            let point = snapshot.point(for: coordinate)
                            return CGPoint(x: point.x / max(size.width, 1),
                                           y: point.y / max(size.height, 1))
                        }
                        continuation.resume(returning: MapShot(image: snapshot.image,
                                                               markers: points))
                    }
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// A region framing every coordinate, padded by `padding` (a fraction of the span) and never
    /// tighter than `minimumMeters` across — otherwise a single stop, or two photos taken on the
    /// same street, would zoom to a region so small the map is one blank block.
    static func region(fitting coordinates: [CLLocationCoordinate2D],
                       padding: Double = 0.3,
                       minimumMeters: Double = 12_000) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                      latitudinalMeters: minimumMeters,
                                      longitudinalMeters: minimumMeters)
        }

        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude); maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude); maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)

        // Degrees per metre. Longitude converges towards the poles, so it's scaled by the
        // cosine of the centre latitude — without that, a region in Iceland comes out far
        // wider than asked for.
        let latDegreesPerMeter = 1 / 111_320.0
        let lonDegreesPerMeter = latDegreesPerMeter / max(cos(center.latitude * .pi / 180), 0.01)

        let latSpan = max((maxLat - minLat) * (1 + padding * 2), minimumMeters * latDegreesPerMeter)
        let lonSpan = max((maxLon - minLon) * (1 + padding * 2), minimumMeters * lonDegreesPerMeter)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: min(latSpan, 160), longitudeDelta: min(lonSpan, 340))
        )
    }
}
