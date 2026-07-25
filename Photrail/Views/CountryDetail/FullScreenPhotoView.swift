import SwiftUI
import Photos

/// A full-screen, zoomable viewer for a single photo asset, with a Share action.
struct FullScreenPhotoView: View {
    let assetID: String
    /// Optional heart-rate "vibe" for this photo, from the Trip Insights module.
    var excitement: ExcitementSample? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in scale = max(1, lastScale * value) }
                            .onEnded { _ in lastScale = scale }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3)) {
                            scale = scale > 1 ? 1 : 2.5
                            lastScale = scale
                        }
                    }
            } else {
                ProgressView().tint(.white)
            }

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
                    Menu {
                        let excluded = appVM.isPhotoExcluded(assetID)
                        Button(role: excluded ? nil : .destructive) {
                            appVM.togglePhotoExcluded(assetID)
                        } label: {
                            Label(excluded ? "Include in stats" : "Exclude from stats",
                                  systemImage: excluded ? "eye" : "eye.slash")
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
                if appVM.isPhotoExcluded(assetID) {
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
        .task(id: assetID) { image = await loadFullImage() }
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
