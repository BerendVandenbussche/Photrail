#if DEBUG
import SwiftUI
import MapKit

// Debug-only: a postcard with made-up data, to check the design in the Simulator without a
// trip or photos. Opened from the "Postcard sample" row in Profile (also #if DEBUG).
// To remove: delete this file and that row in ProfileView.

extension PostcardContent {
    /// Day 3 of 8 in Lisbon: three painted "photos" and a real map of a walk through the city.
    static func debugSample(photoCount: Int = 3) async -> PostcardContent {
        let route = [
            DayPostcard.Point(latitude: 38.6916, longitude: -9.2160),   // Belém
            DayPostcard.Point(latitude: 38.7077, longitude: -9.1365),   // Baixa
            DayPostcard.Point(latitude: 38.7139, longitude: -9.1334),   // Castelo
            DayPostcard.Point(latitude: 38.7110, longitude: -9.1290),   // Alfama
        ]
        let calendar = Calendar.current
        let postcard = DayPostcard(
            day: calendar.startOfDay(for: Date()),
            dayNumber: 3, totalDays: 8,
            countryCode: "PT", countryName: "Portugal",
            cities: ["Lisbon", "Belém"],
            photoIDs: (1...42).map { "debug-\($0)" },
            route: route, distanceKm: 8.4)

        let coordinates = route.map(\.coordinate)
        let map = await MapShotLoader.shot(
            region: MapShotLoader.region(fitting: coordinates, padding: 0.4, minimumMeters: 3_000),
            size: mapRenderSize, markers: coordinates, scale: mapRenderScale)

        let paintings: [(String, [UIColor])] = [
            ("sun.horizon.fill", [.systemOrange, .systemPink]),
            ("tram.fill", [.systemYellow, .systemRed]),
            ("water.waves", [.systemTeal, .systemBlue]),
        ]
        let photos = paintings.prefix(photoCount).map { painting($0.0, colors: $0.1) }
        return PostcardContent(postcard: postcard, photos: photos, map: map)
    }

    /// A stand-in photo: a gradient with a big symbol.
    private static func painting(_ symbol: String, colors: [UIColor]) -> UIImage {
        let size = CGSize(width: 900, height: 900)
        return UIGraphicsImageRenderer(size: size).image { context in
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors.map(\.cgColor) as CFArray, locations: nil)!
            context.cgContext.drawLinearGradient(gradient, start: .zero,
                                                 end: CGPoint(x: size.width, y: size.height), options: [])
            let config = UIImage.SymbolConfiguration(pointSize: 320, weight: .bold)
            if let image = UIImage(systemName: symbol, withConfiguration: config)?
                .withTintColor(.white.withAlphaComponent(0.85), renderingMode: .alwaysOriginal) {
                let origin = CGPoint(x: (size.width - image.size.width) / 2,
                                     y: (size.height - image.size.height) / 2)
                image.draw(at: origin)
            }
        }
    }
}

/// The sample postcard, with a switch between one and three photos and the real share button.
struct PostcardDebugSampleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content: PostcardContent?
    @State private var photoCount = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                PostcardPreview(content: content, loading: content == nil)
                Picker("Photos", selection: $photoCount) {
                    Text(verbatim: "1 photo").tag(1)
                    Text(verbatim: "3 photos").tag(3)
                }
                .pickerStyle(.segmented)
                Button {
                    guard let content,
                          let image = ShareCardRenderer.render(PostcardCardView(content: content),
                                                               baseSize: PostcardCardView.canvasSize,
                                                               opaque: true)
                    else { return }
                    SharePresenter.present([image])
                } label: {
                    Label { Text(verbatim: "Share sample") } icon: { Image(systemName: "square.and.arrow.up") }
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .disabled(content == nil)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .navigationTitle(Text(verbatim: "Postcard sample"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task(id: photoCount) {
                content = nil
                content = await PostcardContent.debugSample(photoCount: photoCount)
            }
        }
    }
}

#Preview {
    PostcardDebugSampleView()
}
#endif
