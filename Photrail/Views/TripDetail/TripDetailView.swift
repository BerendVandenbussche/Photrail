import SwiftUI
import Photos

/// Detail for a single trip: a hero photo, key stats, a map of the cities visited
/// (joined in visit order), the itinerary, wonders seen, and the trip's photos.
struct TripDetailView: View {
    let trip: Trip

    @State private var selectedPhoto: IdentifiedPhoto?
    @State private var coverImage: UIImage?
    @State private var showSharePreview = false

    private struct IdentifiedPhoto: Identifiable { let id: String }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                header

                statsSection

                if !trip.stops.isEmpty {
                    TripMapView(stops: trip.stops)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 20)
                } else if trip.coordinate.latitude != 0 || trip.coordinate.longitude != 0 {
                    LocationMiniMap(latitude: trip.coordinate.latitude,
                                    longitude: trip.coordinate.longitude,
                                    glyph: trip.flag, spanMeters: 400_000)
                        .padding(.horizontal, 20)
                }

                if !trip.stops.isEmpty { stopsSection }

                if !trip.wonders.isEmpty { wondersSection }

                photoGridSection
            }
            .padding(.bottom, 8)
        }
        .navigationTitle(trip.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSharePreview = true } label: { Image(systemName: "square.and.arrow.up") }
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullScreenPhotoView(assetID: photo.id)
        }
        .sheet(isPresented: $showSharePreview) {
            TripSharePreview(trip: trip, cover: coverImage)
        }
        .task { await loadCover() }
    }

    // MARK: - Header (hero cover)

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            // Placeholder that stays put while the cover loads, so the photo can
            // simply cross-fade in over it instead of swapping layouts.
            LinearGradient(colors: [Color(red: 0.20, green: 0.18, blue: 0.45),
                                    Color(red: 0.33, green: 0.20, blue: 0.52)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if coverImage == nil {
                Text(trip.isMultiCountry ? trip.flagsLine : trip.flag)
                    .font(.system(size: trip.isMultiCountry ? 52 : 84))
                    .opacity(0.35)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
                    .transition(.opacity)
            }

            LinearGradient(colors: [.clear, .black.opacity(0.7)],
                           startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.dateRangeText.uppercased())
                    .font(.system(size: 12, weight: .bold)).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
                Text(trip.isMultiCountry ? "\(trip.flagsLine)  \(trip.displayName)" : "\(trip.flag) \(trip.country)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.6)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipped()
        .animation(.easeInOut(duration: 0.45), value: coverImage != nil)
    }

    // MARK: - Stats

    private var statItems: [(icon: String, value: String, label: String)] {
        var items: [(String, String, String)] = []
        if trip.routeDistanceKm >= 1 {
            items.append(("arrow.triangle.swap", "\(Int(trip.routeDistanceKm).formatted()) km", "Traveled"))
        }
        items.append(("calendar", trip.durationText, "Duration"))
        if trip.isMultiCountry {
            items.append(("globe.europe.africa", "\(trip.countries.count)", "Countries"))
        }
        items.append(("building.2", "\(trip.cities.count)", trip.cities.count == 1 ? "City" : "Cities"))
        items.append(("photo.stack", "\(trip.photoCount)", "Photos"))
        if let peak = trip.highestAltitudeText, (trip.highestAltitude ?? 0) >= 1000 {
            items.append(("mountain.2", peak, "Highest"))
        }
        return items
    }

    private var statsSection: some View {
        FlowLayout(spacing: 10, rowSpacing: 10) {
            ForEach(statItems, id: \.label) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.value).font(.subheadline.weight(.bold))
                        Text(item.label).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .card(cornerRadius: AppCard.chipRadius)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Itinerary

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Itinerary")
                .padding(.horizontal, 20)

            ForEach(Array(trip.stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 30, height: 30)
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.tint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.isMultiCountry ? "\(stop.flag) \(stop.name)" : stop.name)
                            .font(.subheadline.weight(.semibold))
                        Text(dateLabel(stop.firstVisit))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(stop.photoCount)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Image(systemName: "photo.stack").font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                if stop.id != trip.stops.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
    }

    // MARK: - Wonders

    private var wondersSectionTitle: String {
        let hasWonder = trip.wonders.contains { $0.isOfficial }
        let hasLandmark = trip.wonders.contains { !$0.isOfficial }
        if hasWonder && hasLandmark { return "Wonders & Landmarks Seen" }
        if hasWonder {
            let count = trip.wonders.filter(\.isOfficial).count
            return count == 1 ? "Wonder Seen" : "Wonders Seen"
        }
        let count = trip.wonders.filter { !$0.isOfficial }.count
        return count == 1 ? "Landmark Seen" : "Landmarks Seen"
    }

    private var wondersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: wondersSectionTitle)
                .padding(.horizontal, 20)

            ForEach(trip.wonders) { wonder in
                HStack(spacing: 14) {
                    if let id = wonder.photoID {
                        Button { selectedPhoto = IdentifiedPhoto(id: id) } label: {
                            PhotoThumbnail(assetID: id, size: 48, cornerRadius: 10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(wonder.emoji)
                            .font(.system(size: 30))
                            .frame(width: 48, height: 48)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    Text(wonder.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(wonder.emoji).font(.system(size: 20))
                }
                .padding(.horizontal, 20)
                if wonder.id != trip.wonders.last?.id {
                    Divider().padding(.leading, 76)
                }
            }
        }
    }

    // MARK: - Photos

    private var photoGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Photos")
                .padding(.horizontal, 20)

            if trip.photoIDs.isEmpty {
                Text("No photos available")
                    .foregroundStyle(.secondary).padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(trip.photoIDs.prefix(90), id: \.self) { id in
                        Button { selectedPhoto = IdentifiedPhoto(id: id) } label: {
                            PhotoThumbnail(assetID: id, size: (UIScreen.main.bounds.width - 4) / 3,
                                           cornerRadius: 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Cover + Share

    private func loadCover() async {
        let best = await PhotoCurator().bestPhotos(candidateIDs: trip.photoIDs, category: nil, limit: 1)
        let id = best.first ?? trip.photoIDs.first
        guard let id else { return }
        coverImage = await loadImage(id: id, target: CGSize(width: 1080, height: 1080))
    }

    private func loadImage(id: String, target: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
            else { continuation.resume(returning: nil); return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .exact
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: target, contentMode: .aspectFill, options: options
            ) { img, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !degraded, !resumed else { return }
                resumed = true
                continuation.resume(returning: img)
            }
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }
}

// MARK: - Share preview

/// Shows a live preview of the trip share card before sharing.
private struct TripSharePreview: View {
    let trip: Trip
    let cover: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 8)

                let scale: CGFloat = 0.72
                let size = TripShareCardView.canvasSize
                TripShareCardView(trip: trip, cover: cover)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale)
                    .frame(width: size.width * scale, height: size.height * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 8)

                Spacer(minLength: 8)

                Button { share() } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .navigationTitle("Share Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func share() {
        if let image = ShareCardRenderer.render(
            TripShareCardView(trip: trip, cover: cover),
            baseSize: TripShareCardView.canvasSize,
            opaque: true
        ) {
            SharePresenter.present([image])
        }
    }
}
