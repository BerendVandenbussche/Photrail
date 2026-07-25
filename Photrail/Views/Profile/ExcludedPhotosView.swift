import SwiftUI

/// Shows every photo the user has excluded from evaluation, with one-tap restore.
/// Tapping a photo opens the full-screen viewer, where it can also be re-included.
struct ExcludedPhotosView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var selected: IdentifiedPhoto?
    @State private var showRestoreAllConfirm = false
    private struct IdentifiedPhoto: Identifiable { let id: String }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var ids: [String] { appVM.excludedPhotoIDs.sorted() }

    var body: some View {
        ScrollView {
            if ids.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("These photos don't count toward any of your stats, trips or memories. Tap one to restore it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(ids, id: \.self) { id in
                            Button { selected = IdentifiedPhoto(id: id) } label: {
                                PhotoThumbnail(assetID: id,
                                               size: (UIScreen.main.bounds.width - 4) / 3,
                                               cornerRadius: 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Excluded Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !ids.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore All") { showRestoreAllConfirm = true }
                }
            }
        }
        .confirmationDialog("Restore all excluded photos?",
                            isPresented: $showRestoreAllConfirm, titleVisibility: .visible) {
            Button("Restore All") { appVM.includePhotos(ids: ids) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They'll count toward your stats, trips and memories again.")
        }
        .fullScreenCover(item: $selected) { FullScreenPhotoView(assetID: $0.id) }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "eye.slash")
                .font(.system(size: 32)).foregroundStyle(.tertiary)
            Text("No excluded photos")
                .font(.headline)
            Text("Exclude a photo from the full-screen viewer to keep it out of your stats.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}

#Preview {
    NavigationStack {
        ExcludedPhotosView().environment(AppViewModel.preview)
    }
}
