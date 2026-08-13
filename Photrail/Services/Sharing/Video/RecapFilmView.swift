import SwiftUI

/// The shot list for a year's recap film.
///
/// Scenes are dropped when the year has nothing to put in them — a year with no new countries
/// shouldn't sit on an empty slide — so the running time is a property of the recap, not a
/// constant. Consecutive scenes overlap by `overlap` seconds and cross-dissolve through it.
struct RecapFilm {

    enum Scene: Hashable {
        case open, route, numbers, newLands, peak, shots, endCard
        /// One scene per headline trip, indexed into `recap.headlineTrips`.
        case trip(Int)
    }

    struct Cue {
        let scene: Scene
        let start: Double
        let duration: Double
        var end: Double { start + duration }
    }

    /// Long enough to read as a dissolve rather than a glitch, short enough that two scenes
    /// are never both legible at once.
    private static let overlap = 0.35

    /// The end card assembles in `endCardAssemble` and then holds for the remainder. The hold
    /// is the whole point of the scene: it's the only frame with every number on it at once,
    /// and it's what someone screenshots or reads on a loop's second pass. Lengthening the
    /// scene lengthens the hold — the assembly keeps its own pace.
    static let endCardDuration = 5.4
    static let endCardAssemble = 2.8

    let cues: [Cue]
    /// Total running time in seconds.
    let duration: Double

    init(recap: RecapModel, assets: RecapFilmAssets) {
        var cues: [Cue] = []
        var t = 0.0
        func add(_ scene: Scene, _ seconds: Double) {
            cues.append(Cue(scene: scene, start: t, duration: seconds))
            t += seconds - Self.overlap
        }

        add(.open, 2.2)
        // A single-stop year has no line to draw, so the map scene would just be a dot.
        if recap.journey.count > 1 { add(.route, 4.0) }
        add(.numbers, 2.8)
        if !recap.newCountries.isEmpty { add(.newLands, 2.4) }
        // Trimmed from 3.0s when there are two, so a two-trip year costs 2.6s rather than 3.0s
        // of extra running time. A trip scene is a photo and three lines — it reads fast.
        let tripSeconds = recap.headlineTrips.count > 1 ? 2.8 : 3.0
        for index in recap.headlineTrips.indices { add(.trip(index), tripSeconds) }
        if recap.highestAltitude != nil { add(.peak, 2.4) }
        // Under three photos it reads as a stutter, not a montage.
        if assets.shots.count >= 3 { add(.shots, 2.6) }
        add(.endCard, Self.endCardDuration)

        self.cues = cues
        self.duration = cues.last?.end ?? 1
    }

    /// Where a scene is at a given global 0…1 progress: its own 0…1 and its dissolve opacity.
    /// `nil` when the scene isn't on screen, so the caller can skip building it entirely —
    /// which matters here, because unbuilt scenes are photos not composited.
    func stage(_ scene: Scene, at progress: Double) -> (local: Double, opacity: Double)? {
        guard let index = cues.firstIndex(where: { $0.scene == scene }) else { return nil }
        let cue = cues[index]
        let t = progress * duration
        guard t >= cue.start, t <= cue.end else { return nil }

        let local = min(max((t - cue.start) / cue.duration, 0), 1)
        // The opener doesn't dissolve up — frame zero is the thumbnail a feed shows before
        // anyone presses play, and it shouldn't be a blank gradient.
        let fadeIn = index == 0 ? 1 : min(1, (t - cue.start) / Self.overlap)
        // The closer doesn't dissolve out — the film would end on nothing.
        let fadeOut = index == cues.count - 1 ? 1 : min(1, (cue.end - t) / Self.overlap)
        return (local, max(0, min(fadeIn, fadeOut)))
    }
}

/// The full "Year in Travel" film: the route you actually walked, your own photos, and the
/// numbers laid over them — ending on the shareable snapshot card.
///
/// **This view must stay a pure function of `progress`.** No `@State`, no `Date()`, no
/// unseeded randomness, and none of SwiftUI's implicit animation constructs (`TimelineView`,
/// `.phaseAnimator`, `withAnimation`, `matchedGeometryEffect`) — `ImageRenderer` can't sample
/// any of them, and the exported video would freeze on one arbitrary phase. Every animated
/// property is derived from `progress` through a `Ramp`.
///
/// Also avoided for the same reason: `Material` (renders flat grey), `.blur()` and
/// `.drawingGroup()` (unreliable inside `ImageRenderer`), and lazy containers (they can
/// decline to build content that isn't on screen yet).
///
/// Photos arrive pre-loaded in `assets` — see `RecapFilmAssets` for why fetching here would
/// be fatal.
struct RecapFilmView: View {
    let recap: RecapModel
    let assets: RecapFilmAssets
    let film: RecapFilm
    /// 0…1 across the whole film.
    let progress: Double

    /// Same canvas as every other share card, so the standard 3× path gives 1080×1920.
    static let canvasSize = CGSize(width: 360, height: 640)

    // The film is dark throughout — it's mostly photography, and a light treatment would
    // fight every frame of it. The still card keeps its theme picker.
    private static let top = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let bottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private let accent = Color(red: 0.6, green: 0.55, blue: 1.0)

    private var W: CGFloat { Self.canvasSize.width }
    private var H: CGFloat { Self.canvasSize.height }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom)

            scene(.open) { openScene(at: $0) }
            scene(.route) { routeScene(at: $0) }
            scene(.numbers) { numbersScene(at: $0) }
            scene(.newLands) { newLandsScene(at: $0) }
            ForEach(recap.headlineTrips.indices, id: \.self) { index in
                scene(.trip(index)) { tripScene(index, at: $0) }
            }
            scene(.peak) { peakScene(at: $0) }
            scene(.shots) { shotsScene(at: $0) }
            scene(.endCard) { endCardScene(at: $0) }

            watermark
        }
        .frame(width: W, height: H)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        // Share cards stay English, matching every other card in the app.
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.colorScheme, .dark)
    }

    /// Builds a scene only while it's on screen, dissolved by the film's timeline.
    @ViewBuilder
    private func scene<Content: View>(_ scene: RecapFilm.Scene,
                                      @ViewBuilder content: (Double) -> Content) -> some View {
        if let stage = film.stage(scene, at: progress) {
            content(stage.local)
                .frame(width: W, height: H)
                .opacity(stage.opacity)
        }
    }

    // MARK: - Shared furniture

    /// A full-bleed photo with a slow push, darkened enough for type to sit on it.
    /// Falls back to nothing when the photo couldn't be loaded — the gradient shows through
    /// and the scene still reads.
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
                // Weights the lower third so bottom-anchored type always has a field to sit on.
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

    /// A quiet brand mark carried through the film, so a clip that gets re-shared without the
    /// end card still says where it came from. Hidden under the end card, which brands itself.
    @ViewBuilder
    private var watermark: some View {
        if film.stage(.endCard, at: progress) == nil {
            VStack {
                Spacer()
                HStack(spacing: 5) {
                    LogoMark(color: .white.opacity(0.85)).frame(width: 12, height: 12)
                    Text("PHOTRAIL · \(String(recap.year))")
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
            backdrop(assets.opener, at: local, from: 1.16, to: 1.0, dim: 0.42)
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                Text("PHOTRAIL")
                    .font(.system(size: 13, weight: .bold)).tracking(2.4)
                    .foregroundStyle(.white.opacity(0.75))
                    .opacity(Ramp(0.04, 0.20).value(at: local))
                Text(String(recap.year))
                    .font(.system(size: 104, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(Ramp(0.10, 0.30).value(at: local))
                    .offset(y: Ramp(0.10, 0.52, easing: .spring).interpolate(26, 0, at: local))
                Text("Your Year in Travel")
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .opacity(Ramp(0.34, 0.54).value(at: local))
                    .offset(y: Ramp(0.34, 0.62).interpolate(14, 0, at: local))
                Spacer().frame(height: 110)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 34)
        }
    }

    // MARK: - 2. Route

    private func routeScene(at local: Double) -> some View {
        // The line draws through the first two thirds; the flags fill in behind it.
        let drawn = Ramp(0.14, 0.80, easing: .easeInOut).value(at: local)
        return VStack(alignment: .leading, spacing: 14) {
            eyebrow("My year on the map", at: local, ramp: Ramp(0.02, 0.16))
            headline(recap.journey.count == 1 ? "1 country,\none journey"
                                              : "\(recap.journey.count) countries,\none journey",
                     at: local, ramp: Ramp(0.08, 0.34, easing: .spring))

            RouteMap(stops: recap.journey, pins: recap.pins, drawn: drawn,
                     lineColor: .white.opacity(0.85), dotColor: .white, accent: accent)
                .frame(height: 250)
                .opacity(Ramp(0.10, 0.24).value(at: local))

            FlowLayout(spacing: 9, rowSpacing: 8) {
                ForEach(Array(recap.journey.prefix(24).enumerated()), id: \.element.id) { index, stop in
                    let share = recap.journey.count > 1
                        ? Double(index) / Double(min(recap.journey.count, 24) - 1) : 0
                    Text(stop.flag)
                        .font(.system(size: 23))
                        // Each flag lands as the line reaches its country.
                        .opacity(drawn >= share ? 1 : 0)
                        .scaleEffect(drawn >= share ? 1 : 0.6)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.top, 84)
        .padding(.bottom, 70)
    }

    // MARK: - 3. Numbers

    private func numbersScene(at local: Double) -> some View {
        ZStack {
            backdrop(assets.numbers, at: local, from: 1.0, to: 1.10, dim: 0.58)
            VStack(alignment: .leading, spacing: 22) {
                Spacer()
                eyebrow("\(String(recap.year)) in numbers", at: local, ramp: Ramp(0.02, 0.16))
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
        var rows: [(Int, String, String)] = [
            (recap.countries, "", recap.countries == 1 ? "country" : "countries")
        ]
        if recap.distanceKm >= 100 { rows.append((Int(recap.distanceKm), " km", "travelled")) }
        rows.append((recap.photos, "", "photos taken"))
        return rows
    }

    private func numberRow(_ row: (value: Int, suffix: String, label: String),
                           index: Int, at local: Double) -> some View {
        let appear = Ramp(0.16 + Double(index) * 0.13, 0.34 + Double(index) * 0.13, easing: .spring)
        let count = Ramp(0.18 + Double(index) * 0.13, 0.56 + Double(index) * 0.13, easing: .easeOut)
        return VStack(alignment: .leading, spacing: -2) {
            Text("\(counted(row.value, at: count, local: local))\(row.suffix)")
                .font(.system(size: 58, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4).lineLimit(1)
            Text(row.label.uppercased())
                .font(.system(size: 12, weight: .bold)).tracking(1.6)
                .foregroundStyle(.white.opacity(0.7))
        }
        .opacity(Ramp(appear.start, appear.start + 0.08).value(at: local))
        .offset(y: appear.interpolate(24, 0, at: local))
    }

    // MARK: - 4. New countries

    private func newLandsScene(at local: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            eyebrow("New in \(String(recap.year))", at: local, ramp: Ramp(0.02, 0.18))
            headline(recap.newCountries.count == 1 ? "1 new country\nunlocked"
                                                   : "\(recap.newCountries.count) new countries\nunlocked",
                     at: local, ramp: Ramp(0.08, 0.36, easing: .spring))
            FlowLayout(spacing: 12, rowSpacing: 12) {
                ForEach(Array(recap.newCountries.prefix(15).enumerated()), id: \.element.id) { index, badge in
                    let deal = Ramp(0.30 + Double(index) * 0.045,
                                    0.46 + Double(index) * 0.045, easing: .spring)
                    VStack(spacing: 3) {
                        Text(badge.flag).font(.system(size: 34))
                        Text(badge.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: 76)
                    .opacity(Ramp(deal.start, deal.start + 0.05).value(at: local))
                    .scaleEffect(deal.interpolate(0.5, 1.0, at: local))
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.top, 96)
        .padding(.bottom, 70)
    }

    // MARK: - 5. Headline trips

    @ViewBuilder
    private func tripScene(_ index: Int, at local: Double) -> some View {
        if recap.headlineTrips.indices.contains(index) {
            let trip = recap.headlineTrips[index]
            // The second trip pushes the other way, so two trip scenes back to back don't
            // read as the same shot twice.
            let pushIn = index.isMultiple(of: 2)
            let cover = assets.trips.indices.contains(index) ? assets.trips[index] : nil
            ZStack {
                backdrop(cover, at: local,
                         from: pushIn ? 1.0 : 1.14, to: pushIn ? 1.14 : 1.0, dim: 0.34)
                VStack(alignment: .leading, spacing: 10) {
                    Spacer()
                    eyebrow(tripEyebrow(index), at: local, ramp: Ramp(0.04, 0.20))
                    Text(trip.title)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3).minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(Ramp(0.12, 0.32).value(at: local))
                        .offset(y: Ramp(0.12, 0.50, easing: .spring).interpolate(22, 0, at: local))
                    Text(trip.subtitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .opacity(Ramp(0.34, 0.52).value(at: local))
                    // Only worth the line on the first trip; repeating it reads as a template.
                    if index == 0, let longest = recap.longestTripText {
                        Text("🧳 Longest · \(longest)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(accent)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .opacity(Ramp(0.46, 0.64).value(at: local))
                    }
                    Spacer().frame(height: 84)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
            }
        }
    }

    /// "My biggest adventure" only holds up when there's one. With two, they're billed as a
    /// pair — neither is the runner-up as far as the viewer is concerned.
    private func tripEyebrow(_ index: Int) -> String {
        guard recap.headlineTrips.count > 1 else { return "My biggest adventure" }
        return index == 0 ? "The year's big trips · 1" : "The year's big trips · 2"
    }

    // MARK: - 6. Highest point

    private func peakScene(at local: Double) -> some View {
        ZStack {
            backdrop(assets.peak, at: local, from: 1.14, to: 1.0, dim: 0.38)
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                eyebrow("Highest point reached", at: local, ramp: Ramp(0.04, 0.20))
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(counted(Int(recap.highestAltitude ?? 0),
                                 at: Ramp(0.14, 0.60, easing: .easeOut), local: local))
                        .font(.system(size: 78, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4).lineLimit(1)
                    Text("m")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(Ramp(0.12, 0.26).value(at: local))
                if let place = recap.highestAltitudePlace {
                    Text(place)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .lineLimit(2).minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(Ramp(0.44, 0.62).value(at: local))
                }
                Spacer().frame(height: 88)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - 7. Best shots

    private func shotsScene(at local: Double) -> some View {
        let shots = assets.shots
        let window = shots.isEmpty ? 1 : 1.0 / Double(shots.count)
        return ZStack {
            ForEach(Array(shots.enumerated()), id: \.offset) { index, image in
                let start = Double(index) * window
                // Each frame cuts in fast and holds; the last one rides out the dissolve into
                // the end card rather than cutting to black.
                let cutIn = Ramp(start - 0.02, start + 0.05, easing: .easeInOut).value(at: local)
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
                Text("The year's best shots".uppercased())
                    .font(.system(size: 12, weight: .bold)).tracking(1.8)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 74)
                    .opacity(Ramp(0.06, 0.20).value(at: local))
            }
        }
    }

    // MARK: - 8. End card

    private func endCardScene(at local: Double) -> some View {
        // The snapshot card assembles at its own pace, then sits finished for the rest of the
        // scene — roughly two and a half seconds of every number on screen at once.
        let assemble = RecapFilm.endCardAssemble / RecapFilm.endCardDuration
        return RecapVideoCardView(recap: recap, theme: .dark, progress: min(local / assemble, 1))
    }

    // MARK: - Helpers

    private func counted(_ target: Int, at ramp: Ramp, local: Double) -> String {
        Int((Double(target) * ramp.value(at: local)).rounded()).formatted()
    }
}

// MARK: - Route map

/// The year's journey drawn stop by stop, fitted to the countries actually visited.
///
/// Unlike `JourneyMapView` — which projects onto the whole world, right for a small card on a
/// static slide — this frames the route itself. A Belgium-to-France year is a line here rather
/// than two touching dots, and framing the route is the whole point of the scene.
private struct RouteMap: View {
    let stops: [RecapModel.JourneyStop]
    let pins: [GeoPhoto.Coordinate]
    /// 0…1 of the line drawn so far.
    let drawn: Double
    let lineColor: Color
    let dotColor: Color
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let box = Box(stops: stops, size: geo.size)
            ZStack {
                // Faint context: every country of the year, in the same projection.
                ForEach(Array(pins.enumerated()), id: \.offset) { _, pin in
                    Circle()
                        .fill(dotColor.opacity(0.16))
                        .frame(width: 3, height: 3)
                        .position(box.point(pin.latitude, pin.longitude))
                }

                let points = stops.map { box.point($0.latitude, $0.longitude) }
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .trim(from: 0, to: drawn)
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(lineColor)
                }

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    // A stop lands once the line has reached it.
                    let share = points.count > 1 ? Double(index) / Double(points.count - 1) : 0
                    let landed = drawn >= share
                    let isEnd = index == 0 || index == points.count - 1
                    Circle()
                        .fill(isEnd ? accent : dotColor)
                        .frame(width: isEnd ? 11 : 7, height: isEnd ? 11 : 7)
                        .scaleEffect(landed ? 1 : 0.1)
                        .opacity(landed ? 1 : 0)
                        .position(point)
                }
            }
        }
    }

    /// Equirectangular projection fitted to the stops, with a floor on the span so a
    /// two-city year doesn't zoom to street level, and matched to the view's aspect ratio so
    /// the route isn't stretched.
    private struct Box {
        let minLat, maxLat, minLon, maxLon: Double
        let size: CGSize

        init(stops: [RecapModel.JourneyStop], size: CGSize) {
            self.size = size
            let lats = stops.map(\.latitude), lons = stops.map(\.longitude)
            var loLat = lats.min() ?? -60, hiLat = lats.max() ?? 60
            var loLon = lons.min() ?? -120, hiLon = lons.max() ?? 120

            // Breathing room around the outermost stops.
            let padLat = max((hiLat - loLat) * 0.22, 2)
            let padLon = max((hiLon - loLon) * 0.22, 2)
            loLat -= padLat; hiLat += padLat
            loLon -= padLon; hiLon += padLon

            // Floor the span, then match the aspect ratio by growing the deficient axis.
            var latSpan = max(hiLat - loLat, 6)
            var lonSpan = max(hiLon - loLon, 6)
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
