import SwiftUI

/// Scales a fixed-size share card down to fit the available space, so the preview
/// is never cut off regardless of device size.
struct SharePreviewCanvas<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geo in
            // Clamp to ≥ 0: during the first layout pass `geo.size` can be zero, which would
            // otherwise make the scale (and the resulting frame) negative / non-finite.
            let scale = max(0, min((geo.size.width - 32) / size.width,
                                   (geo.size.height - 16) / size.height))
            content
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .frame(width: size.width * scale, height: size.height * scale)
                .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
