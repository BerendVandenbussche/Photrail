import Foundation

/// Remembers which photo was chosen as a trip's hero cover, so the (expensive)
/// Vision curation only runs the first time a trip is opened. Keyed by trip id,
/// which is stable across rescans as long as the trip's primary country + start
/// date don't change.
enum TripCoverStore {
    private static let key = "tripCoverPhotoIDs"

    static func coverID(for tripID: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String])?[tripID]
    }

    static func setCoverID(_ id: String, for tripID: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        dict[tripID] = id
        UserDefaults.standard.set(dict, forKey: key)
    }
}
