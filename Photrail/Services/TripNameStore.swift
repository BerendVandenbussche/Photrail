import Foundation

/// Stores a user's custom name per trip, keyed by the stable trip id.
/// (Trips are recomputed from photos each scan, so the name lives here, not on the
/// model — it's read back in when trips are rebuilt.) A custom name is the same in
/// every language, so it's used on both the localized UI and the English share cards.
enum TripNameStore {
    private static let key = "tripNames"

    static func name(for tripID: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String])?[tripID]
    }

    static func setName(_ text: String, for tripID: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        dict[tripID] = trimmed.isEmpty ? nil : trimmed
        UserDefaults.standard.set(dict, forKey: key)
    }
}
