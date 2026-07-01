import SwiftUI
import PhotosUI

/// Lets the user pick a template + background, preview the premium card, and share it.
struct ShareComposerView: View {
    let stats: TravelStats
    let profile: TravelPersonalityProfile?
    let trips: [Trip]

    @Environment(\.dismiss) private var dismiss

    @State private var type: ShareCardType
    @State private var background: ShareCardBackground = .map
    @State private var selectedTrip: Trip?
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?

    init(stats: TravelStats, profile: TravelPersonalityProfile?, trips: [Trip]) {
        self.stats = stats
        self.profile = profile
        self.trips = trips
        _type = State(initialValue: Self.defaultType(stats: stats, profile: profile, trips: trips))
        _selectedTrip = State(initialValue: trips.first)
    }

    private var hasData: Bool { stats.totalGeotaggedPhotos > 0 }

    private var availableTypes: [ShareCardType] {
        ShareCardType.allCases.filter { kind in
            switch kind {
            case .summary:     return stats.countryCount > 0
            case .personality: return profile?.isMeaningful ?? false
            case .wonders:     return !stats.wonders.isEmpty
            case .trip:        return !trips.isEmpty
            }
        }
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
                backgroundPicker

                if type == .trip, trips.count > 1 {
                    tripPicker
                }

                shareButton
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
    }

    private var cardPreview: some View {
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
                        chip(kind.pickerTitle, selected: type == kind) {
                            withAnimation(.spring(response: 0.3)) { type = kind }
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
                    if bg == .photo {
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
            if let image = ShareCardRenderer.image(model: model, background: background, photo: photo) {
                SharePresenter.present([image])
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Small components

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
    }

    private func chipLabel(_ title: String, systemImage: String, selected: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(selected ? .semibold : .regular))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(selected ? .white : .primary)
    }

    private static func defaultType(stats: TravelStats,
                                    profile: TravelPersonalityProfile?,
                                    trips: [Trip]) -> ShareCardType {
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
