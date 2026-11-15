import SwiftUI

/// Dashboard: where you stand among your Game Center friends, so the comparison isn't hidden
/// in Profile. With Game Center off it invites you to turn it on; without friends there it
/// offers to invite one. Both of those can be hidden. Taps open `FriendsLeaderboardView`.
struct FriendsSection: View {
    @Environment(AppViewModel.self) private var appVM
    @AppStorage("friendsInviteDismissed") private var inviteDismissed = false
    @AppStorage("friendsEmptyDismissed") private var emptyDismissed = false

    private typealias Board = GameCenterService.Board
    private typealias Entry = GameCenterService.FriendEntry

    /// The first leaderboard (countries, normally) where you and at least one friend have a score.
    private var headline: (board: Board, entries: [Entry], me: Entry)? {
        for board in Board.allCases {
            if let entries = appVM.friendRankings[board], entries.count > 1,
               let me = entries.first(where: \.isMe) {
                return (board, entries, me)
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !appVM.gameCenterEnabled {
                if !inviteDismissed {
                    header
                    turnOnCard
                }
            } else if let headline {
                header
                NavigationLink { FriendsLeaderboardView(board: headline.board) } label: {
                    rankingCard(headline)
                }
                .buttonStyle(.pressable)
            } else if appVM.friendRankingsLoaded, appVM.gameCenterSignedIn == true, !emptyDismissed {
                header
                noFriendsCard
            }
        }
        .padding(.horizontal, 20)
        .task(id: appVM.gameCenterEnabled) { await appVM.refreshFriendRankings() }
    }

    private var header: some View {
        SectionHeader(title: "Friends", systemImage: "person.2.fill")
    }

    // MARK: Ranking

    private func rankingCard(_ headline: (board: Board, entries: [Entry], me: Entry)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(headline.me.rank) of \(headline.entries.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: Double(headline.me.rank)))
                    Text(headline.board.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 8) {
                ForEach(neighbours(of: headline.me, in: headline.entries)) { entry in
                    FriendRankRow(entry: entry, board: headline.board)
                }
            }

            let others = otherRanks(besides: headline.board)
            if !others.isEmpty {
                Divider()
                HStack(spacing: 0) {
                    ForEach(others) { item in
                        VStack(spacing: 4) {
                            RankBadge(rank: item.rank)
                            Text(item.board.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(AppCard.padding)
        .card()
        .contentShape(Rectangle())
    }

    /// You and the friends just above and below you: three rows at most.
    private func neighbours(of me: Entry, in entries: [Entry]) -> [Entry] {
        guard let index = entries.firstIndex(of: me) else { return Array(entries.prefix(3)) }
        let start = max(0, min(index - 1, entries.count - 3))
        return Array(entries[start..<min(entries.count, start + 3)])
    }

    /// Your rank on each other leaderboard you and a friend have a score on.
    private struct OtherRank: Identifiable {
        let board: Board
        let rank: Int
        var id: Board { board }
    }

    private func otherRanks(besides headline: Board) -> [OtherRank] {
        Board.allCases.compactMap { board in
            guard board != headline, let entries = appVM.friendRankings[board], entries.count > 1,
                  let me = entries.first(where: \.isMe) else { return nil }
            return OtherRank(board: board, rank: me.rank)
        }
    }

    // MARK: Invitations

    private var turnOnCard: some View {
        promptCard(icon: "gamecontroller.fill",
                   title: "Compare with friends",
                   message: "Turn on Game Center to see how your countries, cities and kilometres rank among your friends.",
                   action: "Turn on Game Center",
                   perform: { appVM.gameCenterEnabled = true },
                   dismiss: { inviteDismissed = true })
    }

    private var noFriendsCard: some View {
        promptCard(icon: "person.badge.plus",
                   title: "No friends on Game Center yet",
                   message: "Add friends in Game Center to compare your travels.",
                   action: "Invite a friend",
                   perform: { GameCenterService.inviteFriend() },
                   dismiss: { emptyDismissed = true })
    }

    private func promptCard(icon: String, title: LocalizedStringKey, message: LocalizedStringKey,
                            action: LocalizedStringKey, perform: @escaping () -> Void,
                            dismiss: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Hide suggestion"))
            }
            Button(action: perform) {
                Text(action).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(AppCard.padding)
        .card()
    }
}
