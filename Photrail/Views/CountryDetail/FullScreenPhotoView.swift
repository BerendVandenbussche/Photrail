import SwiftUI
import Photos

/// A full-screen, zoomable photo viewer. Given more than one asset it pages between them,
/// so the grid you opened from stays browsable without going back and forth.
struct FullScreenPhotoView: View {
    /// Every photo reachable by swiping — normally the whole grid the viewer was opened from.
    let assetIDs: [String]
    /// Optional heart-rate "vibe" per photo, from the Trip Insights module.
    var excitementByPhotoID: [String: ExcitementSample] = [:]

    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM

    @State private var currentID: String

    /// A single photo, as opened from a standalone thumbnail.
    init(assetID: String, excitement: ExcitementSample? = nil) {
        self.assetIDs = [assetID]
        self.excitementByPhotoID = excitement.map { [assetID: $0] } ?? [:]
        _currentID = State(initialValue: assetID)
    }

    /// A photo within a set, opened at `startID` and swipeable through the rest.
    init(assetIDs: [String], startID: String,
         excitementByPhotoID: [String: ExcitementSample] = [:]) {
        self.assetIDs = assetIDs.isEmpty ? [startID] : assetIDs
        self.excitementByPhotoID = excitementByPhotoID
        _currentID = State(initialValue: startID)
    }

    private var excitement: ExcitementSample? { excitementByPhotoID[currentID] }
    private var isExcluded: Bool { appVM.isPhotoExcluded(currentID) }

    /// 1-based position of the current photo, for the "3 of 42" counter.
    private var position: Int? {
        assetIDs.firstIndex(of: currentID).map { $0 + 1 }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentID) {
                ForEach(assetIDs, id: \.self) { id in
                    ZoomablePhoto(assetID: id).tag(id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Each page owns its own zoom state, so paging away resets it — which is what
            // the system Photos app does and what people expect.
            .ignoresSafeArea()

            controls
        }
        .statusBarHidden()
    }

    // MARK: - Chrome

    private var controls: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline).foregroundStyle(.white)
                        .padding(10).background(Circle().fill(.white.opacity(0.18)))
                }
                if let excitement {
                    HStack(spacing: 6) {
                        Text(excitement.badge.emoji)
                        Text("\(Int(excitement.bpm)) bpm")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.18)))
                }
                Spacer()
                // Only worth showing when there's somewhere to swipe to.
                if assetIDs.count > 1, let position {
                    Text("\(position) of \(assetIDs.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.18)))
                        .monospacedDigit()
                }
                Spacer()
                Menu {
                    Button(role: isExcluded ? nil : .destructive) {
                        appVM.togglePhotoExcluded(currentID)
                    } label: {
                        Label(isExcluded ? "Include in stats" : "Exclude from stats",
                              systemImage: isExcluded ? "eye" : "eye.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline).foregroundStyle(.white)
                        .padding(10).background(Circle().fill(.white.opacity(0.18)))
                }
                .accessibilityLabel("More options")
            }
            .padding(20)

            Spacer()

            if isExcluded {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash.fill")
                    Text("Excluded from stats").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(.black.opacity(0.5)))
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - One page

/// A single zoomable photo. Its own view so that zoom state belongs to the page and is
/// discarded when `TabView` recycles it.
///
/// Zoom is anchored: pinching magnifies around the point between your fingers and
/// double-tapping around the point you tapped, rather than always around the centre. That's
/// done by keeping a plain centre-anchored `scaleEffect` and moving `offset` to compensate,
/// which composes across successive gestures — an `anchor:` that changes per gesture does not.
private struct ZoomablePhoto: View {
    let assetID: String

    private static let maxScale: CGFloat = 6
    private static let doubleTapScale: CGFloat = 2.5

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .gesture(magnification(in: geo.size, image: image))
                        // High priority so a pan beats `TabView`'s paging — while zoomed in,
                        // dragging should move the photo, not turn the page. At 1× it isn't
                        // installed at all, so paging works normally.
                        .highPriorityGesture(pan(in: geo.size, image: image),
                                             including: scale > 1 ? .all : .subviews)
                        .onTapGesture(count: 2) { location in
                            handleDoubleTap(at: location, in: geo.size, image: image)
                        }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: assetID) {
            image = nil
            let loaded = await loadFullImage()
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }

    // MARK: - Gestures

    private func magnification(in viewSize: CGSize, image: UIImage) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let focus = focalPoint(value.startLocation, in: viewSize)
                let target = min(max(lastScale * value.magnification, 1), Self.maxScale)
                offset = offsetKeeping(focus, fixed: target, from: lastScale, at: lastOffset)
                scale = target
            }
            .onEnded { _ in settle(in: viewSize, image: image) }
    }

    private func pan(in viewSize: CGSize, image: UIImage) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in settle(in: viewSize, image: image) }
    }

    private func handleDoubleTap(at location: CGPoint, in viewSize: CGSize, image: UIImage) {
        withAnimation(.spring(response: 0.3)) {
            if scale > 1 {
                scale = 1
                offset = .zero
            } else {
                let focus = focalPoint(location, in: viewSize)
                offset = offsetKeeping(focus, fixed: Self.doubleTapScale,
                                       from: scale, at: offset)
                scale = Self.doubleTapScale
                offset = clamped(offset, scale: scale, viewSize: viewSize, image: image)
            }
            lastScale = scale
            lastOffset = offset
        }
    }

    // MARK: - Zoom maths

    /// A point in view coordinates, re-expressed relative to the view's centre — which is
    /// what `scaleEffect` and `offset` are both measured from.
    private func focalPoint(_ location: CGPoint, in viewSize: CGSize) -> CGPoint {
        CGPoint(x: location.x - viewSize.width / 2, y: location.y - viewSize.height / 2)
    }

    /// The offset that keeps whatever is under `focus` under `focus` as the scale changes.
    ///
    /// A point sits on screen at `p * scale + offset`, so the content point currently under
    /// the focus is `(focus - offset) / scale`. Putting that same content point back under
    /// the focus at the new scale gives the expression below.
    private func offsetKeeping(_ focus: CGPoint, fixed newScale: CGFloat,
                               from oldScale: CGFloat, at oldOffset: CGSize) -> CGSize {
        let ratio = newScale / oldScale
        return CGSize(width: focus.x - (focus.x - oldOffset.width) * ratio,
                      height: focus.y - (focus.y - oldOffset.height) * ratio)
    }

    /// Snap back to a legal position: never smaller than fit, never dragged past the edges.
    private func settle(in viewSize: CGSize, image: UIImage) {
        withAnimation(.spring(response: 0.3)) {
            if scale <= 1 {
                scale = 1
                offset = .zero
            } else {
                offset = clamped(offset, scale: scale, viewSize: viewSize, image: image)
            }
        }
        lastScale = scale
        lastOffset = offset
    }

    /// Keep the photo covering the screen: pan is limited to the part of the scaled image
    /// that hangs outside the view, and pinned to centre on any axis that still fits.
    private func clamped(_ offset: CGSize, scale: CGFloat,
                         viewSize: CGSize, image: UIImage) -> CGSize {
        let fitted = fittedSize(of: image, in: viewSize)
        let limitX = max(0, (fitted.width * scale - viewSize.width) / 2)
        let limitY = max(0, (fitted.height * scale - viewSize.height) / 2)
        return CGSize(width: min(max(offset.width, -limitX), limitX),
                      height: min(max(offset.height, -limitY), limitY))
    }

    /// What `scaledToFit` actually draws at 1×.
    private func fittedSize(of image: UIImage, in viewSize: CGSize) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else { return viewSize }
        let ratio = min(viewSize.width / image.size.width, viewSize.height / image.size.height)
        return CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
    }

    private func loadFullImage() async -> UIImage? {
        await withCheckedContinuation { continuation in
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
            else { continuation.resume(returning: nil); return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .fast
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit, options: options
            ) { img, info in
                // Can deliver a low-res placeholder first; resume once on the final image.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded, !resumed else { return }
                resumed = true
                continuation.resume(returning: img)
            }
        }
    }
}
