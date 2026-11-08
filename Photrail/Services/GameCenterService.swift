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
    static func submit(countries: Int, cities: Int, distanceKm: Int) async {
        guard isAuthenticated else { return }
        let player = GKLocalPlayer.local
        for (score, id) in [(countries, Leaderboard.countries),
                            (cities, Leaderboard.cities),
                            (distanceKm, Leaderboard.distance)] {
            try? await GKLeaderboard.submitScore(score, context: 0, player: player, leaderboardIDs: [id])
        }
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
