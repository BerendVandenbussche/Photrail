import SwiftUI

/// A single photo thumbnail that opens a full-screen, zoomable viewer when tapped.
/// Use for standalone photos (e.g. a wonder's representative shot). For large grids
/// prefer `PhotoGridSection`, which shares one presentation across all tiles.
struct TappablePhotoThumbnail: View {
    let assetID: String
    var size: CGFloat = 100
    var cornerRadius: CGFloat = 10

    @State private var showFullScreen = false

    var body: some View {
        Button { showFullScreen = true } label: {
            PhotoThumbnail(assetID: assetID, size: size, cornerRadius: cornerRadius)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenPhotoView(assetID: assetID)
        }
    }
}
