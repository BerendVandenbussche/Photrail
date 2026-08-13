import SwiftUI
import Photos
import UIKit

/// The "Year in Travel" recap: a paged story that culminates in the shareable finale.
/// Each slide renders the *exact* card you can share, so the preview is WYSIWYG.
struct RecapView: View {
    let recap: RecapModel
    @Environment(\.dismiss) private var dismiss

    private enum Slide: Hashable {
        case intro, distance, mostPhotographed, route, newCountries,
             personality, wonders, biggestTrip, highestPeak, finale
    }

    @State private var page: Slide = .intro
    @State private var collageImages: [UIImage] = []
    @State private var peakImage: UIImage?

    // Finale film.
    @State private var loopStart = Date()
    @State private var filmAssets = RecapFilmAssets.empty
    @State private var filmLoaded = false
    @State private var exporting = false
    @State private var exportProgress: Double = 0
    @State private var videoError: String?

    /// The shot list, which depends on what actually loaded — a year whose photos are all
    /// offline drops the montage rather than cutting to black.
    private var film: RecapFilm? {
        guard filmLoaded else { return nil }
        return RecapFilm(recap: recap, assets: filmAssets)
    }

    private static let top = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let bottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private var gradient: LinearGradient {
        LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom)
    }

    private var slides: [Slide] {
        var s: [Slide] = [.intro, .distance, .mostPhotographed, .route]
        if !recap.newCountries.isEmpty { s.append(.newCountries) }
        s.append(.personality)
        if !recap.seenWonders.isEmpty { s.append(.wonders) }   // skip when none seen that year
        s.append(.biggestTrip)
        if recap.highestAltitude != nil { s.append(.highestPeak) }
        s.append(.finale)
        return s
    }

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()

            if recap.isEmpty {
                emptyState
            } else {
                TabView(selection: $page) {
                    ForEach(slides, id: \.self) { slide in
                        view(for: slide).tag(slide)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }

            topBar
        }
        .preferredColorScheme(.dark)
        .task { await preloadCollage(); await preloadPeak(); await preloadFilm() }
        .overlay { if exporting { exportOverlay } }
        .interactiveDismissDisabled(exporting)
        .alert("Couldn't create the video", isPresented: videoErrorBinding) {
            Button("OK", role: .cancel) { videoError = nil }
        } message: {
            Text(videoError ?? "")
        }
    }

    @ViewBuilder
    private func view(for slide: Slide) -> some View {
        switch slide {
        case .intro:            intro
        case .mostPhotographed: collagePage
        case .highestPeak:      cardPage(RecapShareCardView(recap: recap, focus: .highestPeak, peakImage: peakImage))
        case .finale:           finale
        default:                cardPage(RecapShareCardView(recap: recap, focus: focus(for: slide)))
        }
    }

    /// Renders a share card scaled to fill the slide — this is exactly what gets shared.
    private func cardPage<Card: View>(_ card: Card,
                                      canvas: CGSize = RecapShareCardView.canvasSize) -> some View {
        GeometryReader { geo in
            let availableW = geo.size.width - 32
            let availableH = geo.size.height - 96      // leave room for top bar + page dots
            let scale = min(availableW / canvas.width, availableH / canvas.height)
            card
                .frame(width: canvas.width, height: canvas.height)
                .scaleEffect(scale)
                .frame(width: canvas.width * scale, height: canvas.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The Most Photographed slide shares the curated photo collage.
    @ViewBuilder
    private var collagePage: some View {
        if recap.highlightPhotoIDs.isEmpty {
            cardPage(RecapShareCardView(recap: recap, focus: .snapshot))
        } else if collageImages.isEmpty {
            ProgressView().tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            cardPage(RecapCollageCardView(recap: recap, images: collageImages),
                     canvas: RecapCollageCardView.canvasSize)
        }
    }

    // MARK: - Intro / Finale

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("PHOTRAIL")
                .font(.system(size: 14, weight: .bold)).tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            Text(String(recap.year)).font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Your Year in Travel")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Text("Swipe to relive it →")
                .font(.subheadline).foregroundStyle(.white.opacity(0.5))
                .padding(.top, 4)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 36)
    }

    private var finale: some View {
        VStack(spacing: 14) {
            Text("Your \(String(recap.year)) film")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 6)

            finaleCard
            finaleActions
        }
    }

    /// The finale plays the very film it exports. `RecapFilmView` is a pure function of
    /// progress, so what loops here and what lands in the `.mp4` are identical by construction
    /// — the same guarantee the still slides get from rendering the real share card.
    @ViewBuilder
    private var finaleCard: some View {
        let scale: CGFloat = 0.58
        Group {
            if let film {
                TimelineView(.animation) { timeline in
                    RecapFilmView(recap: recap, assets: filmAssets, film: film,
                                  progress: loopProgress(at: timeline.date, film: film))
                }
            } else {
                // Photos are still being pulled — possibly from iCloud. The card is the same
                // size either way, so nothing jumps when it arrives.
                ZStack {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    ProgressView().tint(.white)
                }
            }
        }
        .frame(width: RecapFilmView.canvasSize.width, height: RecapFilmView.canvasSize.height)
        .scaleEffect(scale)
        .frame(width: RecapFilmView.canvasSize.width * scale,
               height: RecapFilmView.canvasSize.height * scale)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .onAppear { loopStart = Date() }
    }

    /// Restarts from the top after a beat on the end card, so the brand line — which resolves
    /// last — is actually readable before it loops.
    private func loopProgress(at date: Date, film: RecapFilm) -> Double {
        let cycle = film.duration + 1.0
        let elapsed = date.timeIntervalSince(loopStart).truncatingRemainder(dividingBy: cycle)
        return min(elapsed / film.duration, 1)
    }

    private var finaleActions: some View {
        VStack(spacing: 12) {
            Button { Task { await exportVideo() } } label: {
                Label("Share video", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.black)
            }
            .disabled(exporting || film == nil)

            // No theme picker. Once the finale plays a film, a light/transparent switch that
            // silently applies to the *still* export and nothing you can see is a puzzle, not
            // a choice — every recap card is dark, matching the film.
            Button { shareFinaleImage() } label: {
                Text("Share image")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(exporting)
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 20)
    }

    private func shareFinaleImage() {
        if let image = ShareCardRenderer.render(
            RecapShareCardView(recap: recap),
            baseSize: RecapShareCardView.canvasSize,
            opaque: true
        ) {
            SharePresenter.present([image])
        }
    }

    // MARK: - Video export

    /// Pulls every photo the film needs, once. Deliberately last of the three preloads: the
    /// user lands on the intro slide and swipes through nine others before reaching the
    /// finale, which is plenty of time even when the photos come from iCloud.
    private func preloadFilm() async {
        guard !filmLoaded, !recap.isEmpty else { return }
        filmAssets = await RecapFilmAssets.load(for: recap)
        filmLoaded = true
    }

    private func exportVideo() async {
        guard let film else { return }
        exporting = true
        exportProgress = 0
        defer { exporting = false }

        do {
            let url = try ShareVideoFile.makeURL(named: "Photrail \(recap.year) — Year in Travel")
            let output = try await ShareVideoRenderer.export(
                config: ShareVideoRenderer.Config(duration: film.duration),
                outputURL: url,
                onProgress: { exportProgress = $0 }
            ) { progress in
                RecapFilmView(recap: recap, assets: filmAssets, film: film, progress: progress)
            }
            // Cleaned up only once the sheet is done: Instagram and TikTok read the file
            // lazily after their extension launches, so deleting any earlier ships a 0-byte
            // video. The handler fires on cancel too.
            SharePresenter.present([output]) {
                ShareVideoFile.remove(output)
            }
        } catch is CancellationError {
            // Nothing to report — the user backed out.
        } catch {
            videoError = error.localizedDescription
        }
    }

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: exportProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 180)
                Text("Creating video…")
                    .font(.subheadline.weight(.semibold))
                // The film takes long enough that a bar alone reads as a hang; the number
                // is what tells you it's still moving.
                Text(exportProgress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        // Rendering keeps the main actor busy throughout, so block interaction rather than
        // letting the UI feel broken.
        .transition(.opacity)
    }

    private var videoErrorBinding: Binding<Bool> {
        Binding(get: { videoError != nil }, set: { if !$0 { videoError = nil } })
    }

    // MARK: - Top bar (share + close)

    private var topBar: some View {
        VStack {
            HStack {
                if !recap.isEmpty && page != .finale {
                    Button { shareCurrentSlide() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline).foregroundStyle(.white.opacity(0.85))
                            .padding(10).background(Circle().fill(.white.opacity(0.12)))
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline).foregroundStyle(.white.opacity(0.85))
                        .padding(10).background(Circle().fill(.white.opacity(0.12)))
                }
            }
            Spacer()
        }
        .padding(20)
    }

    private func focus(for slide: Slide) -> RecapCardFocus {
        switch slide {
        case .distance:     return .distance
        case .route:        return .route
        case .newCountries: return .newCountries
        case .personality:  return .personality
        case .wonders:      return .wonders
        case .biggestTrip:  return .biggestTrip
        case .highestPeak:  return .highestPeak
        default:            return .snapshot   // intro, mostPhotographed, finale
        }
    }

    // MARK: - Sharing

    private func shareCurrentSlide() {
        if page == .mostPhotographed && !recap.highlightPhotoIDs.isEmpty {
            Task { await shareCollage() }
            return
        }
        if let image = ShareCardRenderer.render(
            RecapShareCardView(recap: recap, focus: focus(for: page),
                               peakImage: page == .highestPeak ? peakImage : nil),
            baseSize: RecapShareCardView.canvasSize,
            opaque: true
        ) {
            SharePresenter.present([image])
        }
    }

    private func shareCollage() async {
        let images = collageImages.isEmpty
            ? await loadImages(ids: recap.highlightPhotoIDs, targetSize: CGSize(width: 600, height: 600))
            : collageImages
        guard !images.isEmpty else { return }
        if let image = ShareCardRenderer.render(
            RecapCollageCardView(recap: recap, images: images),
            baseSize: RecapCollageCardView.canvasSize, opaque: true
        ) {
            SharePresenter.present([image])
        }
    }

    private func preloadCollage() async {
        guard collageImages.isEmpty, !recap.highlightPhotoIDs.isEmpty else { return }
        collageImages = await loadImages(ids: recap.highlightPhotoIDs,
                                         targetSize: CGSize(width: 600, height: 600))
    }

    private func preloadPeak() async {
        guard peakImage == nil, let id = recap.highestPeakPhotoID else { return }
        peakImage = await loadImages(ids: [id], targetSize: CGSize(width: 900, height: 700)).first
    }

    private func loadImages(ids: [String], targetSize: CGSize) async -> [UIImage] {
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byID: [String: PHAsset] = [:]
        fetched.enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }

        var result: [UIImage] = []
        for id in ids {
            guard let asset = byID[id] else { continue }
            if let image = await requestImage(asset: asset, targetSize: targetSize) { result.append(image) }
        }
        return result
    }

    private func requestImage(asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .exact
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options
            ) { image, _ in continuation.resume(returning: image) }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar").font(.system(size: 50)).foregroundStyle(.white.opacity(0.7))
            Text("No travels recorded in \(String(recap.year)) yet")
                .font(.title3.weight(.semibold)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Take some geotagged photos on your next trip and check back.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
