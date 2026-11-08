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
    /// Whether the user has unlocked Photrail Lifetime. Widgets that surface Lifetime-only
    /// content render an "Unlock" placeholder when this is false. Defaulted so older cached
    /// snapshots (written before this field existed) decode cleanly as not-entitled.
    var hasLifetime: Bool = false

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
        updatedAt: .now,
        hasLifetime: true
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

// MARK: - Trip countdown

/// The trip the countdown widget shows: the plan underway, else the next one. Written by the
/// app whenever plans change; the widget works out the days itself, so the count stays right
/// at midnight without the app running.
struct WidgetCountdown: Codable, Equatable {
    var name: String
    var flag: String
    /// First and last day, each as the start of the day.
    var startDate: Date
    var endDate: Date
    /// IATA codes along the planned flights, e.g. ["BRU", "IST", "NRT"]. Empty without flights.
    var route: [String]

    enum Phase: Equatable {
        case upcoming(days: Int)          // 0 = today
        case underway(day: Int, of: Int)
        case over
    }

    func phase(on date: Date, calendar: Calendar = .current) -> Phase {
        let today = calendar.startOfDay(for: date)
        let days = { (from: Date, to: Date) in calendar.dateComponents([.day], from: from, to: to).day ?? 0 }
        if today < startDate { return .upcoming(days: days(today, startDate)) }
        if today <= endDate {
            return .underway(day: days(startDate, today) + 1, of: days(startDate, endDate) + 1)
        }
        return .over
    }

    static let placeholder = WidgetCountdown(
        name: "Japan", flag: "🇯🇵",
        startDate: Calendar.current.date(byAdding: .day, value: 12,
                                         to: Calendar.current.startOfDay(for: .now)) ?? .now,
        endDate: Calendar.current.date(byAdding: .day, value: 26,
                                       to: Calendar.current.startOfDay(for: .now)) ?? .now,
        route: ["BRU", "IST", "NRT"])
}

enum WidgetCountdownStore {
    private static let key = "widgetCountdown"

    /// `nil` clears it: no plan to count down to.
    static func save(_ countdown: WidgetCountdown?) {
        guard let defaults = UserDefaults(suiteName: WidgetSharedStore.appGroup) else { return }
        if let countdown, let data = try? JSONEncoder().encode(countdown) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static func load() -> WidgetCountdown? {
        guard let data = UserDefaults(suiteName: WidgetSharedStore.appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetCountdown.self, from: data)
    }
}
