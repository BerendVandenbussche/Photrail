import SwiftUI

/// A titled 3-column photo grid where tapping any photo opens a full-screen,
/// zoomable viewer. Shared across the country / trip / wonder detail pages so
/// photo behavior is consistent everywhere.
struct PhotoGridSection: View {
    var title: LocalizedStringKey = "Photos"
    let photoIDs: [String]
    var limit: Int = 90
    /// Optional heart-rate "vibe" per photo, from the Trip Insights module. When present,
    /// a small badge is overlaid on the tile and carried into the full-screen viewer.
    var excitementByPhotoID: [String: ExcitementSample] = [:]

    @State private var selected: IdentifiedPhoto?
    private struct IdentifiedPhoto: Identifiable { let id: String }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
                .padding(.horizontal, 20)

            if photoIDs.isEmpty {
                Text("No photos available")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(photoIDs.prefix(limit), id: \.self) { id in
                        Button { selected = IdentifiedPhoto(id: id) } label: {
                            PhotoThumbnail(assetID: id,
                                           size: (UIScreen.main.bounds.width - 4) / 3,
                                           cornerRadius: 0)
                                .overlay(alignment: .topTrailing) {
                                    if let sample = excitementByPhotoID[id] {
                                        Text(sample.badge.emoji)
                                            .font(.system(size: 13))
                                            .padding(4)
                                            .background(Circle().fill(.black.opacity(0.35)))
                                            .padding(4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .fullScreenCover(item: $selected) {
            FullScreenPhotoView(assetID: $0.id, excitement: excitementByPhotoID[$0.id])
        }
    }
}
