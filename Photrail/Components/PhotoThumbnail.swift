import SwiftUI
import Photos

/// Loads and displays a single PHAsset thumbnail.
/// Uses async/await so loading doesn't block the main thread.
struct PhotoThumbnail: View {
    let assetID: String
    var size: CGFloat = 100
    var cornerRadius: CGFloat = 10

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: assetID) {
            image = await loadThumbnail()
        }
    }

    private func loadThumbnail() async -> UIImage? {
        await withCheckedContinuation { continuation in
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            guard let asset = result.firstObject else {
                continuation.resume(returning: nil)
                return
            }
            let options = PHImageRequestOptions()
            // High quality + iCloud access, so optimized-storage libraries (where the
            // full-res original lives in iCloud) don't render a blurry local thumbnail.
            // .highQualityFormat delivers a single callback, safe for the continuation.
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: size * 2, height: size * 2),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
