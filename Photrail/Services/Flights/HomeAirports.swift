import Foundation
import CoreLocation

/// Which airports you fly from, learned from your own history: the airports near home you
/// were photographed at, and the flights you entered. Size alone can't tell (OurAirports lists
/// Ostend as "large", like Brussels), and the nearest airport is often not the one people fly from.
enum HomeAirports {
    /// How far from home an airport still counts as one of yours (also any in the home country).
    static let maxKm: Double = 150

    /// IATA codes of your home airports, most used first. Empty when there's no history.
    ///
    /// - Photos: one point per calendar day you were photographed at the airport, so a long
    ///   wait with 40 photos counts once.
    /// - Flights: two points per flight you entered that leaves from or lands at it; you
    ///   chose that airport yourself.
    static func rank(photos: [GeoPhoto],
                     flights: [PlannedTrip.Flight],
                     home: CLLocationCoordinate2D,
                     homeCountryCode: String?,
                     calendar: Calendar = .current) -> [String] {
        let homeLocation = CLLocation(latitude: home.latitude, longitude: home.longitude)
        func isHomeAirport(_ airport: AirportDirectory.Airport) -> Bool {
            if let homeCountryCode, airport.countryCode == homeCountryCode { return true }
            let meters = CLLocation(latitude: airport.latitude, longitude: airport.longitude)
                .distance(from: homeLocation)
            return meters <= maxKm * 1000
        }

        var score: [String: Int] = [:]
        var seenDays = Set<String>()
        // Outside the home country, only photos within a few degrees of home can be at a home
        // airport: a cheap pre-filter before the airport lookup.
        for photo in photos {
            let coordinate = CLLocationCoordinate2D(latitude: photo.coordinate.latitude,
                                                    longitude: photo.coordinate.longitude)
            if homeCountryCode == nil || photo.countryCode != homeCountryCode {
                guard abs(coordinate.latitude - home.latitude) < 2.5,
                      abs(coordinate.longitude - home.longitude) < 4 else { continue }
            }
            guard let airport = AirportDirectory.airport(at: coordinate), isHomeAirport(airport) else { continue }
            let day = calendar.dateComponents([.year, .month, .day], from: photo.date)
            let key = "\(airport.iata)-\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
            if seenDays.insert(key).inserted { score[airport.iata, default: 0] += 1 }
        }
        for flight in flights {
            for code in [flight.from, flight.to] {
                guard let airport = AirportDirectory.airport(code), isHomeAirport(airport) else { continue }
                score[airport.iata, default: 0] += 2
            }
        }
        return score
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { $0.key }
    }

    /// Airports to choose from when there's no history: the large ones within `maxKm`, those in
    /// the home country first, nearest first ("OST, BRU, CRL, LIL" from Bruges: the nearest
    /// three alone would leave out Brussels). Medium ones only when there are too few large.
    static func candidates(home: CLLocationCoordinate2D, homeCountryCode: String?, limit: Int = 4)
        -> [AirportDirectory.Airport] {
        let near = AirportDirectory.airports(near: home, maxKm: maxKm)
        let large = near.filter { $0.size == .large }
        let pool = large.count >= 2 ? large : near
        let homeFirst = pool.filter { $0.countryCode == homeCountryCode }
            + pool.filter { $0.countryCode != homeCountryCode }
        return Array(homeFirst.prefix(limit))
    }
}
