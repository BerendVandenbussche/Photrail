import SwiftUI
import PhotosUI
import CoreLocation

/// Lets the user pick a template + background, preview the premium card, and share it.
struct ShareComposerView: View {
    let stats: TravelStats
    let profile: TravelPersonalityProfile?
    let trips: [Trip]

    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM

    @State private var type: ShareCardType
    @State private var background: ShareCardBackground = .map
    @State private var selectedTrip: Trip?
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var showPaywall = false

    // World-poster artwork. Loaded lazily the first time the template is chosen, since it
    // parses the bundled border data.
    @State private var posterCoastline: [[CGPoint]] = []
    @State private var posterRings: [String: [[CLLocationCoordinate2D]]] = [:]
    @State private var posterLoading = false
    @State private var posterLoaded = false

    init(stats: TravelStats, profile: TravelPersonalityProfile?, trips: [Trip]) {
        self.stats = stats
        self.profile = profile
        self.trips = trips
        _type = State(initialValue: Self.defaultType(stats: stats, profile: profile, trips: trips))
        _selectedTrip = State(initialValue: trips.first)
    }

    private var hasData: Bool { stats.totalGeotaggedPhotos > 0 }

    /// Free users get a single basic template + default background, watermarked. Lifetime
    /// unlocks every template, every background and removes the watermark.
    private var isFree: Bool { !appVM.hasLifetime }
    /// The one template free users may use (the basic map summary).
    private var freeType: ShareCardType { availableTypes.contains(.summary) ? .summary : (availableTypes.first ?? .summary) }
    /// The world poster is deliberately free for everyone — every one shared advertises the app.
    private func isUnlocked(_ kind: ShareCardType) -> Bool {
        appVM.hasLifetime || kind == freeType || kind == .poster
    }
    private func isUnlocked(_ bg: ShareCardBackground) -> Bool { appVM.hasLifetime || bg == .map }

    private var availableTypes: [ShareCardType] {
        ShareCardType.allCases.filter { kind in
            switch kind {
            case .poster:      return stats.countryCount > 0
            case .summary:     return stats.countryCount > 0
            case .personality: return profile?.isMeaningful ?? false
            case .wonders:     return !stats.wonders.isEmpty
            // Trips have their own richer, photo-backed share card in Trip Detail, so the
            // generic "Trip" template is intentionally not offered here.
            case .trip:        return false
            }
        }
    }

    private var posterCard: WorldPosterCardView {
        WorldPosterCardView(
            visitedCodes: stats.countries.map(\.id),
            coastline: posterCoastline,
            borderRings: posterRings,
            profileEmoji: appVM.profileEmoji,
            title: "My World"
        )
    }

    private var model: ShareCardModel {
        ShareCardModel.make(type: type, stats: stats, profile: profile, trip: selectedTrip ?? trips.first)
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasData {
                    composer
                } else {
                    ContentUnavailableView("No travel data available",
                                           systemImage: "map",
                                           description: Text("Scan your photos to create a shareable card."))
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showPaywall) { LifetimePaywallView() }
            .task {
                // Keep free users on a template they're entitled to (the poster counts).
                if isFree, !isUnlocked(type) {
                    type = freeType
                    background = .map
                    photo = nil
                }
            }
            // Also fires on first appear, so it covers the poster being the default.
            .task(id: type) {
                if type == .poster { await loadPosterArtwork() }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        photo = img
                        background = .photo
                    }
                }
            }
        }
    }

    private var composer: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Live preview (vector → stays crisp)
                cardPreview
                    .padding(.top, 12)

                templatePicker
                // The poster brings its own artwork, so there's no background to pick.
                if !type.usesOwnArtwork {
                    backgroundPicker
                }

                if type == .trip, trips.count > 1 {
                    tripPicker
                }

                shareButton
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var cardPreview: some View {
        if type == .poster {
            posterPreview
        } else {
            standardPreview
        }
    }

    private var posterPreview: some View {
        let scale: CGFloat = 0.78
        return ZStack {
            posterCard
                .frame(width: WorldPosterCardView.canvasSize.width,
                       height: WorldPosterCardView.canvasSize.height)
            if posterLoading { ProgressView().tint(.white) }
        }
        .scaleEffect(scale)
        .frame(width: WorldPosterCardView.canvasSize.width * scale,
               height: WorldPosterCardView.canvasSize.height * scale)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }

    private var standardPreview: some View {
        let scale: CGFloat = 0.78
        return ShareCardView(model: model, background: background, photo: photo)
            .frame(width: ShareCardView.canvasSize.width, height: ShareCardView.canvasSize.height)
            .scaleEffect(scale)
            .frame(width: ShareCardView.canvasSize.width * scale,
                   height: ShareCardView.canvasSize.height * scale)
            .background(
                // checkerboard hint so transparent margins are obvious
                background == .transparent ? AnyView(TransparencyChecker()) : AnyView(Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Template").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableTypes) { kind in
                        chip(kind.pickerTitle, selected: type == kind, locked: !isUnlocked(kind)) {
                            if isUnlocked(kind) {
                                withAnimation(.spring(response: 0.3)) { type = kind }
                            } else {
                                showPaywall = true
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backgroundPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Background").font(.headline)
            HStack(spacing: 10) {
                ForEach(ShareCardBackground.allCases) { bg in
                    if !isUnlocked(bg) {
                        Button { showPaywall = true } label: {
                            chipLabel(bg.pickerTitle, systemImage: bg.systemImage,
                                      selected: false, locked: true)
                        }
                    } else if bg == .photo {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            chipLabel(bg.pickerTitle, systemImage: bg.systemImage,
                                      selected: background == .photo)
                        }
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.3)) { background = bg }
                        } label: {
                            chipLabel(bg.pickerTitle, systemImage: bg.systemImage,
                                      selected: background == bg)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tripPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trip").font(.headline)
            Menu {
                ForEach(trips) { trip in
                    Button("\(trip.flag) \(trip.displayName) · \(trip.dateRangeText)") { selectedTrip = trip }
                }
            } label: {
                HStack {
                    Text(selectedTrip.map { "\($0.flag) \($0.displayName) · \($0.dateRangeText)" } ?? "Choose a trip")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shareButton: some View {
        Button {
            let image: UIImage? = type == .poster
                ? ShareCardRenderer.render(posterCard,
                                           baseSize: WorldPosterCardView.canvasSize,
                                           opaque: true)
                : ShareCardRenderer.image(model: model, background: background, photo: photo)
            if let image { SharePresenter.present([image]) }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .disabled(type == .poster && posterLoading)
    }

    // MARK: - Poster artwork

    /// Loads the world outline and the visited countries' borders, once. The heavy
    /// simplification runs off the main actor so the composer stays responsive.
    private func loadPosterArtwork() async {
        guard !posterLoaded, !posterLoading else { return }
        posterLoading = true

        let lines = await WorldOutline.shared.polylines()
        let raw = await appVM.borderRings(for: stats.countries.map(\.id))
        let prepared = await Task.detached(priority: .userInitiated) {
            var result: [String: [[CLLocationCoordinate2D]]] = [:]
            for (code, rings) in raw {
                let cleaned = PosterMapGeometry.prepare(rings: rings)
                if !cleaned.isEmpty { result[code] = cleaned }
            }
            return result
        }.value

        posterCoastline = lines
        posterRings = prepared
        posterLoaded = true
        posterLoading = false
    }

    // MARK: - Small components

    private func chip(_ title: String, selected: Bool, locked: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                if locked { Image(systemName: "lock.fill").font(.caption2) }
            }
            .font(.subheadline.weight(selected ? .semibold : .regular))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(selected ? .white : (locked ? .secondary : .primary))
        }
    }

    private func chipLabel(_ title: String, systemImage: String, selected: Bool,
                           locked: Bool = false) -> some View {
        HStack(spacing: 5) {
            Label(title, systemImage: locked ? "lock.fill" : systemImage)
        }
        .font(.subheadline.weight(selected ? .semibold : .regular))
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
        .foregroundStyle(selected ? .white : (locked ? .secondary : .primary))
    }

    private static func defaultType(stats: TravelStats,
                                    profile: TravelPersonalityProfile?,
                                    trips: [Trip]) -> ShareCardType {
        // The world poster leads — it's the most striking card and it's free for everyone.
        if stats.countryCount > 0 { return .poster }
        if profile?.isMeaningful ?? false { return .personality }
        if stats.countryCount > 0 { return .summary }
        if !stats.wonders.isEmpty { return .wonders }
        if !trips.isEmpty { return .trip }
        return .summary
    }
}

/// Simple checkerboard to visualize transparency in the preview.
private struct TransparencyChecker: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 12
            let cols = Int(size.width / tile) + 1
            let rows = Int(size.height / tile) + 1
            for r in 0..<rows {
                for c in 0..<cols where (r + c).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(c) * tile, y: CGFloat(r) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(.gray.opacity(0.18)))
                }
            }
        }
    }
}
