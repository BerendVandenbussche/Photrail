import SwiftUI
import Photos

/// "On this day" — resurfaces photos taken on today's calendar day in past years.
struct OnThisDaySection: View {
    let memories: [Memory]
    @State private var selected: Memory?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "On This Day", systemImage: "clock.arrow.circlepath")
                .padding(.horizontal, 20)

            if memories.count == 1, let memory = memories.first {
                Button { selected = memory } label: { MemoryCard(memory: memory) }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(memories) { memory in
                            Button { selected = memory } label: {
                                MemoryCard(memory: memory).frame(width: 300)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(item: $selected) { memory in MemoryDetailView(memory: memory) }
    }
}

// MARK: - Card

private struct MemoryCard: View {
    let memory: Memory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MemoryCover(assetID: memory.coverPhotoID)
                .frame(height: 180)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text(memory.yearsAgoText.uppercased())
                    .font(.system(size: 12, weight: .bold)).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(memory.flag) \(memory.placeText)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(L.photos(memory.photoCount)) · \(memory.year.description)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous))
    }
}

/// A rectangular cover loader (PhotoThumbnail is square-only).
private struct MemoryCover: View {
    let assetID: String?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color(red: 0.31, green: 0.27, blue: 0.9),
                                        Color(red: 0.55, green: 0.3, blue: 0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: assetID) { image = await load() }
    }

    private func load() async -> UIImage? {
        guard let assetID else { return nil }
        return await withCheckedContinuation { continuation in
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
            else { continuation.resume(returning: nil); return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 800, height: 480),
                contentMode: .aspectFill, options: options
            ) { img, _ in continuation.resume(returning: img) }
        }
    }
}

// MARK: - Detail

private struct MemoryDetailView: View {
    let memory: Memory
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM

    private let columns = [GridItem(.flexible(), spacing: 3),
                           GridItem(.flexible(), spacing: 3),
                           GridItem(.flexible(), spacing: 3)]

    @State private var selected: IdentifiedPhoto?
    private struct IdentifiedPhoto: Identifiable { let id: String }

    /// The trip these memory photos belong to (the one sharing the most photo IDs).
    private var trip: Trip? {
        let ids = Set(memory.photoIDs)
        return appVM.stats.trips
            .map { (trip: $0, overlap: $0.photoIDs.reduce(0) { ids.contains($1) ? $0 + 1 : $0 }) }
            .filter { $0.overlap > 0 }
            .max { $0.overlap < $1.overlap }?
            .trip
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(memory.flag) \(memory.placeText)")
                        .font(.title2.weight(.bold))
                    Text("\(memory.yearsAgoText) · \(fullDate)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if let trip {
                    NavigationLink { TripDetailView(trip: trip) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "map")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("View trip").font(.subheadline.weight(.semibold))
                                Text(trip.displayName).font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .card(cornerRadius: AppCard.chipRadius)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(memory.photoIDs, id: \.self) { id in
                        Button { selected = IdentifiedPhoto(id: id) } label: {
                            PhotoThumbnail(assetID: id, size: tileSize, cornerRadius: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 3)
            }
            .navigationTitle("On This Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .fullScreenCover(item: $selected) { FullScreenPhotoView(assetID: $0.id) }
        }
    }

    private var tileSize: CGFloat { (UIScreen.main.bounds.width - 12) / 3 }

    private var fullDate: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: memory.date)
    }
}
