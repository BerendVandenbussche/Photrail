import Foundation

struct CountryStat: Identifiable, Sendable {
    let id: String      // ISO country code
    var name: String
    var flag: String
    var photoCount: Int
    var cities: [CityStat]
    var firstVisit: Date
    var lastVisit: Date
    var photoIDs: [String]  // GeoPhoto.id references for photo grid

    var cityCount: Int { cities.count }
}

struct CityStat: Identifiable, Sendable {
    let id: String      // "\(city),\(countryCode)"
    var name: String
    var country: String
    var countryCode: String
    var photoCount: Int
    var firstVisit: Date
    var lastVisit: Date
    var representativeCoordinate: GeoPhoto.Coordinate
}

extension CountryStat {
    static let totalCountriesInWorld = 195

    static var mock: CountryStat {
        CountryStat(
            id: "IT",
            name: "Italy",
            flag: "🇮🇹",
            photoCount: 142,
            cities: [
                CityStat(id: "Rome,IT", name: "Rome", country: "Italy", countryCode: "IT",
                         photoCount: 80, firstVisit: .distantPast, lastVisit: .now,
                         representativeCoordinate: .init(latitude: 41.9, longitude: 12.5)),
                CityStat(id: "Florence,IT", name: "Florence", country: "Italy", countryCode: "IT",
                         photoCount: 62, firstVisit: .distantPast, lastVisit: .now,
                         representativeCoordinate: .init(latitude: 43.77, longitude: 11.25))
            ],
            firstVisit: Calendar.current.date(byAdding: .year, value: -3, to: .now) ?? .now,
            lastVisit: Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now,
            photoIDs: []
        )
    }
}
