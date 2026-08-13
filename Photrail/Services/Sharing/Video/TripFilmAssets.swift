import CoreLocation
import MapKit
import Photos
import UIKit

/// Everything the trip film needs — photos *and* map images — fetched once before rendering.
///
/// Same contract as `RecapFilmAssets`: the renderer redraws the card hundreds of times, so
/// anything fetched inside that loop would put an iCloud round-trip, or a map tile download, on
/// every frame. Every field is optional and the film degrades scene by scene — a map that
/// couldn't be snapshotted falls back to the vector treatment, a photo that isn't on the device
/// leaves the scene's gradient showing. Neither leaves a hole in the video.
struct TripFilmAssets {
    var cover: UIImage?
    /// One per entry in `stops`, same order. May be nil.
    var stopShots: [UIImage?] = []
    var trackShot: UIImage?
    var wonderShot: UIImage?
    /// Photos for the closing montage.
    var shots: [UIImage] = []

    /// The stops the film actually gives a scene to, in chronological order.
    var stops: [Trip.TripStop] = []
    /// The workout the track scene retraces, if the trip recorded one worth drawing.
    var chapter: WorkoutChapter?
    /// The wonder the trip is proudest of, resolved to its catalogue entry so the scene has a
    /// coordinate to point a camera at.
    var wonder: Wonder?
    /// The chapter's route, simplified to what a 360-point-wide map can show.
    var route: [CLLocationCoordinate2D] = []

    var wideMap: MapShot?
    /// One per entry in `stops`, same order. May be nil.
    var stopMaps: [MapShot?] = []
    var trackMap: MapShot?
    var wonderMap: MapShot?
    /// Coastline polylines, loaded **only** when the wide snapshot failed — offline, it's the
    /// difference between a route on a recognisable world and a route on a blank field.
    var outline: [[CGPoint]] = []

    static let empty = TripFilmAssets()

    // MARK: - Geometry the film and the loader have to agree on

    /// Full-bleed scenes are drawn at the export resolution; anything larger is memory carried
    /// for the whole render with nothing to show for it.
    static let fullBleed = CGSize(width: 1080, height: 1920)
    /// Inset photo cards are a third of the frame — they never need full-bleed pixels.
    static let insetPhoto = CGSize(width: 660, height: 880)
    static let montagePhoto = CGSize(width: 810, height: 1440)

    /// Map sizes are in **points**, matching the 360×640 design canvas the card is laid out in.
    static let wideMapSize = CGSize(width: 360, height: 640)
    static let stopMapSize = CGSize(width: 300, height: 320)
    /// 360 rather than 400 tall: these scenes carry the most type under them, and the extra
    /// 40pt is what keeps a long landmark name clear of the brand mark.
    static let trackMapSize = CGSize(width: 320, height: 360)
    static let wonderMapSize = CGSize(width: 320, height: 360)
    /// The wide map is the one scene that scales its image up during playback, so it asks for
    /// more than the export's 3× — a zoom into a 3× raster goes soft exactly where the detail
    /// matters. The rest sit at export resolution, which at ~6 MB apiece is worth not doubling.
    static let zoomingMapScale: CGFloat = 4
    static let mapScale: CGFloat = 3

    /// Three stops is what a 25-second film can give a scene each without the middle turning
    /// into a list. A wonder takes one of those slots rather than adding to the running time —
    /// "you stood at the Colosseum" beats a third city card, and the film stays ~25 seconds.
    static let maxStops = 3
    static let maxStopsWithWonder = 2
    static let maxShots = 6

    // MARK: - Loading

    @MainActor
    static func load(for trip: Trip, insights: TripInsights?) async -> TripFilmAssets {
        var assets = TripFilmAssets()

        assets.wonder = pickWonder(from: trip)

        // The busiest stops make the film, but they're replayed in the order they happened —
        // a film that jumps around the trip stops reading as a journey.
        assets.stops = trip.stops
            .sorted { $0.photoCount > $1.photoCount }
            .prefix(assets.wonder == nil ? maxStops : maxStopsWithWonder)
            .sorted { $0.firstVisit < $1.firstVisit }

        assets.chapter = pickChapter(from: insights, trip: trip)
        if let chapter = assets.chapter {
            let raw = chapter.route.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            // A recorded route can run to thousands of samples; at this size most of them land
            // on the same pixel. ~11 m of tolerance keeps every real turn.
            assets.route = PosterMapGeometry.simplify(raw, tolerance: 0.0001)
        }

        // Photos. The cover reuses whatever the trip already decided on — never a fresh
        // `PhotoCurator` pass, which is two Vision requests per candidate over the trip's
        // *whole* photo list and would take minutes on a big trip.
        assets.cover = await image(TripCoverStore.coverID(for: trip.id) ?? trip.photoIDs.first,
                                   size: fullBleed)

        var stopShots: [UIImage?] = []
        for stop in assets.stops {
            stopShots.append(await image(stop.photoIDs.first, size: insetPhoto))
        }
        assets.stopShots = stopShots

        assets.trackShot = await image(assets.chapter?.photoIDs.first, size: insetPhoto)
        assets.wonderShot = await image(await wonderPhotoID(for: assets.wonder, in: trip),
                                        size: insetPhoto)

        for id in montageIDs(for: trip) {
            if let image = await image(id, size: montagePhoto) { assets.shots.append(image) }
        }

        // Maps last: by now the expensive photo work is done, and if the snapshots time out the
        // film still has everything else it needs.
        await assets.loadMaps(for: trip)
        return assets
    }

    /// Photos spread evenly across the trip rather than curated.
    ///
    /// `trip.photoIDs` is already chronological, so taking an even stride across it lands one
    /// photo from roughly each phase of the trip — a montage that walks through the trip instead
    /// of six shots of the same afternoon. Curation would be better and costs far too much here.
    private static func montageIDs(for trip: Trip) -> [String] {
        let ids = trip.photoIDs
        guard ids.count > maxShots else { return ids }
        return (0..<maxShots).map { ids[Int(Double($0) * Double(ids.count - 1) / Double(maxShots - 1))] }
    }

    /// A photo that actually shows the wonder, via the same cached pick every other surface uses
    /// — so the film, the trip's wonder row and the wonder detail page can't disagree.
    ///
    /// Note this is a different animal from the `bestPhotos` sweep the *cover* deliberately
    /// avoids: that one runs uncapped over the trip's entire photo list, this one over at most
    /// twelve, once per wonder ever.
    private static func wonderPhotoID(for wonder: Wonder?, in trip: Trip) async -> String? {
        guard let wonder, let hit = trip.wonders.first(where: { $0.id == wonder.id }) else { return nil }
        return await WonderCover.resolve(wonderID: wonder.id,
                                         candidates: hit.photoIDs.isEmpty
                                             ? [hit.photoID].compactMap { $0 } : hit.photoIDs)
    }

    /// The wonder worth a scene. One of the official New 7 Wonders always wins — that's the
    /// flex — and among equals the one you photographed most is the one you actually stood at.
    ///
    /// Resolved back to the catalogue entry because `Trip.WonderHit` carries a name and a photo
    /// but no coordinate, and the scene needs somewhere to point a camera.
    private static func pickWonder(from trip: Trip) -> Wonder? {
        let hits = trip.wonders
        guard !hits.isEmpty else { return nil }
        let ranked = hits.sorted {
            ($0.isOfficial ? 0 : 1, $0.photoID == nil ? 1 : 0) < ($1.isOfficial ? 0 : 1, $1.photoID == nil ? 1 : 0)
        }
        for hit in ranked {
            if let wonder = WonderCatalog.all.first(where: { $0.id == hit.id }) { return wonder }
        }
        return nil
    }

    /// The workout worth retracing: the longest recorded route, of whatever kind the trip was
    /// actually about.
    ///
    /// The activity comes from `TripShareTheme.decide` — the same call that themes the still
    /// share card — so a ski trip retraces a ski run and a hiking trip retraces a hike, and the
    /// two artefacts agree about what the trip was.
    ///
    /// When no activity dominates (the theme is `.standard`, or Health is off) it falls back to
    /// the longest route of *any* kind. A single long walk is still the shape of a day, and
    /// dropping it because walking is "too ambient to define a trip" — true for choosing a
    /// palette — would throw away the one scene that traces where you actually went.
    private static func pickChapter(from insights: TripInsights?, trip: Trip) -> WorkoutChapter? {
        let candidates = (insights?.workoutChapters ?? []).filter { $0.route.count > 2 }
        guard !candidates.isEmpty else { return nil }

        let themed = TripShareTheme.decide(trip: trip, insights: insights).kind
        let preferred = themed == .standard
            ? []
            : candidates.filter { TripShareTheme.kind(forActivityKey: $0.activityKey) == themed }

        return (preferred.isEmpty ? candidates : preferred)
            .max { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }
    }

    private mutating func loadMaps(for trip: Trip) async {
        // The wide map carries the whole itinerary, not just the three stops with scenes —
        // it's the establishing shot, and a route that skips stops isn't the route.
        let route = trip.stops.prefix(12).map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        if !route.isEmpty {
            wideMap = await MapShotLoader.shot(
                region: MapShotLoader.region(fitting: route, padding: 0.35, minimumMeters: 40_000),
                size: Self.wideMapSize, markers: route, scale: Self.zoomingMapScale)
            // Parsing the coastline isn't free, so it's only worth it when there's no map to
            // draw the route on.
            if wideMap == nil { outline = await WorldOutline.shared.polylines() }
        }

        var maps: [MapShot?] = []
        for stop in stops {
            let centre = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
            maps.append(await MapShotLoader.shot(
                region: MapShotLoader.region(fitting: [centre], minimumMeters: 20_000),
                size: Self.stopMapSize, markers: [centre], scale: Self.mapScale))
        }
        stopMaps = maps

        if let wonder {
            let centre = CLLocationCoordinate2D(latitude: wonder.latitude, longitude: wonder.longitude)
            // Pull back far enough to hold a sprawling site, close enough that a single statue
            // still fills the frame. A steep pitch is what makes a modelled landmark read as a
            // building rather than a rooftop.
            let distance = min(max(wonder.radiusMeters * 3.5, 700), 6_000)
            // 3D tiles are heavier than flat ones, so this gets longer before it gives up.
            wonderMap = await MapShotLoader.shot(
                region: MKCoordinateRegion(center: centre,
                                           latitudinalMeters: distance,
                                           longitudinalMeters: distance),
                size: Self.wonderMapSize, scale: Self.mapScale,
                style: .landmark(pitch: 62, distance: distance), timeout: 10)
        }

        if !self.route.isEmpty {
            trackMap = await MapShotLoader.shot(
                region: MapShotLoader.region(fitting: self.route, padding: 0.25, minimumMeters: 2_500),
                size: Self.trackMapSize, markers: self.route, scale: Self.mapScale)
        }
    }

    private static func image(_ id: String?, size: CGSize) async -> UIImage? {
        guard let id,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .exact
            PHImageManager.default().requestImage(
                for: asset, targetSize: size, contentMode: .aspectFill, options: options
            ) { image, _ in
                // `.highQualityFormat` calls the handler exactly once, so there's no degraded
                // placeholder to filter — and filtering one would risk a continuation that never
                // resumes, hanging the export before it starts.
                continuation.resume(returning: image)
            }
        }
    }
}
