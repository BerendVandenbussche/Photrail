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
    @State private var theme: RecapTheme = .dark
    @State private var collageImages: [UIImage] = []

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
        .task { await preloadCollage() }
    }

    @ViewBuilder
    private func view(for slide: Slide) -> some View {
        switch slide {
        case .intro:            intro
        case .mostPhotographed: collagePage
        case .finale:           finale
        default:                cardPage(RecapShareCardView(recap: recap, theme: theme,
                                                            focus: focus(for: slide)))
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
            cardPage(RecapShareCardView(recap: recap, theme: theme, focus: .snapshot))
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
        VStack(spacing: 18) {
            Text("Your \(String(recap.year)) Travel Snapshot")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 8)

            let scale: CGFloat = 0.62
            RecapShareCardView(recap: recap, theme: theme)
                .frame(width: RecapShareCardView.canvasSize.width, height: RecapShareCardView.canvasSize.height)
                .scaleEffect(scale)
                .frame(width: RecapShareCardView.canvasSize.width * scale,
                       height: RecapShareCardView.canvasSize.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

            HStack(spacing: 8) {
                ForEach(RecapTheme.allCases) { t in
                    Button { theme = t } label: {
                        Text(t.title)
                            .font(.subheadline.weight(theme == t ? .semibold : .regular))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(theme == t ? Color.white.opacity(0.9) : Color.white.opacity(0.12),
                                        in: Capsule())
                            .foregroundStyle(theme == t ? .black : .white)
                    }
                }
            }

            Button {
                if let image = ShareCardRenderer.render(
                    RecapShareCardView(recap: recap, theme: theme),
                    baseSize: RecapShareCardView.canvasSize,
                    opaque: theme != .transparent
                ) {
                    SharePresenter.present([image])
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 28)
        }
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
            RecapShareCardView(recap: recap, theme: theme, focus: focus(for: page)),
            baseSize: RecapShareCardView.canvasSize,
            opaque: theme != .transparent
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
