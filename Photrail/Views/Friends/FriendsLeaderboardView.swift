import GameKit
import SwiftUI

/// Your Game Center friends ranked on countries, cities, distance and highest point, right in
/// Photrail instead of only in Apple's Game Center sheet. Opened from the Dashboard card and
/// from Profile.
struct FriendsLeaderboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var board: GameCenterService.Board
    @State private var loading = false

    init(board: GameCenterService.Board = .countries) {
        _board = State(initialValue: board)
    }

    private var entries: [GameCenterService.FriendEntry] { appVM.friendRankings[board] ?? [] }
    /// Anyone else on any leaderboard: once one friend shows up, the others are just missing a score.
    private var hasFriends: Bool {
        appVM.friendRankings.values.contains { $0.contains { !$0.isMe } }
    }

    var body: some View {
        Group {
            if !appVM.gameCenterEnabled {
                ContentUnavailableView {
                    Label("Compare with friends", systemImage: "person.2.fill")
                } description: {
                    Text("Turn on Game Center to see how your countries, cities and kilometres rank among your friends.")
                } actions: {
                    Button("Turn on Game Center") { appVM.gameCenterEnabled = true }
                        .buttonStyle(.borderedProminent)
                }
            } else if appVM.gameCenterSignedIn == false {
                ContentUnavailableView {
                    Label("Not signed in to Game Center", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("Sign in to Game Center in Settings to compare with your friends.")
                } actions: {
                    Button("Try again") { Task { await appVM.retryGameCenterSignIn() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if !appVM.friendRankingsLoaded {
                loadingList
            } else if !hasFriends {
                ContentUnavailableView {
                    Label("No friends on Game Center yet", systemImage: "person.2.fill")
                } description: {
                    Text("Add friends in Game Center to compare your travels.")
                } actions: {
                    Button("Invite a friend") { GameCenterService.inviteFriend() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                list
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if appVM.gameCenterEnabled, appVM.gameCenterSignedIn == true {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { GameCenterService.inviteFriend() } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel(Text("Invite a friend"))
                }
            }
        }
        .task(id: appVM.gameCenterEnabled) { await appVM.refreshFriendRankings(force: true) }
    }

    private var list: some View {
        List {
            Section {
                Picker("Leaderboard", selection: $board) {
                    ForEach(GameCenterService.Board.allCases) { board in
                        Text(board.title).tag(board)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: board)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                if entries.isEmpty {
                    Text("No scores yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        FriendRankRow(entry: entry, board: board)
                            .listRowBackground(entry.isMe ? Color.accentColor.opacity(0.12) : nil)
                    }
                }
            } footer: {
                Button("See in Game Center") { GameCenterService.showLeaderboard(board) }
                    .font(.footnote.weight(.medium))
                    .padding(.top, 6)
            }
        }
        .animation(Motion.smooth, value: board)
        .refreshable {
            await appVM.refreshFriendRankings(force: true)
            Haptics.soft()
        }
    }

    /// Placeholder rows in the shape of the real list while Game Center answers.
    private var loadingList: some View {
        List {
            Section {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: 12) {
                        Text(verbatim: "#\(index + 1)").frame(width: 30)
                        Circle().fill(.quaternary).frame(width: 36, height: 36)
                        Text(verbatim: "Placeholder name")
                        Spacer()
                        Text(verbatim: "00")
                    }
                    .redacted(reason: .placeholder)
                    .shimmering()
                }
            }
        }
        .accessibilityLabel(Text("Loading"))
    }
}

/// One line on a friends leaderboard: rank (a medal for the top three), photo, name, score.
struct FriendRankRow: View {
    let entry: GameCenterService.FriendEntry
    let board: GameCenterService.Board

    var body: some View {
        HStack(spacing: 12) {
            RankBadge(rank: entry.rank)
                .frame(width: 30)
            PlayerAvatar(entry: entry, size: 36)
            if entry.isMe {
                Text("You").font(.body.weight(.semibold))
            } else {
                Text(verbatim: entry.name).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(verbatim: board.formatted(entry.score))
                .font(.body.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText(value: Double(entry.score)))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// 🥇🥈🥉, then "#4".
struct RankBadge: View {
    let rank: Int

    var body: some View {
        switch rank {
        case 1: Text(verbatim: "🥇").font(.title3)
        case 2: Text(verbatim: "🥈").font(.title3)
        case 3: Text(verbatim: "🥉").font(.title3)
        default:
            Text(verbatim: "#\(rank)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// A friend's Game Center photo (their initial until it loads, or when they have none);
/// for the player themself, their Photrail emoji.
struct PlayerAvatar: View {
    let entry: GameCenterService.FriendEntry
    let size: CGFloat

    @Environment(AppViewModel.self) private var appVM
    @State private var photo: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            if entry.isMe {
                Text(verbatim: appVM.profileEmoji).font(.system(size: size * 0.55))
            } else if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Text(verbatim: String(entry.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: entry.id) {
            guard !entry.isMe else { return }
            photo = try? await entry.player.loadPhoto(for: .small)
        }
    }
}
