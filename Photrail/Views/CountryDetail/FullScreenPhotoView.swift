import SwiftUI
import Photos

/// A full-screen, zoomable viewer for a single photo asset, with a Share action.
struct FullScreenPhotoView: View {
    let assetID: String
    @Environment(\.dismiss) private var dismiss

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
                    Spacer()
                }
                .padding(20)
                Spacer()
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
