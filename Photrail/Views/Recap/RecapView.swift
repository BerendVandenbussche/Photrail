import SwiftUI
import Photos
import UIKit

/// The "Year in Travel" recap: a paged story that culminates in the shareable finale.
/// Every slide can be shared as its own branded card.
struct RecapView: View {
    let recap: RecapModel
    @Environment(\.dismiss) private var dismiss

    private enum Slide: Hashable {
        case intro, distance, mostPhotographed, route, newCountries,
             personality, wonders, biggestTrip, highestPeak, highlights, summary, finale
    }

    @State private var page: Slide = .intro
    @State private var theme: RecapTheme = .dark

    private static let top = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let bottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private var gradient: LinearGradient {
        LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom)
    }

    private var slides: [Slide] {
        var s: [Slide] = [.intro, .distance, .mostPhotographed, .route]
        if !recap.newCountries.isEmpty { s.append(.newCountries) }
        s.append(.personality)
        if !recap.seenWonders.isEmpty { s.append(.wonders) }   // skip when none seen that year
        s.append(.biggestTrip)
        if recap.highestAltitude != nil { s.append(.highestPeak) }
        if recap.busiestMonth != nil || recap.longestTripText != nil { s.append(.highlights) }
        s += [.summary, .finale]
        return s
    }

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()

            if recap.isEmpty {
                emptyState
            } else {
                TabView(selection: $page) {
                    ForEach(slides, id: \.self) { slide in
                        view(for: slide).tag(slide)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }

            topBar
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func view(for slide: Slide) -> some View {
        switch slide {
        case .intro:           intro
        case .distance:        distance
        case .mostPhotographed: favorite
        case .route:           route
        case .newCountries:    newCountriesSlide
        case .personality:     personality
        case .wonders:         wonders
        case .biggestTrip:     biggestTrip
        case .highestPeak:     highestPeak
        case .highlights:      highlights
        case .summary:         summary
        case .finale:          finale
        }
    }

    // MARK: - Top bar (share + close)

    private var topBar: some View {
        VStack {
            HStack {
                if !recap.isEmpty && page != .finale {
                    Button { shareCurrentSlide() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline).foregroundStyle(.white.opacity(0.85))
                            .padding(10).background(Circle().fill(.white.opacity(0.12)))
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline).foregroundStyle(.white.opacity(0.85))
                        .padding(10).background(Circle().fill(.white.opacity(0.12)))
                }
            }
            Spacer()
        }
        .padding(20)
    }

    private func focus(for slide: Slide) -> RecapCardFocus {
        switch slide {
        case .route:        return .route
        case .newCountries: return .newCountries
        case .personality:  return .personality
        default:            return .snapshot
        }
    }

    private func shareCurrentSlide() {
        // The Most Photographed slide shows the curated photos, so share them as a collage.
        if page == .mostPhotographed && !recap.highlightPhotoIDs.isEmpty {
            Task { await shareCollage() }
            return
        }
        if let image = ShareCardRenderer.render(
            RecapShareCardView(recap: recap, theme: theme, focus: focus(for: page)),
            baseSize: RecapShareCardView.canvasSize,
            opaque: theme != .transparent
        ) {
            SharePresenter.present([image])
        }
    }

    private func shareCollage() async {
        let images = await loadImages(ids: recap.highlightPhotoIDs, targetSize: CGSize(width: 600, height: 600))
        guard !images.isEmpty else { return }
        if let image = ShareCardRenderer.render(
            RecapCollageCardView(recap: recap, images: images),
            baseSize: RecapCollageCardView.canvasSize, opaque: true
        ) {
            SharePresenter.present([image])
        }
    }

    private func loadImages(ids: [String], targetSize: CGSize) async -> [UIImage] {
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byID: [String: PHAsset] = [:]
        fetched.enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }

        var result: [UIImage] = []
        for id in ids {
            guard let asset = byID[id] else { continue }
            if let image = await requestImage(asset: asset, targetSize: targetSize) { result.append(image) }
        }
        return result
    }

    private func requestImage(asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .exact
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options
            ) { image, _ in continuation.resume(returning: image) }
        }
    }

    // MARK: - Slide chrome

    private func slide<Content: View>(eyebrow: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text(eyebrow.uppercased())
                .font(.system(size: 14, weight: .bold)).tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            content()
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 36)
    }

    private var hugeText: Font { .system(size: 64, weight: .black, design: .rounded) }

    // MARK: - Slides

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
            Text(recap.distanceComparison ?? "across the world this year")
                .font(.title3).foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var favorite: some View {
        slide(eyebrow: "Top destination") {
            HStack(spacing: 14) {
                Text(recap.favoriteCountryFlag ?? "").font(.system(size: 56))
                Text(recap.favoriteCountryName ?? "—")
                    .font(.system(size: 38, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .minimumScaleFactor(0.5).lineLimit(2)
            }
            if !recap.highlightPhotoIDs.isEmpty {
                let side = (UIScreen.main.bounds.width - 72 - 10) / 2
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(recap.highlightPhotoIDs.prefix(4), id: \.self) { id in
                        PhotoThumbnail(assetID: id, size: side, cornerRadius: 14)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private var route: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("WHERE YOU WENT")
                .font(.system(size: 14, weight: .bold)).tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            Text(routeHeadline)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            JourneyMapView(stops: uniqueJourney)
                .frame(height: 230)
                .padding(.vertical, 4)

            FlowLayout(spacing: 14, rowSpacing: 12) {
                ForEach(uniqueJourney) { stop in
                    VStack(spacing: 2) {
                        Text(stop.flag).font(.system(size: 24))
                        Text(stop.monthLabel.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 36)
    }

    private var newCountriesSlide: some View {
        slide(eyebrow: "New this year") {
            Text(recap.newCountries.count == 1 ? "1 new\ncountry" : "\(recap.newCountries.count) new\ncountries")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 14, rowSpacing: 14) {
                ForEach(recap.newCountries) { badge in
                    VStack(spacing: 3) {
                        Text(badge.flag).font(.system(size: 30))
                        Text(badge.name).font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    }
                    .frame(maxWidth: 80)
                }
            }
            .padding(.top, 4)
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
            Text("\(recap.seenWonders.count)")
                .font(.system(size: 72, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text(recap.seenWonders.count == 1 ? "wonder & landmark seen" : "wonders & landmarks seen")
                .font(.title3).foregroundStyle(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(recap.seenWonders.prefix(6)) { badge in
                    HStack(spacing: 12) {
                        if let photoID = badge.photoID {
                            PhotoThumbnail(assetID: photoID, size: 44, cornerRadius: 10)
                        } else {
                            Text(badge.emoji).font(.system(size: 22)).frame(width: 44)
                        }
                        Text(badge.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                        if badge.isOfficial {
                            Text("WONDER")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(.orange))
                        }
                        Spacer()
                    }
                }
                if recap.seenWonders.count > 6 {
                    Text("+ \(recap.seenWonders.count - 6) more")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.top, 6)
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

    private var highestPeak: some View {
        slide(eyebrow: "Highest point") {
            if let photoID = recap.highestPeakPhotoID {
                PhotoThumbnail(assetID: photoID, size: UIScreen.main.bounds.width - 72, cornerRadius: 18)
            } else {
                Text("⛰️").font(.system(size: 64))
            }
            Text(recap.highestAltitudeText ?? "—")
                .font(hugeText).foregroundStyle(.white)
                .minimumScaleFactor(0.5).lineLimit(1)
            Text(recap.highestAltitudePlace.map { "above sea level · \($0)" } ?? "above sea level")
                .font(.title3).foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var highlights: some View {
        slide(eyebrow: "Highlights") {
            VStack(alignment: .leading, spacing: 18) {
                if let month = recap.busiestMonth {
                    factRow(emoji: "📅", label: "Busiest month", value: month)
                }
                if let longest = recap.longestTripText {
                    factRow(emoji: "🧳", label: "Longest trip", value: longest)
                }
            }
        }
    }

    private func factRow(emoji: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Text(emoji).font(.system(size: 34))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.white.opacity(0.6))
                Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
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
                if let image = ShareCardRenderer.render(
                    RecapShareCardView(recap: recap, theme: theme),
                    baseSize: RecapShareCardView.canvasSize,
                    opaque: theme != .transparent
                ) {
                    SharePresenter.present([image])
                }
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

    // MARK: - Helpers

    /// Journey deduped to unique countries, keeping first-visit chronological order.
    private var uniqueJourney: [RecapModel.JourneyStop] {
        var seen = Set<String>()
        var result: [RecapModel.JourneyStop] = []
        for stop in recap.journey where seen.insert(stop.name).inserted {
            result.append(stop)
        }
        return result
    }

    private var routeHeadline: String {
        let distinct = uniqueJourney.count
        if distinct <= 1 { return "Your year, mapped" }
        return "\(distinct) countries,\none journey"
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
