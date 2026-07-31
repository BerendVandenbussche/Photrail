import SwiftUI

/// The one-time, post-onboarding "wow" — the moment that shows a new user their whole travel
/// life, drawn from their own photos, and sells the app before they've tapped anything.
///
/// Two phases. **Loading**: a lightweight progress ring waits for the scan to resolve every
/// country (the long city-geocoding tail keeps running in the background). **Animating**: on a
/// frozen snapshot of those countries, a dark space sky and softly glowing world host each
/// country igniting oldest-first — pulse ring, flag, and glowing flight-path arcs — while a
/// counter ticks up to the finale + CTA. Splitting the phases keeps the heavy animation off the
/// main actor while the scan is busy. Built on the same equirectangular projection as
/// `MiniMapDots`, independent of the MapKit map so it can be fully choreographed.
struct MapRevealView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One country to light up. A local snapshot so `body` never reads `appVM` (which updates
    /// constantly during a scan) — the reveal renders purely from `@State`, so the scan and the
    /// animation don't fight over the main actor.
    private struct Beacon: Identifiable {
        let id: String
        let coord: GeoPhoto.Coordinate
        let flag: String
        let photoCount: Int
    }

    /// The reveal runs in two phases. `loading` waits for the scan to resolve every country
    /// (showing a lightweight progress read-out); `animating` then plays the celebration on a
    /// frozen snapshot, so the heavy animation never competes with the scan.
    private enum Phase: Equatable { case loading, animating }

    @State private var phase: Phase = .loading
    @State private var beacons: [Beacon] = []
    @State private var visibleCount = 0
    @State private var settled = false
    @State private var started = false
    @State private var skipRequested = false
    @State private var outline: [[CGPoint]] = []

    // Loading read-out, updated by the polling loop (so `body` never reads `appVM`).
    @State private var loadProgress = 0.0
    @State private var loadLabel = ""

    // Finale stats, captured once when the reveal settles (so the subtitle doesn't read appVM).
    @State private var finaleContinents = 0
    @State private var finaleWorldPct = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                sky
                worldStage(in: geo.size)
                if phase == .loading {
                    loadingOverlay
                } else {
                    scrims
                    hud
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { if phase == .animating { skipRequested = true } }
        .onAppear { start() }
        .task { outline = await WorldOutline.shared.polylines() }
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: loadProgress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: loadProgress)
                Text("\(Int(loadProgress * 100))%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: loadProgress)
            }
            .frame(width: 132, height: 132)

            Text(loadLabel)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.opacity)
        }
        .padding(40)
    }

    // MARK: - Background

    private var sky: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.10),
                                    Color(red: 0.06, green: 0.03, blue: 0.14),
                                    Color.black],
                           startPoint: .top, endPoint: .bottom)
            StarField()
                .equatable()
                .opacity(0.7)
        }
    }

    /// Top + bottom gradient scrims so the HUD text stays readable over the map.
    private var scrims: some View {
        VStack {
            LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 220)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
        }
    }

    // MARK: - The world

    private func worldStage(in size: CGSize) -> some View {
        // Equirectangular world is 2:1; fit it to the screen width and centre it.
        let mapWidth = size.width
        let mapHeight = mapWidth / 2
        let mapSize = CGSize(width: mapWidth, height: mapHeight)
        let shown = Array(beacons.prefix(visibleCount))
        let pts = shown.map { project($0.coord, in: mapSize) }
        let arcIndices = pts.count >= 2 ? Array(1..<pts.count) : []

        return ZStack {
            WorldOutlineLayer(outline: outline)
                .equatable()
                .frame(width: mapSize.width, height: mapSize.height)
                .opacity(phase == .loading ? 0.45 : 1)
                .animation(.easeInOut(duration: 0.45), value: phase)

            // Flight-path arcs between consecutive countries, drawing themselves on appear.
            ForEach(arcIndices, id: \.self) { i in
                AnimatedArc(from: pts[i - 1], to: pts[i], reduceMotion: reduceMotion)
            }

            // Country beacons.
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, beacon in
                CountryBeacon(flag: beacon.flag,
                              size: dotSize(photoCount: beacon.photoCount),
                              reduceMotion: reduceMotion)
                    .position(pts[index])
            }
        }
        .frame(width: mapSize.width, height: mapSize.height)
        .frame(width: size.width, height: size.height)
    }

    // MARK: - HUD

    private var hud: some View {
        VStack {
            Text("Discovering your world…")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .opacity(settled ? 0 : 1)
                .padding(.top, 72)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 6) {
                Text("\(visibleCount)")
                    .font(.system(size: 68, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: visibleCount)

                Text(subtitleText)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                if settled {
                    Button(action: finish) {
                        Text("Start exploring")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 18)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, settled ? 48 : 64)
            .overlay(alignment: .bottom) {
                if !settled {
                    Text("Tap to skip")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Reveal driving

    private func start() {
        guard !started else { return }
        started = true
        Task { @MainActor in await run() }
    }

    /// Phase 1 — wait (showing a live progress read-out) until the scan has resolved every
    /// country. Then freeze a snapshot and Phase 2 — play the celebration on that static data,
    /// so the heavy animation never contends with the scan's main-actor work.
    @MainActor
    private func run() async {
        // Loading: poll the scan off the render path, driving the progress ring. We only wait
        // for COUNTRIES to resolve — the (potentially long) city-geocoding pass keeps running in
        // the background scan task while we play the animation, so we never block on it here.
        var waited = 0.0
        while !countriesResolved(appVM.scanProgress) {
            updateLoad(appVM.scanProgress)
            try? await Task.sleep(nanoseconds: 80_000_000)
            waited += 0.08
            if waited > 60 { break }   // safety valve, never strand the user
        }
        updateLoad(.complete)
        snapshotCountries()

        // Nothing to celebrate → straight to the dashboard.
        if beacons.isEmpty { appVM.finishMapReveal(); return }

        // Capture finale stats now, while the loading screen still holds at 100%.
        finaleContinents = appVM.stats.visitedContinentCount
        finaleWorldPct = max(1, Int(appVM.stats.worldPercentage.rounded()))

        try? await Task.sleep(nanoseconds: 450_000_000)   // brief beat at 100%
        withAnimation(.easeInOut(duration: 0.45)) { phase = .animating }
        await runAnimation()
    }

    /// Phase 2 — staggered ignition of the frozen beacons, oldest-first.
    @MainActor
    private func runAnimation() async {
        try? await Task.sleep(nanoseconds: 500_000_000)   // let the phase transition land

        let total = beacons.count
        let pace = reduceMotion ? 0.0 : min(0.14, max(0.05, 3.5 / Double(max(total, 1))))
        for i in 1...total {
            if skipRequested { break }
            visibleCount = i
            if pace > 0 { try? await Task.sleep(nanoseconds: UInt64(pace * 1_000_000_000)) }
        }
        visibleCount = total
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { settled = true }
    }

    /// Freeze the fully-resolved countries into the local model, oldest-first.
    private func snapshotCountries() {
        beacons = appVM.stats.countries
            .sorted { $0.firstVisit < $1.firstVisit }
            .map { Beacon(id: $0.id, coord: $0.representativeCoordinate,
                          flag: $0.flag, photoCount: $0.photoCount) }
    }

    /// True once every country is known. `.geocoding` marks the START of the city pass, which
    /// only happens after all countries are resolved — so we release the loading screen here and
    /// let the city pass finish in the background rather than waiting through its long tail.
    /// `.complete` covers the case where there were no cities to geocode at all.
    private func countriesResolved(_ p: AppViewModel.ScanProgress) -> Bool {
        switch p {
        case .geocoding, .complete, .failed: return true
        default: return false
        }
    }

    /// Map scan progress to a single 0…1 value + label for the loading ring.
    private func updateLoad(_ p: AppViewModel.ScanProgress) {
        switch p {
        case .idle:
            loadProgress = max(loadProgress, 0.02)
            loadLabel = String(localized: "Getting ready…")
        case .scanning(let progress, _):
            loadProgress = progress * 0.5
            loadLabel = String(localized: "Scanning your photos…")
        case .resolvingCountries(let progress, _):
            loadProgress = 0.5 + progress * 0.5
            loadLabel = String(localized: "Finding your countries…")
        case .geocoding, .complete, .failed:
            loadProgress = 1
            loadLabel = String(localized: "Ready")
        }
    }

    private func finish() { appVM.finishMapReveal() }

    // MARK: - Geometry & copy

    private func project(_ coord: GeoPhoto.Coordinate, in size: CGSize) -> CGPoint {
        CGPoint(x: (coord.longitude + 180) / 360 * size.width,
                y: (90 - coord.latitude) / 180 * size.height)
    }

    private func dotSize(photoCount: Int) -> CGFloat {
        let base: CGFloat = 8
        let bonus = min(CGFloat(photoCount) / 120, 1) * 8
        return base + bonus
    }

    private var subtitleText: String {
        guard settled else {
            return visibleCount == 1
                ? String(localized: "country so far")
                : String(localized: "countries so far")
        }
        let countriesWord = beacons.count == 1
            ? String(localized: "country visited")
            : String(localized: "countries visited")
        let continents = finaleContinents == 1
            ? String(localized: "1 continent")
            : String(localized: "\(finaleContinents) continents")
        // Keep the literal "%" out of any format key by pre-formatting the percentage.
        let worldPart = String(localized: "\("\(finaleWorldPct)%") of the world")
        return "\(countriesWord) · \(continents) · \(worldPart)"
    }
}

// MARK: - Country beacon

/// A single country lighting up: an expanding pulse ring, a glowing core, and its flag
/// briefly rising before fading — giving every country a moment of identity.
private struct CountryBeacon: View {
    let flag: String
    let size: CGFloat
    let reduceMotion: Bool

    @State private var appeared = false
    @State private var ring = false
    @State private var showFlag = true

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .stroke(Color.accentColor.opacity(ring ? 0 : 0.7), lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(ring ? 3.2 : 0.6)
            }
            // Cheap static "glow": a translucent halo behind the core (no drop shadow, which
            // is costly to composite once dozens of beacons are on screen at once).
            Circle()
                .fill(Color.accentColor.opacity(0.35))
                .frame(width: size * 2.2, height: size * 2.2)
                .blur(radius: 4)
            Circle()
                .fill(Color.accentColor)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
            if showFlag {
                Text(flag)
                    .font(.system(size: max(20, size + 6)))
                    .offset(y: -(size + 14))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(appeared ? 1 : 0.1)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { appeared = true }
            if reduceMotion { showFlag = false; return }
            withAnimation(.easeOut(duration: 1.1)) { ring = true }
            withAnimation(.easeIn(duration: 0.35).delay(0.9)) { showFlag = false }
        }
    }
}

// MARK: - Flight-path arc

/// A curved great-circle-ish arc between two countries that draws itself on appear.
private struct AnimatedArc: View {
    let from: CGPoint
    let to: CGPoint
    let reduceMotion: Bool

    @State private var trimEnd: CGFloat = 0

    var body: some View {
        ArcShape(from: from, to: to)
            .trim(from: 0, to: trimEnd)
            .stroke(
                LinearGradient(colors: [Color.accentColor.opacity(0.9), .cyan.opacity(0.7)],
                               startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [1, 5])
            )
            .onAppear {
                if reduceMotion { trimEnd = 1; return }
                withAnimation(.easeInOut(duration: 0.7)) { trimEnd = 1 }
            }
    }
}

private struct ArcShape: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        // Bow the line upward, proportional to its length, for a flight-path feel.
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let dist = hypot(to.x - from.x, to.y - from.y)
        let control = CGPoint(x: mid.x, y: mid.y - dist * 0.28)
        path.addQuadCurve(to: to, control: control)
        return path
    }
}

// MARK: - World outline

/// The coastline, stroked once. `Equatable` so SwiftUI skips re-drawing the (large) path on
/// every dot increment — it only depends on the loaded polylines, which never change.
private struct WorldOutlineLayer: View, Equatable {
    let outline: [[CGPoint]]

    static func == (lhs: WorldOutlineLayer, rhs: WorldOutlineLayer) -> Bool {
        lhs.outline.count == rhs.outline.count
    }

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            for line in outline {
                var drawing = false
                var prevLon = 0.0
                for coord in line {
                    let x = (coord.x + 180) / 360 * size.width
                    let y = (90 - coord.y) / 180 * size.height
                    if drawing && abs(coord.x - prevLon) > 180 { drawing = false }   // antimeridian
                    if drawing { path.addLine(to: CGPoint(x: x, y: y)) }
                    else { path.move(to: CGPoint(x: x, y: y)); drawing = true }
                    prevLon = coord.x
                }
            }
            // Soft wide glow underneath, crisp line on top.
            ctx.stroke(path, with: .color(.cyan.opacity(0.10)), lineWidth: 2.4)
            ctx.stroke(path, with: .color(.white.opacity(0.28)), lineWidth: 0.6)
        }
        .drawingGroup()
    }
}

// MARK: - Star field

/// A deterministic star field (no RNG, so it never reflows on redraw). `Equatable` with no
/// inputs so SwiftUI renders it exactly once and skips it on every subsequent state change.
private struct StarField: View, Equatable {
    static func == (lhs: StarField, rhs: StarField) -> Bool { true }

    var body: some View {
        Canvas { ctx, size in
            for i in 0..<140 {
                let fx = frac(sin(Double(i) * 12.9898) * 43758.5453)
                let fy = frac(sin(Double(i) * 78.233) * 12543.1234)
                let fr = frac(sin(Double(i) * 4.911) * 9843.12)
                let x = fx * size.width
                let y = fy * size.height
                let r = 0.4 + fr * 1.3
                let opacity = 0.25 + fr * 0.5
                let rect = CGRect(x: x, y: y, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
            }
        }
    }

    private func frac(_ v: Double) -> Double { v - floor(v) }
}
