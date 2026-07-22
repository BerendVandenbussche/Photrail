import SwiftUI
import Photos

/// Detail for a single trip: a hero photo, key stats, a map of the cities visited
/// (joined in visit order), the itinerary, wonders seen, and the trip's photos.
struct TripDetailView: View {
    let trip: Trip

    @Environment(AppViewModel.self) private var appVM
    @State private var coverImage: UIImage?
    @State private var showSharePreview = false
    @State private var note: String = ""
    @State private var showNoteEditor = false
    @State private var selectedWonder: WonderStat?
    @State private var customName: String?
    @State private var showRenameEditor = false
    /// Per-photo heart-rate "vibe", filled by the insights section, used to badge the grid.
    @State private var excitement: [String: ExcitementSample] = [:]
    /// Cached Health insights for this trip — drives the activity "vibe" pill and the
    /// share card's theme so the two always agree.
    @State private var insights: TripInsights?

    /// The trip's "vibe" pill: the workout-derived activity when there's a strong signal,
    /// otherwise the location-inferred type.
    private var tripType: TripType {
        TripShareTheme.decide(trip: trip, insights: insights).tripTypeOverride ?? trip.tripType
    }

    /// The trip with any just-edited custom name applied, so a rename shows immediately
    /// in this view (header, title, share preview) without waiting for the recompute.
    private var displayTrip: Trip {
        var t = trip
        t.customName = customName
        return t
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                header

                tripTypeBadge

                statsSection

                notesSection

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

                // Health-powered insights come after the trip's own itinerary — the trip
                // itself leads, activity context follows.
                TripInsightsSection(trip: trip, excitement: $excitement)

                PhotoGridSection(photoIDs: trip.photoIDs, limit: 90,
                                 excitementByPhotoID: excitement)
            }
            .padding(.bottom, 8)
        }
        .navigationTitle(displayTrip.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSharePreview = true } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("Share"))
            }
        }
        .sheet(isPresented: $showSharePreview) {
            TripSharePreview(trip: displayTrip, cover: coverImage, insights: insights)
        }
        .sheet(isPresented: $showNoteEditor) {
            TripNoteEditor(text: note) { saved in
                note = saved
                TripNoteStore.setNote(saved, for: trip.id)
            }
        }
        .sheet(isPresented: $showRenameEditor) {
            TripNameEditor(name: customName ?? "", defaultName: trip.englishDisplayName) { saved in
                let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
                customName = trimmed.isEmpty ? nil : trimmed
                appVM.renameTrip(trimmed, tripID: trip.id)
            }
        }
        .sheet(item: $selectedWonder) { WonderDetailView(stat: $0) }
        .task { await loadCover() }
        .task { await loadInsights() }
        .onAppear {
            note = TripNoteStore.note(for: trip.id)
            customName = trip.customName
        }
    }

    private var tripTypeBadge: some View {
        HStack(spacing: 6) {
            Text(tripType.emoji)
            Text(tripType.title).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        .padding(.horizontal, 20)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Notes").padding(.horizontal, 20)

            Button { showNoteEditor = true } label: {
                if note.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil").foregroundStyle(.tint)
                        Text("Add a note").foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(AppCard.padding)
                    .card()
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        Text(appVM.profileEmoji)
                            .font(.system(size: 24))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.accentColor.opacity(0.15)))
                        Text(note)
                            .font(.subheadline).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(AppCard.padding)
                    .card()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
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
                // Tapping the name renames the trip (with a subtle pencil affordance).
                Button { showRenameEditor = true } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(trip.isMultiCountry ? "\(trip.flagsLine)  \(displayTrip.displayName)" : "\(trip.flag) \(displayTrip.displayName)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2).minimumScaleFactor(0.6)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
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
                        Text(LocalizedStringKey(item.label)).font(.caption2).foregroundStyle(.secondary)
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

    /// The full wonder stat (for the detail page) matching a trip's lightweight hit.
    private func wonderStat(for id: String) -> WonderStat? {
        appVM.stats.wonders.first { $0.wonder.id == id }
    }

    private var wondersSectionTitle: LocalizedStringKey {
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
                Button { selectedWonder = wonderStat(for: wonder.id) } label: {
                    HStack(spacing: 14) {
                        if let id = wonder.photoID {
                            PhotoThumbnail(assetID: id, size: 48, cornerRadius: 10)
                        } else {
                            Text(wonder.emoji)
                                .font(.system(size: 30))
                                .frame(width: 48, height: 48)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wonder.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(wonder.isOfficial ? "New 7 Wonder" : "Landmark")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(wonderStat(for: wonder.id) == nil)
                if wonder.id != trip.wonders.last?.id {
                    Divider().padding(.leading, 76)
                }
            }
        }
    }

    // MARK: - Cover + Share

    private func loadCover() async {
        // Reuse the remembered cover if we've curated this trip before — instant, no Vision pass.
        let id: String?
        if let cached = TripCoverStore.coverID(for: trip.id) {
            id = cached
        } else {
            let best = await PhotoCurator().bestPhotos(candidateIDs: trip.photoIDs, category: nil, limit: 1)
            id = best.first ?? trip.photoIDs.first
            if let chosen = id { TripCoverStore.setCoverID(chosen, for: trip.id) }
        }
        guard let id else { return }
        coverImage = await loadImage(id: id, target: CGSize(width: 1080, height: 1080))
    }

    /// Resolve the activity vibe/theme source: cached insights, or a compute if enabled.
    private func loadInsights() async {
        if let cached = appVM.cachedInsights(for: trip) { insights = cached; return }
        guard appVM.insightsEnabled else { return }
        insights = await appVM.computeInsights(for: trip)
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
    /// Cached Health insights, if any — lets the card pick an activity theme (ski, hike…).
    let insights: TripInsights?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM
    /// Resolved insights: the cached value, refined once computed on appear.
    @State private var resolved: TripInsights?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                SharePreviewCanvas(size: TripShareCardView.canvasSize) {
                    TripShareCardView(trip: trip, cover: cover, insights: resolved)
                }
                .task {
                    resolved = insights
                    // Fill the theme in even if the (lazy) insights section hasn't loaded yet.
                    if resolved == nil, appVM.insightsEnabled {
                        resolved = await appVM.computeInsights(for: trip)
                    }
                }

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
            TripShareCardView(trip: trip, cover: cover, insights: resolved),
            baseSize: TripShareCardView.canvasSize,
            opaque: true
        ) {
            SharePresenter.present([image])
        }
    }
}

// MARK: - Name editor

private struct TripNameEditor: View {
    @State var name: String
    /// The auto-generated name (country list), shown as the placeholder + reset target.
    let defaultName: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(defaultName, text: $name)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { onSave(name); dismiss() }
                } footer: {
                    Text("Give this trip your own name, like \u{201C}Summer in Italy\u{201D}. Leave it empty to use the default (\(defaultName)).")
                }

                if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        Button(role: .destructive) {
                            name = ""
                            onSave("")
                            dismiss()
                        } label: {
                            Label("Reset to default name", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
            .navigationTitle("Trip Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onSave(name); dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Note editor

private struct TripNoteEditor: View {
    @State var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .padding(12)
                if text.isEmpty {
                    Text("Write a note about this trip…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 17).padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { onSave(text); dismiss() } }
            }
        }
    }
}
