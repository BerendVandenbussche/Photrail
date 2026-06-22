import SwiftUI

/// A shareable photo collage of the year's best shots, branded. 9:16, render-ready.
/// Images are passed in pre-loaded (UIImage) so it renders faithfully via ImageRenderer.
struct RecapCollageCardView: View {
    let recap: RecapModel
    let images: [UIImage]

    static let canvasSize = CGSize(width: 360, height: 640)

    private static let top = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let bottom = Color(red: 0.22, green: 0.13, blue: 0.42)

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 7) {
                    LogoMark(color: .white).frame(width: 18, height: 18)
                    Text("Photrail").font(.system(size: 15, weight: .heavy, design: .rounded))
                    Spacer()
                    Text(String(recap.year))
                        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)

                Text("My \(String(recap.year)) in photos")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(images.prefix(6).enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Spacer(minLength: 0)
                Text(ShareCardModel.tagline)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(28)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
}
