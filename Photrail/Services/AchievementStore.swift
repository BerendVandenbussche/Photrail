import Foundation

/// Persists which achievement IDs the user has unlocked, so newly-earned ones can be
/// detected (and celebrated) exactly once. Mirrors the lightweight UserDefaults stores
/// used elsewhere (e.g. `TripNameStore`).
enum AchievementStore {
    private static let key = "unlockedAchievements"

    static func load() -> Set<String> {
        let ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(ids)
    }

    static func save(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}
