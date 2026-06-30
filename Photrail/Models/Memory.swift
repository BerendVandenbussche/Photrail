import Foundation

/// A "On this day" memory: photos taken on today's calendar day in a past year,
/// away from home. One memory = one (year, country) cluster from that day.
struct Memory: Identifiable, Sendable {
    let id: String          // "year-countryCode"
    let year: Int
    let yearsAgo: Int
    let date: Date          // the day that year
    let country: String
    let countryCode: String
    let flag: String
    let city: String?
    let photoIDs: [String]

    var coverPhotoID: String? { photoIDs.first }
    var photoCount: Int { photoIDs.count }

    /// "1 year ago" / "5 years ago"
    var yearsAgoText: String { yearsAgo == 1 ? "1 year ago" : "\(yearsAgo) years ago" }

    /// "Lisbon, Portugal" or just the country.
    var placeText: String {
        if let city { return "\(city), \(country)" }
        return country
    }
}
