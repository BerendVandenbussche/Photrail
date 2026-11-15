import GameKit
import UIKit

/// Game Center: achievements and leaderboards, so friends can compare without a backend.
///
/// Opt-in (`AppViewModel.gameCenterEnabled`): nothing here runs until the user turns it on in
/// Profile, and every call is a no-op while the player isn't signed in.
///
/// The identifiers must match what's set up in App Store Connect:
/// - achievements: `photrail.achievement.<AchievementCatalog id>`
/// - leaderboards: see `Leaderboard`
@MainActor
enum GameCenterService {
    static let achievementPrefix = "photrail.achievement."

    enum Leaderboard {
        static let countries = "photrail.leaderboard.countries"
        static let cities = "photrail.leaderboard.cities"
        static let distance = "photrail.leaderboard.distance"
        /// Highest point reached on a trip, in metres. Plane photos are filtered out upstream.
        static let altitude = "photrail.leaderboard.altitude"
    }

    static var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    /// Signs the player in. `interactive` shows Apple's sign-in sheet when needed (turning the
    /// toggle on); otherwise a player who isn't signed in on this iPhone just stays signed out
    /// (on launch — no sheet the user didn't ask for).
    static func authenticate(interactive: Bool) async -> Bool {
        if GKLocalPlayer.local.isAuthenticated { return true }
        let once = Once()
        return await withCheckedContinuation { continuation in
            GKLocalPlayer.local.authenticateHandler = { viewController, _ in
                Task { @MainActor in
                    // No floating Game Center button over the app.
                    GKAccessPoint.shared.isActive = false
                    if let viewController, interactive, !once.done,
                       let top = SharePresenter.topViewController() {
                        // The handler fires again once the user signs in or cancels.
                        top.present(viewController, animated: true)
                        return
                    }
                    guard !once.done else { return }
                    once.done = true
                    continuation.resume(returning: GKLocalPlayer.local.isAuthenticated)
                }
            }
        }
    }

    /// Reports every unlocked achievement. Idempotent: Game Center keeps the highest value,
    /// and Photrail shows its own unlock toast, so Game Center's banner stays off.
    static func report(achievementIDs: Set<String>) async {
        guard isAuthenticated, !achievementIDs.isEmpty else { return }
        let achievements = achievementIDs.sorted().map { id in
            let achievement = GKAchievement(identifier: achievementPrefix + id)
            achievement.percentComplete = 100
            achievement.showsCompletionBanner = false
            return achievement
        }
        try? await GKAchievement.report(achievements)
    }

    /// Submits the leaderboard numbers. "Best score" leaderboards keep the highest, so a
    /// lower number after excluding photos doesn't lower the rank — acceptable for a hobby
    /// comparison.
    static func submit(countries: Int, cities: Int, distanceKm: Int, altitudeMeters: Int) async {
        guard isAuthenticated else { return }
        let player = GKLocalPlayer.local
        var scores = [(countries, Leaderboard.countries),
                      (cities, Leaderboard.cities),
                      (distanceKm, Leaderboard.distance)]
        // No altitude in any photo: stay off that leaderboard rather than post a 0.
        if altitudeMeters > 0 { scores.append((altitudeMeters, Leaderboard.altitude)) }
        for (score, id) in scores {
            try? await GKLeaderboard.submitScore(score, context: 0, player: player, leaderboardIDs: [id])
        }
    }

    // MARK: - Friends

    /// The leaderboards friends can compare on, in the order the Friends screen shows them.
    enum Board: String, CaseIterable, Identifiable {
        case countries, cities, distance, altitude

        var id: String { rawValue }

        var leaderboardID: String {
            switch self {
            case .countries: Leaderboard.countries
            case .cities: Leaderboard.cities
            case .distance: Leaderboard.distance
            case .altitude: Leaderboard.altitude
            }
        }

        var title: LocalizedStringResource {
            switch self {
            case .countries: "Countries"
            case .cities: "Cities"
            case .distance: "Distance"
            case .altitude: "Altitude"
            }
        }

        var systemImage: String {
            switch self {
            case .countries: "flag.fill"
            case .cities: "building.2.fill"
            case .distance: "airplane"
            case .altitude: "mountain.2.fill"
            }
        }

        /// A score as the user reads it: kilometres and metres with their unit.
        func formatted(_ score: Int) -> String {
            switch self {
            case .countries, .cities:
                return score.formatted()
            case .distance:
                return Measurement(value: Double(score), unit: UnitLength.kilometers)
                    .formatted(.measurement(width: .abbreviated, usage: .road,
                                            numberFormatStyle: .number.precision(.fractionLength(0))))
            case .altitude:
                return Measurement(value: Double(score), unit: UnitLength.meters)
                    .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                            numberFormatStyle: .number.precision(.fractionLength(0))))
            }
        }
    }

    /// One person on a friends leaderboard: a friend, or the player themself.
    struct FriendEntry: Identifiable, Equatable {
        let player: GKPlayer
        /// 1 is the best, counted among friends only.
        let rank: Int
        let score: Int
        let isMe: Bool

        var id: String { player.gamePlayerID }
        var name: String { player.displayName }
    }

    /// The player and their Game Center friends on `board`, best first. Only the player
    /// themself when they have no friends on it yet; empty when nobody has a score.
    static func friendsRanking(_ board: Board) async throws -> [FriendEntry] {
        guard isAuthenticated,
              let leaderboard = try await GKLeaderboard.loadLeaderboards(IDs: [board.leaderboardID]).first
        else { return [] }
        let (local, entries, _) = try await leaderboard.loadEntries(
            for: .friendsOnly, timeScope: .allTime, range: NSRange(location: 1, length: 100))
        // Typed explicitly so this reads the same whether the SDK marks them optional or not.
        let listed: [GKLeaderboard.Entry]? = entries
        let localEntry: GKLeaderboard.Entry? = local
        var all = listed ?? []
        if let local = localEntry, !all.contains(where: { $0.player.gamePlayerID == local.player.gamePlayerID }) {
            all.append(local)
        }
        let me = GKLocalPlayer.local.gamePlayerID
        // Ranked here rather than trusting `rank`, so ties and the added local entry line up.
        return all
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.player.displayName < $1.player.displayName }
            .enumerated()
            .map { index, entry in
                FriendEntry(player: entry.player, rank: index + 1, score: entry.score,
                            isMe: entry.player.gamePlayerID == me)
            }
    }

    /// Apple's sheet to send a friend request (by message or link).
    static func inviteFriend() {
        guard isAuthenticated, let top = SharePresenter.topViewController() else { return }
        try? GKLocalPlayer.local.presentFriendRequestCreator(from: top)
    }

    /// Apple's sheet on one leaderboard, filtered to friends.
    static func showLeaderboard(_ board: Board) {
        guard isAuthenticated, let top = SharePresenter.topViewController() else { return }
        let controller = GKGameCenterViewController(leaderboardID: board.leaderboardID,
                                                    playerScope: .friendsOnly, timeScope: .allTime)
        controller.gameCenterDelegate = DashboardDelegate.shared
        top.present(controller, animated: true)
    }

    /// Apple's Game Center dashboard: leaderboards with a friends filter, and achievements.
    static func showDashboard() {
        guard isAuthenticated, let top = SharePresenter.topViewController() else { return }
        let controller = GKGameCenterViewController(state: .dashboard)
        controller.gameCenterDelegate = DashboardDelegate.shared
        top.present(controller, animated: true)
    }

    private final class Once { var done = false }

    private final class DashboardDelegate: NSObject, GKGameCenterControllerDelegate {
        static let shared = DashboardDelegate()
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
