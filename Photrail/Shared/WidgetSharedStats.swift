import Foundation

/// A compact, Codable snapshot of travel stats that the app publishes to a shared
/// App Group container so the widget extension (a separate process) can render it
/// without opening the SwiftData store.
///
/// IMPORTANT: This file must be a member of BOTH the app target and the widget
/// extension target (check Target Membership in the File Inspector).
struct WidgetSharedStats: Codable, Equatable {
    var countryCount: Int
    var cityCount: Int
    var visitedContinents: Int
    var totalContinents: Int
    var worldPercentage: Double
    var totalPhotos: Int
    var topCountryName: String?
    var topCountryFlag: String?
    var hasVisitedAntarctica: Bool
    var sevenWondersSeen: Int
    var totalWondersSeen: Int
    var seenWonderEmojis: [String]
    var updatedAt: Date

    static let placeholder = WidgetSharedStats(
        countryCount: 24,
        cityCount: 68,
        visitedContinents: 4,
        totalContinents: 6,
        worldPercentage: 12.3,
        totalPhotos: 1_247,
        topCountryName: "Japan",
        topCountryFlag: "🇯🇵",
        hasVisitedAntarctica: false,
        sevenWondersSeen: 3,
        totalWondersSeen: 9,
        seenWonderEmojis: ["🗼", "🏛️", "🕌", "🗽", "🌉", "🗻"],
        updatedAt: .now
    )

    static let empty = WidgetSharedStats(
        countryCount: 0,
        cityCount: 0,
        visitedContinents: 0,
        totalContinents: 6,
        worldPercentage: 0,
        totalPhotos: 0,
        topCountryName: nil,
        topCountryFlag: nil,
        hasVisitedAntarctica: false,
        sevenWondersSeen: 0,
        totalWondersSeen: 0,
        seenWonderEmojis: [],
        updatedAt: .distantPast
    )

    var worldPercentageText: String {
        String(format: "%.1f%%", worldPercentage)
    }
}

/// Reads/writes the shared snapshot via the App Group container.
enum WidgetSharedStore {
    /// The App Group identifier. Must be enabled on BOTH targets' Signing & Capabilities.
    static let appGroup = "group.com.berend.photrail"
    private static let key = "widgetSharedStats"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func save(_ stats: WidgetSharedStats) {
        guard let defaults, let data = try? JSONEncoder().encode(stats) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetSharedStats {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let stats = try? JSONDecoder().decode(WidgetSharedStats.self, from: data)
        else { return .empty }
        return stats
    }
}
