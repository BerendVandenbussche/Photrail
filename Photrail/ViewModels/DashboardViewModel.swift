import Foundation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    let stats: TravelStats

    init(stats: TravelStats) {
        self.stats = stats
    }

    var worldPercentageText: String {
        String(format: "%.1f%%", stats.worldPercentage)
    }

    var sortedCountries: [CountryStat] {
        stats.countries.sorted { $0.photoCount > $1.photoCount }
    }

    var topCountries: [CountryStat] {
        Array(sortedCountries.prefix(5))
    }

    var recentMemories: [CountryStat] {
        stats.countries.sorted { $0.lastVisit > $1.lastVisit }.prefix(3).map { $0 }
    }
}
