import SwiftUI
import UIKit

/// Renders a SwiftUI share card to a high-resolution PNG-ready UIImage.
enum ShareCardRenderer {

    /// Exports the card at Instagram-story resolution (1080×1920) by default.
    /// - Parameter transparent: preserve the alpha channel (for story overlays).
    @MainActor
    static func image(model: ShareCardModel,
                      background: ShareCardBackground,
                      photo: UIImage? = nil,
                      targetWidth: CGFloat = 1080) -> UIImage? {
        let base = ShareCardView.canvasSize
        let renderer = ImageRenderer(content:
            ShareCardView(model: model, background: background, photo: photo)
                .frame(width: base.width, height: base.height)
        )
        renderer.scale = targetWidth / base.width   // 1080 / 360 = 3×
        renderer.isOpaque = (background != .transparent)
        return renderer.uiImage
    }

    /// PNG data (keeps alpha for transparent exports).
    @MainActor
    static func pngData(model: ShareCardModel,
                        background: ShareCardBackground,
                        photo: UIImage? = nil) -> Data? {
        image(model: model, background: background, photo: photo)?.pngData()
    }

    /// Generic high-resolution render for any card view (e.g. the recap finale card).
    @MainActor
    static func render(_ view: some View, baseSize: CGSize, width: CGFloat = 1080, opaque: Bool) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: baseSize.width, height: baseSize.height))
        renderer.scale = width / baseSize.width
        renderer.isOpaque = opaque
        return renderer.uiImage
    }
}
