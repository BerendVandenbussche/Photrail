import Foundation

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
    let photoIDs: [String]
    let coordinate: GeoPhoto.Coordinate   // trip centroid, for distance calculations

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
