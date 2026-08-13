import CoreLocation
import SwiftUI

/// The shot list for one trip's film.
///
/// Same shape as `RecapFilm`: scenes are dropped when the trip has nothing to put in them, so a
/// weekend city break runs short rather than sitting on empty slides. Consecutive scenes overlap
/// by `overlap` seconds and cross-dissolve through it.
struct TripFilm {

    enum Scene: Hashable {
        case open, mapDive, wonder, track, shots, numbers, endCard
        /// One scene per entry in `TripFilmAssets.stops`.
        case stop(Int)
    }

    struct Cue {
        let scene: Scene
        let start: Double
        let duration: Double
        var end: Double { start + duration }
    }

    private static let overlap = 0.35

    /// The end card assembles in `endCardAssemble` and holds for the rest — the hold is the
    /// point of the scene, since it's the one frame with every number on it at once.
    static let endCardDuration = 4.6
    static let endCardAssemble = 2.4

    let cues: [Cue]
    let duration: Double

    init(trip: Trip, assets: TripFilmAssets) {
        var cues: [Cue] = []
        var t = 0.0
        func add(_ scene: Scene, _ seconds: Double) {
            cues.append(Cue(scene: scene, start: t, duration: seconds))
            t += seconds - Self.overlap
        }

        add(.open, 2.2)
        // Nothing geocoded means nothing to frame — the establishing shot would be an empty map.
        if !trip.stops.isEmpty { add(.mapDive, 4.2) }
        for index in assets.stops.indices { add(.stop(index), 2.8) }
        // Takes a stop's slot rather than adding to the running time — see `maxStopsWithWonder`.
        if assets.wonder != nil { add(.wonder, 2.8) }
        if assets.chapter != nil, !assets.route.isEmpty { add(.track, 3.2) }
        // Under three photos it reads as a stutter, not a montage.
        if assets.shots.count >= 3 { add(.shots, 2.6) }
        add(.numbers, 2.6)
        add(.endCard, Self.endCardDuration)

        self.cues = cues
        self.duration = cues.last?.end ?? 1
    }

    /// Where a scene is at a given global 0…1 progress: its own 0…1 and its dissolve opacity.
    /// `nil` when the scene isn't on screen, so the caller can skip building it entirely.
    func stage(_ scene: Scene, at progress: Double) -> (local: Double, opacity: Double)? {
        guard let index = cues.firstIndex(where: { $0.scene == scene }) else { return nil }
        let cue = cues[index]
        let t = progress * duration
        guard t >= cue.start, t <= cue.end else { return nil }

        let local = min(max((t - cue.start) / cue.duration, 0), 1)
        let fadeIn = index == 0 ? 1 : min(1, (t - cue.start) / Self.overlap)
        let fadeOut = index == cues.count - 1 ? 1 : min(1, (cue.end - t) / Self.overlap)
        return (local, max(0, min(fadeIn, fadeOut)))
    }
}

// MARK: - The film

/// A trip, told as a ~25-second film: where you went on a real map, the stops that mattered, the
/// route you actually walked or skied, and the photos.
///
/// A pure function of `progress`, like every other exportable card — see `ShareVideoRenderer`.
/// Photos and map images arrive pre-loaded in `assets`; nothing is fetched here.
struct TripFilmView: View {
    let trip: Trip
    let assets: TripFilmAssets
    let insights: TripInsights?
    let film: TripFilm
    /// 0…1 across the whole film.
    let progress: Double

    /// Same canvas as every other share card, so the standard 3× path gives 1080×1920.
    static let canvasSize = CGSize(width: 360, height: 640)

    private static let top = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let bottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private let accent = Color(red: 0.6, green: 0.55, blue: 1.0)

    private var W: CGFloat { Self.canvasSize.width }
    private var H: CGFloat { Self.canvasSize.height }

    /// Clearance kept below every scene's type for the brand mark.
    ///
    /// The card scenes stack downward from a map, so their height depends on how long a place
    /// name runs — "Rio de Janeiro" is one line, "Kampong Phluk, Siem Reap" is two — and the
    /// overflow lands exactly where the watermark sits. Reserving the space explicitly, and
    /// letting the *top* absorb the slack instead, means a long name pushes into empty sky
    /// rather than through the branding.
    private static let brandSafe: CGFloat = 54

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom)

            scene(.open) { openScene(at: $0) }
            scene(.mapDive) { mapDiveScene(at: $0) }
            ForEach(assets.stops.indices, id: \.self) { index in
                scene(.stop(index)) { stopScene(index, at: $0) }
            }
            scene(.wonder) { wonderScene(at: $0) }
            scene(.track) { trackScene(at: $0) }
            scene(.shots) { shotsScene(at: $0) }
            scene(.numbers) { numbersScene(at: $0) }
            scene(.endCard) { endCardScene(at: $0) }

            watermark
        }
        .frame(width: W, height: H)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        // Share cards stay English, matching every other card in the app.
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.colorScheme, .dark)
    }

    /// Builds a scene only while it's on screen — an unbuilt scene is a photo, and a map, not
    /// composited.
    @ViewBuilder
    private func scene<Content: View>(_ scene: TripFilm.Scene,
                                      @ViewBuilder content: (Double) -> Content) -> some View {
        if let stage = film.stage(scene, at: progress) {
            content(stage.local)
                .frame(width: W, height: H)
                .opacity(stage.opacity)
        }
    }

    // MARK: - Shared furniture

    @ViewBuilder
    private func backdrop(_ image: UIImage?, at local: Double,
                          from: Double = 1.12, to: Double = 1.0,
                          dim: Double = 0.45) -> some View {
        if let image {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: W, height: H)
                    .scaleEffect(Ramp(0, 1, easing: .linear).interpolate(from, to, at: local))
                    .clipped()
                Color.black.opacity(dim)
                LinearGradient(colors: [.clear, .black.opacity(0.75)],
                               startPoint: .center, endPoint: .bottom)
            }
        }
    }

    private func eyebrow(_ text: String, at local: Double, ramp: Ramp) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .bold)).tracking(1.8)
            .foregroundStyle(accent)
            .opacity(ramp.value(at: local))
            .offset(y: ramp.interpolate(10, 0, at: local))
    }

    private func headline(_ text: String, at local: Double, ramp: Ramp, size: CGFloat = 40) -> some View {
        Text(text)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(3).minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(Ramp(ramp.start, ramp.start + (ramp.end - ramp.start) * 0.6).value(at: local))
            .offset(y: ramp.interpolate(20, 0, at: local))
    }

    /// A photo in a rounded card, used as the inset beside a map.
    @ViewBuilder
    private func photoCard(_ image: UIImage?, size: CGSize, at local: Double, ramp: Ramp) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
                .opacity(ramp.value(at: local))
                .scaleEffect(ramp.interpolate(0.88, 1, at: local))
        }
    }

    /// The brand mark carried through the film, so a clip re-shared without the end card still
    /// says where it came from. Hidden under the end card, which brands itself.
    @ViewBuilder
    private var watermark: some View {
        if film.stage(.endCard, at: progress) == nil {
            VStack {
                Spacer()
                HStack(spacing: 5) {
                    LogoMark(color: .white.opacity(0.85)).frame(width: 12, height: 12)
                    Text("PHOTRAIL")
                        .font(.system(size: 10, weight: .bold)).tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 22)
            }
            .opacity(Ramp(0.02, 0.06).value(at: progress))
        }
    }

    // MARK: - 1. Open

    private func openScene(at local: Double) -> some View {
        ZStack {
            backdrop(assets.cover, at: local, from: 1.16, to: 1.0, dim: 0.40)
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                Text(trip.englishDateRange.uppercased())
                    .font(.system(size: 13, weight: .bold)).tracking(2.0)
                    .foregroundStyle(.white.opacity(0.8))
                    .opacity(Ramp(0.04, 0.20).value(at: local))
                Text(trip.isMultiCountry ? "\(trip.flagsLine)\n\(trip.englishDisplayName)"
                                         : "\(trip.flag) \(trip.englishDisplayName)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3).minimumScaleFactor(0.45)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(Ramp(0.10, 0.30).value(at: local))
                    .offset(y: Ramp(0.10, 0.52, easing: .spring).interpolate(26, 0, at: local))
                Text("\(days) days · \(trip.photoCount.formatted()) photos")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .opacity(Ramp(0.34, 0.54).value(at: local))
                    .offset(y: Ramp(0.34, 0.62).interpolate(14, 0, at: local))
                Spacer().frame(height: 108)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 34)
        }
    }

    // MARK: - 2. The map

    /// The establishing shot: the real map, with the route drawing across it.
    ///
    /// `MKMapSnapshotter` gave us one image and the coordinates resolved into it, so the route is
    /// welded to the terrain underneath it.
    ///
    /// Deliberately not scaled. This used to pull back from 1.25, which cropped the outer fifth of
    /// the image — including the bottom-leading corner where the snapshot carries Apple's Maps
    /// logo. Cropping an attribution mark isn't something to be clever about, and the scene never
    /// needed the move: the line drawing itself across a real map is the shot.
    private func mapDiveScene(at local: Double) -> some View {
        let drawn = Ramp(0.18, 0.82, easing: .easeInOut).value(at: local)
        let route = trip.stops.prefix(12).map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        return ZStack {
            ZStack {
                MapLayer(shot: assets.wideMap, coordinates: Array(route), outline: assets.outline,
                         size: Self.canvasSize, drawn: drawn, lineWidth: 2.6,
                         lineColor: .white.opacity(0.9), accent: accent, pinSize: 10)
                Color.black.opacity(0.28)
                LinearGradient(colors: [.black.opacity(0.5), .clear, .black.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
            }
            .frame(width: W, height: H)

            VStack(alignment: .leading, spacing: 10) {
                Spacer()
                eyebrow("The route", at: local, ramp: Ramp(0.04, 0.18))
                headline(trip.stops.count == 1 ? "One stop" : "\(trip.stops.count) stops",
                         at: local, ramp: Ramp(0.10, 0.34, easing: .spring), size: 38)
                if trip.routeDistanceKm >= 1 {
                    Text("\(Int(trip.routeDistanceKm).formatted()) km on the ground")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .opacity(Ramp(0.40, 0.58).value(at: local))
                }
                Spacer().frame(height: 84)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - 3–5. Stops

    @ViewBuilder
    private func stopScene(_ index: Int, at local: Double) -> some View {
        if assets.stops.indices.contains(index) {
            let stop = assets.stops[index]
            let shot = assets.stopMaps.indices.contains(index) ? assets.stopMaps[index] : nil
            let photo = assets.stopShots.indices.contains(index) ? assets.stopShots[index] : nil
            // Alternating sides, so three stops in a row don't read as the same shot three times.
            // Only the *card* swaps sides: the photo inset always overhangs the trailing corner,
            // because the leading one carries the snapshot's Apple Maps logo (see `MapShot`).
            let leading = index.isMultiple(of: 2)
            let mapSize = TripFilmAssets.stopMapSize
            let centre = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)

            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    // The slack lives at the top, so a long name grows upward into empty space.
                    Spacer(minLength: 0)

                    ZStack(alignment: .bottomTrailing) {
                        MapLayer(shot: shot, coordinates: [centre], outline: [],
                                 size: mapSize, drawn: nil, lineWidth: 0,
                                 lineColor: .clear, accent: accent, pinSize: 14)
                            .frame(width: mapSize.width, height: mapSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(.white.opacity(0.18), lineWidth: 1))
                            .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                            .opacity(Ramp(0.02, 0.18).value(at: local))

                        photoCard(photo, size: CGSize(width: 124, height: 158), at: local,
                                  ramp: Ramp(0.22, 0.44, easing: .spring))
                            .offset(x: 34, y: 46)
                    }
                    .frame(width: mapSize.width, height: mapSize.height)
                    .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)

                    // Clears the photo inset, which overhangs the map by 46pt.
                    Spacer().frame(height: 66)

                    VStack(alignment: .leading, spacing: 6) {
                        eyebrow(monthLabel(stop.firstVisit), at: local, ramp: Ramp(0.30, 0.46))
                        Text(stop.name)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2).minimumScaleFactor(0.5)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(Ramp(0.34, 0.52).value(at: local))
                            .offset(y: Ramp(0.34, 0.70, easing: .spring).interpolate(20, 0, at: local))
                        Text("\(stop.flag) \(stop.photoCount.formatted()) photos")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .opacity(Ramp(0.48, 0.64).value(at: local))
                    }
                    Spacer().frame(height: Self.brandSafe)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
            }
        }
    }

    // MARK: - 6. The wonder

    /// The one scene built from a 3D camera rather than a flat map.
    ///
    /// Apple models a set of famous landmarks — Christ the Redeemer, the Colosseum — and they
    /// exist only in the pitched, buildings-on view; a flat map shows their footprint at best.
    /// Where there's no model, the pitched terrain still reads as a dramatic view of the site.
    ///
    /// With no snapshot at all the scene falls back to the user's own photo full-bleed, which is
    /// a better failure than a dark panel where a landmark should be.
    @ViewBuilder
    private func wonderScene(at local: Double) -> some View {
        if let wonder = assets.wonder {
            let isOfficial = wonder.category == .sevenWonders
            let mapSize = TripFilmAssets.wonderMapSize

            ZStack {
                if assets.wonderMap == nil {
                    backdrop(assets.wonderShot, at: local, from: 1.14, to: 1.0, dim: 0.40)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    if assets.wonderMap != nil {
                        ZStack(alignment: .bottomTrailing) {
                            MapLayer(shot: assets.wonderMap, coordinates: [], outline: [],
                                     size: mapSize, drawn: nil, lineWidth: 0,
                                     lineColor: .clear, accent: accent, pinSize: 0)
                                .frame(width: mapSize.width, height: mapSize.height)
                                // No slow push here either: scaling up crops the corner carrying
                                // Apple's Maps logo. The 3D camera already gives this scene its
                                // depth, so it loses less than the wide map did.
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(.white.opacity(0.18), lineWidth: 1))
                                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                                .opacity(Ramp(0.02, 0.16).value(at: local))

                            photoCard(assets.wonderShot, size: CGSize(width: 112, height: 142),
                                      at: local, ramp: Ramp(0.26, 0.48, easing: .spring))
                                .offset(x: 26, y: 40)
                        }
                        .frame(width: mapSize.width, height: mapSize.height)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Clears the photo inset, which overhangs the map by 40pt.
                        Spacer().frame(height: 60)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        eyebrow(isOfficial ? "A wonder of the world" : "Landmark seen",
                                at: local, ramp: Ramp(0.04, 0.22))
                        Text("\(wonder.emoji) \(wonder.name)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            // Two lines, not three: even "Christ the Redeemer" fits, and a third
                            // line is what pushed this scene into the brand mark.
                            .lineLimit(2).minimumScaleFactor(0.45)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(Ramp(0.14, 0.34).value(at: local))
                            .offset(y: Ramp(0.14, 0.56, easing: .spring).interpolate(22, 0, at: local))
                        Text(isOfficial ? "\(wonder.flagEmoji) One of the New 7 Wonders"
                                        : "\(wonder.flagEmoji) Seen in person")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                            .opacity(Ramp(0.40, 0.58).value(at: local))
                    }
                    // The photo fallback sits its type lower, the way the other full-bleed
                    // scenes do; the map layout is already bottom-heavy.
                    Spacer().frame(height: assets.wonderMap != nil ? Self.brandSafe : 92)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
            }
        }
    }

    // MARK: - 7. The route you actually moved on (any activity, not just hikes)

    @ViewBuilder
    private func trackScene(at local: Double) -> some View {
        if let chapter = assets.chapter {
            let drawn = Ramp(0.16, 0.78, easing: .easeInOut).value(at: local)
            let mapSize = TripFilmAssets.trackMapSize

            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)

                    ZStack(alignment: .bottomTrailing) {
                        MapLayer(shot: assets.trackMap, coordinates: assets.route, outline: [],
                                 size: mapSize, drawn: drawn, lineWidth: 3.2,
                                 lineColor: accent, accent: accent, pinSize: 9)
                            .frame(width: mapSize.width, height: mapSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(.white.opacity(0.18), lineWidth: 1))
                            .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                            .opacity(Ramp(0.02, 0.16).value(at: local))

                        photoCard(assets.trackShot, size: CGSize(width: 112, height: 142), at: local,
                                  ramp: Ramp(0.26, 0.48, easing: .spring))
                            .offset(x: 26, y: 40)
                    }
                    .frame(width: mapSize.width, height: mapSize.height)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Clears the photo inset, which overhangs the map by 40pt.
                    Spacer().frame(height: 60)

                    VStack(alignment: .leading, spacing: 8) {
                        eyebrow("\(chapter.emoji) \(activityLabel(chapter.activityKey))",
                                at: local, ramp: Ramp(0.30, 0.46))
                        HStack(alignment: .lastTextBaseline, spacing: 16) {
                            ForEach(Array(trackStats(chapter).enumerated()), id: \.offset) { index, stat in
                                let appear = Ramp(0.36 + Double(index) * 0.08,
                                                  0.56 + Double(index) * 0.08, easing: .spring)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(stat.value)
                                        .font(.system(size: 32, weight: .black, design: .rounded)
                                            .monospacedDigit())
                                        .foregroundStyle(.white)
                                        .lineLimit(1).minimumScaleFactor(0.5)
                                    Text(stat.label.uppercased())
                                        .font(.system(size: 10, weight: .bold)).tracking(1.2)
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                                .opacity(Ramp(appear.start, appear.start + 0.06).value(at: local))
                                .offset(y: appear.interpolate(18, 0, at: local))
                            }
                        }
                    }
                    Spacer().frame(height: Self.brandSafe)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
            }
        }
    }

    private func trackStats(_ chapter: WorkoutChapter) -> [(value: String, label: String)] {
        var stats: [(String, String)] = []
        if let metres = chapter.distanceMeters, metres >= 100 {
            stats.append((String(format: "%.1f", metres / 1000), "km"))
        }
        stats.append((chapter.durationText, "moving"))
        if let kcal = chapter.activeEnergyKcal, kcal >= 1 {
            stats.append(("\(Int(kcal).formatted())", "kcal"))
        }
        return Array(stats.prefix(3))
    }

    /// The film speaks English like every other share card, so these don't go through the
    /// localized activity names.
    private func activityLabel(_ key: String) -> String {
        switch key {
        case "hiking":       return "On foot"
        case "skiing":       return "On the piste"
        case "snowSports", "snowboarding": return "In the snow"
        case "climbing":     return "On the wall"
        case "cycling":      return "On two wheels"
        case "running":      return "Running"
        case "walking":      return "Walking"
        case "swimming":     return "In the water"
        default:             return "Moving"
        }
    }

    // MARK: - 8. Photos

    private func shotsScene(at local: Double) -> some View {
        let shots = assets.shots
        let window = shots.isEmpty ? 1 : 1.0 / Double(shots.count)
        return ZStack {
            ForEach(Array(shots.enumerated()), id: \.offset) { index, image in
                let start = Double(index) * window
                let cutIn = Ramp(start - 0.02, start + 0.05, easing: .easeInOut).value(at: local)
                // The last frame rides out the dissolve into the next scene rather than
                // cutting to black.
                let cutOut = index == shots.count - 1
                    ? 0
                    : Ramp(start + window - 0.05, start + window + 0.02, easing: .easeInOut).value(at: local)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: W, height: H)
                    .scaleEffect(1.08 - 0.08 * min(1, max(0, (local - start) / window)))
                    .clipped()
                    .opacity(max(0, cutIn - cutOut))
            }
            VStack {
                Spacer()
                Text("The trip, in pictures".uppercased())
                    .font(.system(size: 12, weight: .bold)).tracking(1.8)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 74)
                    .opacity(Ramp(0.06, 0.20).value(at: local))
            }
        }
    }

    // MARK: - 9. Numbers

    private func numbersScene(at local: Double) -> some View {
        ZStack {
            backdrop(assets.cover, at: local, from: 1.0, to: 1.10, dim: 0.62)
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                eyebrow("The trip in numbers", at: local, ramp: Ramp(0.02, 0.16))
                ForEach(Array(numberRows.enumerated()), id: \.offset) { index, row in
                    numberRow(row, index: index, at: local)
                }
                Spacer().frame(height: 90)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
        }
    }

    private var numberRows: [(value: Int, suffix: String, label: String)] {
        var rows: [(Int, String, String)] = [(days, "", days == 1 ? "day away" : "days away")]
        if trip.cities.count > 1 { rows.append((trip.cities.count, "", "places")) }
        if trip.routeDistanceKm >= 1 { rows.append((Int(trip.routeDistanceKm), " km", "on the ground")) }
        rows.append((trip.photoCount, "", "photos taken"))
        if let peak = trip.highestAltitude, peak >= 1000 {
            rows.append((Int(peak), " m", "highest point"))
        }
        // Four rows is what fits before the type has to shrink to stay on the card.
        return Array(rows.prefix(4))
    }

    private func numberRow(_ row: (value: Int, suffix: String, label: String),
                           index: Int, at local: Double) -> some View {
        let appear = Ramp(0.16 + Double(index) * 0.13, 0.34 + Double(index) * 0.13, easing: .spring)
        let count = Ramp(0.18 + Double(index) * 0.13, 0.56 + Double(index) * 0.13, easing: .easeOut)
        return VStack(alignment: .leading, spacing: -2) {
            Text("\(counted(row.value, at: count, local: local))\(row.suffix)")
                .font(.system(size: 54, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4).lineLimit(1)
            Text(row.label.uppercased())
                .font(.system(size: 12, weight: .bold)).tracking(1.6)
                .foregroundStyle(.white.opacity(0.7))
        }
        .opacity(Ramp(appear.start, appear.start + 0.08).value(at: local))
        .offset(y: appear.interpolate(24, 0, at: local))
    }

    // MARK: - 10. End card

    /// The film ends on the exact card the "Share image" button exports. A still view is
    /// trivially a pure function of progress, so it needs no animated variant — it just arrives
    /// and holds.
    private func endCardScene(at local: Double) -> some View {
        let assemble = TripFilm.endCardAssemble / TripFilm.endCardDuration
        let t = min(local / assemble, 1)
        return TripShareCardView(trip: trip, cover: assets.cover, insights: insights)
            .opacity(Ramp(0, 0.35).value(at: t))
            .scaleEffect(Ramp(0, 0.6, easing: .spring).interpolate(1.06, 1.0, at: t))
    }

    // MARK: - Helpers

    private var days: Int {
        (Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0) + 1
    }

    private func counted(_ target: Int, at ramp: Ramp, local: Double) -> String {
        Int((Double(target) * ramp.value(at: local)).rounded()).formatted()
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Map layer

/// A map image with the route and its stops drawn on top, or — when the snapshot never arrived —
/// the same route drawn on a plain field.
///
/// The fallback matters more than it looks. Under "Optimize iPhone Storage" a photo can be
/// missing; on a plane, *every* map is missing. A scene that quietly loses its terrain still
/// tells you where you went; a black rectangle doesn't.
private struct MapLayer: View {
    let shot: MapShot?
    /// Used to project by hand when `shot` is nil.
    let coordinates: [CLLocationCoordinate2D]
    /// Coastline polylines (x = lon, y = lat) for the fallback at wide zoom. Empty otherwise —
    /// a coastline is no help when the frame is 20 km across.
    let outline: [[CGPoint]]
    let size: CGSize
    /// 0…1 of the line drawn so far, or nil for a scene with pins but no route.
    let drawn: Double?
    let lineWidth: CGFloat
    let lineColor: Color
    let accent: Color
    let pinSize: CGFloat

    var body: some View {
        ZStack {
            if let shot {
                Image(uiImage: shot.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.22),
                                        Color(red: 0.06, green: 0.07, blue: 0.14)],
                               startPoint: .top, endPoint: .bottom)
                Canvas { context, canvasSize in
                    guard !outline.isEmpty else { return }
                    let box = Box(coordinates: coordinates, size: canvasSize)
                    var path = Path()
                    for line in outline {
                        var started = false
                        for point in line {
                            let projected = box.point(point.y, point.x)
                            if started { path.addLine(to: projected) }
                            else { path.move(to: projected); started = true }
                        }
                    }
                    context.stroke(path, with: .color(.white.opacity(0.16)), lineWidth: 0.6)
                }
            }

            let points = resolved
            if let drawn, points.count > 1 {
                Path { path in
                    path.move(to: points[0])
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .trim(from: 0, to: drawn)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundStyle(lineColor)
                .shadow(color: .black.opacity(0.6), radius: 3)
            }

            ForEach(Array(pins(points).enumerated()), id: \.offset) { _, pin in
                ZStack {
                    Circle().fill(.white).frame(width: pinSize + 4, height: pinSize + 4)
                    Circle().fill(accent).frame(width: pinSize, height: pinSize)
                }
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .opacity(pin.landed ? 1 : 0)
                .scaleEffect(pin.landed ? 1 : 0.2)
                .position(pin.point)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Points in this layer's own space — straight from the snapshot when we have one, projected
    /// by hand when we don't.
    private var resolved: [CGPoint] {
        if let shot, shot.markers.count == coordinates.count, !shot.markers.isEmpty {
            return shot.markers.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        }
        let box = fallbackBox(size)
        return coordinates.map { box.point($0.latitude, $0.longitude) }
    }

    /// Only the ends of a recorded route get a pin — one dot per GPS sample would be a smear.
    /// A stop list gets one on every stop, landing as the line reaches it.
    private func pins(_ points: [CGPoint]) -> [(point: CGPoint, landed: Bool)] {
        guard !points.isEmpty else { return [] }
        guard let drawn else { return points.map { ($0, true) } }
        if points.count > 24 {
            return [(points[0], drawn > 0.01), (points[points.count - 1], drawn >= 0.999)]
        }
        return points.enumerated().map { index, point in
            let share = points.count > 1 ? Double(index) / Double(points.count - 1) : 0
            return (point, drawn >= share)
        }
    }

    private func fallbackBox(_ size: CGSize) -> Box {
        Box(coordinates: coordinates, size: size)
    }

    /// Equirectangular projection fitted to the coordinates, aspect-matched so the route isn't
    /// stretched. Only used when there's no snapshot to register against.
    private struct Box {
        let minLat, maxLat, minLon, maxLon: Double
        let size: CGSize

        init(coordinates: [CLLocationCoordinate2D], size: CGSize) {
            self.size = size
            let lats = coordinates.map(\.latitude), lons = coordinates.map(\.longitude)
            var loLat = lats.min() ?? -60, hiLat = lats.max() ?? 60
            var loLon = lons.min() ?? -120, hiLon = lons.max() ?? 120

            let padLat = max((hiLat - loLat) * 0.28, 0.4)
            let padLon = max((hiLon - loLon) * 0.28, 0.4)
            loLat -= padLat; hiLat += padLat
            loLon -= padLon; hiLon += padLon

            var latSpan = max(hiLat - loLat, 0.8)
            var lonSpan = max(hiLon - loLon, 0.8)
            let target = size.height > 0 ? Double(size.width / size.height) : 1
            if lonSpan / latSpan < target { lonSpan = latSpan * target }
            else { latSpan = lonSpan / target }

            let midLat = (loLat + hiLat) / 2, midLon = (loLon + hiLon) / 2
            minLat = midLat - latSpan / 2; maxLat = midLat + latSpan / 2
            minLon = midLon - lonSpan / 2; maxLon = midLon + lonSpan / 2
        }

        func point(_ lat: Double, _ lon: Double) -> CGPoint {
            let x = (lon - minLon) / max(maxLon - minLon, 0.0001) * Double(size.width)
            let y = (maxLat - lat) / max(maxLat - minLat, 0.0001) * Double(size.height)
            return CGPoint(x: x, y: y)
        }
    }
}
