import SwiftUI

/// The "Year in Travel" recap: a paged story that culminates in the shareable finale.
struct RecapView: View {
    let recap: RecapModel
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var theme: RecapTheme = .dark
    @State private var shareImage: UIImage?
    @State private var showShare = false

    private static let top = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let bottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private var gradient: LinearGradient {
        LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()

            if recap.isEmpty {
                emptyState
            } else {
                TabView(selection: $page) {
                    intro.tag(0)
                    distance.tag(1)
                    favorite.tag(2)
                    personality.tag(3)
                    wonders.tag(4)
                    biggestTrip.tag(5)
                    summary.tag(6)
                    finale.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }

            // Close
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(10)
                            .background(Circle().fill(.white.opacity(0.12)))
                    }
                }
                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShare) {
            if let shareImage { ShareSheetViewControllerWrapper(items: [shareImage]) }
        }
    }

    // MARK: - Slides

    private func slide<Content: View>(eyebrow: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text(eyebrow.uppercased())
                .font(.system(size: 14, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            content()
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 36)
    }

    private var hugeText: Font { .system(size: 64, weight: .black, design: .rounded) }

    private var intro: some View {
        slide(eyebrow: "Photrail") {
            Text(String(recap.year)).font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Your Year in Travel")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var distance: some View {
        slide(eyebrow: "Distance traveled") {
            Text(recap.distanceText).font(hugeText).foregroundStyle(.white)
                .minimumScaleFactor(0.5).lineLimit(1)
            Text("across the world this year")
                .font(.title3).foregroundStyle(.white.opacity(0.8))
        }
    }

    private var favorite: some View {
        slide(eyebrow: "Favorite destination") {
            if let name = recap.favoriteCountryName {
                Text(recap.favoriteCountryFlag ?? "").font(.system(size: 80))
                Text(name).font(.system(size: 46, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .minimumScaleFactor(0.5).lineLimit(2)
            } else {
                Text("—").font(hugeText).foregroundStyle(.white)
            }
        }
    }

    private var personality: some View {
        slide(eyebrow: "Travel personality") {
            Text("You were a\n\(recap.dominantTitle ?? recap.title)")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                ForEach(recap.topSlices) { slice in
                    HStack {
                        Text("\(slice.category.emoji)  \(slice.category.title)")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text("\(Int(slice.percentage.rounded()))%")
                            .font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var wonders: some View {
        slide(eyebrow: "Wonders & landmarks") {
            Text("\(recap.wonders)").font(.system(size: 96, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text(recap.wonders == 1 ? "wonder visited" : "wonders visited")
                .font(.title3).foregroundStyle(.white.opacity(0.8))
        }
    }

    private var biggestTrip: some View {
        slide(eyebrow: "Biggest trip") {
            Text(recap.biggestTripTitle ?? "—")
                .font(.system(size: 44, weight: .black, design: .rounded)).foregroundStyle(.white)
                .minimumScaleFactor(0.5).lineLimit(2)
            if let sub = recap.biggestTripSubtitle {
                Text(sub).font(.title3).foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var summary: some View {
        slide(eyebrow: "Year summary") {
            let items: [(String, String, String)] = [
                ("🌍", "\(recap.countries)", "Countries"), ("🏙", "\(recap.cities)", "Cities"),
                ("✈️", "\(recap.trips)", "Trips"), ("📸", "\(recap.photos)", "Photos"),
                ("🏛", "\(recap.wonders)", "Wonders"), ("🌎", "\(recap.continents)", "Continents")
            ]
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(items, id: \.2) { emoji, value, label in
                    VStack(spacing: 2) {
                        Text("\(emoji) \(value)")
                            .font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text(label).font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.08)))
                }
            }
        }
    }

    // MARK: - Finale

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
                shareImage = ShareCardRenderer.render(
                    RecapShareCardView(recap: recap, theme: theme),
                    baseSize: RecapShareCardView.canvasSize,
                    opaque: theme != .transparent
                )
                showShare = shareImage != nil
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
