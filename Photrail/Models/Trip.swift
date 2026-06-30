import Foundation
import CoreLocation

/// A single trip: a streak of photos taken in one country within a time window.
struct Trip: Identifiable, Sendable {
    let id: String
    let countryCode: String
    let country: String
    let flag: String
    let startDate: Date
    let endDate: Date
    let photoCount: Int
    let cities: [String]          // visited cities, most-photographed first
    let stops: [TripStop]         // visited cities with coordinates, in chronological order
    let photoIDs: [String]
    let coordinate: GeoPhoto.Coordinate   // trip centroid, for distance calculations
    /// Highest GPS altitude reached on the trip, in meters (nil if no vertical fix).
    let highestAltitude: Double?
    /// World wonders / landmarks photographed on the trip.
    let wonders: [WonderHit]

    /// A city visited during the trip, with a representative location and arrival date.
    struct TripStop: Identifiable, Sendable {
        let id: String            // city name
        var name: String { id }
        let latitude: Double
        let longitude: Double
        let firstVisit: Date
        let photoCount: Int
    }

    /// A wonder/landmark seen on the trip (lightweight projection of WonderStat).
    struct WonderHit: Identifiable, Sendable {
        let id: String            // wonder id
        let name: String
        let emoji: String
        let isOfficial: Bool      // true = one of the New 7 Wonders; false = landmark
        let photoID: String?      // a representative photo, if any
    }

    /// Indicative distance traveled across the trip: sum of the legs between stops,
    /// in the order visited (kilometers). Not an exact route.
    var routeDistanceKm: Double {
        guard stops.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<stops.count {
            let a = CLLocation(latitude: stops[i - 1].latitude, longitude: stops[i - 1].longitude)
            let b = CLLocation(latitude: stops[i].latitude, longitude: stops[i].longitude)
            total += a.distance(from: b)
        }
        return total / 1000
    }

    var highestAltitudeText: String? {
        highestAltitude.map { "\(Int($0).formatted()) m" }
    }

    var dateRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return fmt.string(from: startDate)
        }
        let short = DateFormatter()
        short.dateFormat = "MMM d"
        // Same year → "Apr 3 – Apr 12, 2025"
        if Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .year) {
            return "\(short.string(from: startDate)) – \(fmt.string(from: endDate))"
        }
        return "\(fmt.string(from: startDate)) – \(fmt.string(from: endDate))"
    }

    var durationText: String {
        let days = (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
        return days == 1 ? "1 day" : "\(days) days"
    }
}
