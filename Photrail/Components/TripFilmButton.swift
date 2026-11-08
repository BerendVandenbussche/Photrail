import SwiftUI

/// "▶ Watch trip film" on the trip page's cover photo. Without it the film is only reachable
/// through the toolbar's share icon, and most people never find it.
struct TripFilmButton: View {
    let status: FreeFilmAllowance.Status

    var body: some View {
        HStack(spacing: 8) {
            Label("Watch trip film", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
            badge
        }
        .foregroundStyle(.white)
        .padding(.leading, 14)
        .padding(.trailing, status == .freeLeft || status == .locked ? 6 : 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .environment(\.colorScheme, .dark)
        .contentShape(Capsule())
    }

    /// Free users only: whether the film is still free.
    @ViewBuilder
    private var badge: some View {
        switch status {
        case .freeLeft:
            Text("1 free")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.accentColor, in: Capsule())
        case .locked:
            Image(systemName: "lock.fill")
                .font(.caption2.weight(.bold))
                .padding(6)
                .background(.white.opacity(0.2), in: Circle())
        case .unlimited, .thisTripIsFree:
            EmptyView()
        }
    }
}
