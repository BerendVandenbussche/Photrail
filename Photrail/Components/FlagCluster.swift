import SwiftUI

/// A fixed-size circular badge that arranges one or more country flags in a tidy
/// composition — so rows with different country counts stay aligned.
struct FlagCluster: View {
    let flags: [String]
    var size: CGFloat = 44

    private enum Tile { case flag(String); case more(Int) }

    /// Up to four tiles; a 5th+ country collapses into a "+N" tile.
    private var tiles: [Tile] {
        if flags.count <= 4 { return flags.map { .flag($0) } }
        return flags.prefix(3).map { Tile.flag($0) } + [.more(flags.count - 3)]
    }

    var body: some View {
        ZStack {
            Circle().fill(Color(.tertiarySystemFill))
            if flags.isEmpty {
                Image(systemName: "globe").font(.system(size: size * 0.42)).foregroundStyle(.secondary)
            } else if flags.count == 1 {
                Text(flags[0]).font(.system(size: size * 0.5))
            } else {
                grid
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
    }

    @ViewBuilder
    private var grid: some View {
        let cell = tiles.count <= 2 ? size * 0.4 : size * 0.3
        if tiles.count == 3 {
            // One on top, two below — balanced inside the circle.
            VStack(spacing: 1) {
                tile(tiles[0], cell: cell)
                HStack(spacing: 1) { tile(tiles[1], cell: cell); tile(tiles[2], cell: cell) }
            }
        } else {
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    tile(tiles[0], cell: cell)
                    if tiles.count > 1 { tile(tiles[1], cell: cell) }
                }
                if tiles.count > 2 {
                    HStack(spacing: 1) {
                        tile(tiles[2], cell: cell)
                        if tiles.count > 3 { tile(tiles[3], cell: cell) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ tile: Tile, cell: CGFloat) -> some View {
        switch tile {
        case .flag(let f):
            Text(f).font(.system(size: cell))
        case .more(let n):
            Text("+\(n)")
                .font(.system(size: cell * 0.62, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: cell, height: cell)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        FlagCluster(flags: ["🇫🇷"])
        FlagCluster(flags: ["🇫🇷", "🇮🇹"])
        FlagCluster(flags: ["🇫🇷", "🇮🇹", "🇨🇭"])
        FlagCluster(flags: ["🇫🇷", "🇮🇹", "🇨🇭", "🇩🇪"])
        FlagCluster(flags: ["🇫🇷", "🇮🇹", "🇨🇭", "🇩🇪", "🇪🇸", "🇧🇪"])
    }
    .padding()
}
