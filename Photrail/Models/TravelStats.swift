import Foundation

struct TravelStats: Sendable {
    var totalGeotaggedPhotos: Int
    var countries: [CountryStat]
    var allCities: [CityStat]
    var timelineEntries: [TimelineEntry]

    var countryCount: Int { countries.count }
    var cityCount: Int { allCities.count }

    var worldPercentage: Double {
        Double(countryCount) / Double(CountryStat.totalCountriesInWorld) * 100
    }

    var mostPhotographedCountry: CountryStat? {
        countries.max(by: { $0.photoCount < $1.photoCount })
    }

    var recentCountries: [CountryStat] {
        countries.sorted { $0.lastVisit > $1.lastVisit }.prefix(5).map { $0 }
    }

    static var empty: TravelStats {
        TravelStats(totalGeotaggedPhotos: 0, countries: [], allCities: [], timelineEntries: [])
    }

    static var mock: TravelStats {
        let calendar = Calendar.current
        let now = Date.now
        return TravelStats(
            totalGeotaggedPhotos: 1_247,
            countries: [
                .mock,
                CountryStat(id: "FR", name: "France", flag: "🇫🇷", photoCount: 98,
                            cities: [], firstVisit: calendar.date(byAdding: .year, value: -4, to: now)!,
                            lastVisit: calendar.date(byAdding: .month, value: -6, to: now)!, photoIDs: []),
                CountryStat(id: "JP", name: "Japan", flag: "🇯🇵", photoCount: 214,
                            cities: [], firstVisit: calendar.date(byAdding: .year, value: -1, to: now)!,
                            lastVisit: calendar.date(byAdding: .day, value: -45, to: now)!, photoIDs: []),
                CountryStat(id: "US", name: "United States", flag: "🇺🇸", photoCount: 76,
                            cities: [], firstVisit: calendar.date(byAdding: .year, value: -5, to: now)!,
                            lastVisit: calendar.date(byAdding: .year, value: -1, to: now)!, photoIDs: []),
                CountryStat(id: "ES", name: "Spain", flag: "🇪🇸", photoCount: 55,
                            cities: [], firstVisit: calendar.date(byAdding: .year, value: -2, to: now)!,
                            lastVisit: calendar.date(byAdding: .month, value: -3, to: now)!, photoIDs: [])
            ],
            allCities: [],
            timelineEntries: (0..<12).map { i in
                TimelineEntry(
                    id: UUID(), month: calendar.date(byAdding: .month, value: -i, to: now)!,
                    photoCount: Int.random(in: 20...120), countries: ["Italy", "France", "Japan"][safe: i % 3].map { [$0] } ?? []
                )
            }
        )
    }
}

struct TimelineEntry: Identifiable, Sendable {
    let id: UUID
    var month: Date
    var photoCount: Int
    var countries: [String]

    var monthLabel: String {
        month.formatted(.dateTime.month(.abbreviated).year())
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
