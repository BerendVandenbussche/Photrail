import SwiftUI

struct WonderDetailView: View {
    let stat: WonderStat
    /// The trip on which this wonder was seen, if known — enables "View trip".
    var trip: Trip? = nil
    @Environment(\.dismiss) private var dismiss

    private let gridColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    headerSection
                    LocationMiniMap(latitude: stat.wonder.latitude,
                                    longitude: stat.wonder.longitude,
                                    glyph: stat.wonder.emoji,
                                    spanMeters: 40_000)
                        .padding(.horizontal, 20)
                    statsRow
                        .padding(.horizontal, 20)
                    if let trip { tripLink(trip) }
                    photoGridSection
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(stat.wonder.emoji)
                .font(.system(size: 72))
            Text(stat.wonder.name)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text("\(stat.wonder.flagEmoji) \(stat.wonder.category.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func tripLink(_ trip: Trip) -> some View {
        NavigationLink { TripDetailView(trip: trip) } label: {
            HStack(spacing: 14) {
                Image(systemName: "suitcase.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("View this trip").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("\(trip.flag) \(trip.country) · \(trip.dateRangeText)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(AppCard.padding)
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(icon: "photo.stack.fill", value: "\(stat.photoCount)",
                     label: "Photos", iconColor: .blue)
            StatCard(icon: "calendar", value: visitLabel,
                     label: "Visited", iconColor: .pink)
        }
    }

    private var photoGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Photos")
                .padding(.horizontal, 20)

            if stat.photoIDs.isEmpty {
                Text("No photos available")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(stat.photoIDs.prefix(60), id: \.self) { id in
                        PhotoThumbnail(assetID: id, size: (UIScreen.main.bounds.width - 4) / 3,
                                       cornerRadius: 0)
                    }
                }
            }
        }
    }

    private var visitLabel: String {
        guard let last = stat.lastSeen else { return "—" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        return fmt.string(from: last)
    }
}

#Preview {
    WonderDetailView(stat: TravelStats.mock.wonders.first { $0.seen } ?? TravelStats.mock.wonders[0])
}
