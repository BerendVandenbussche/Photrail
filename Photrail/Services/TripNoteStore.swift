import Foundation

/// Stores a user's free-text note per trip, keyed by the stable trip id.
/// (Trips are recomputed from photos each scan, so notes live here, not on the model.)
enum TripNoteStore {
    private static let key = "tripNotes"

    static func note(for tripID: String) -> String {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String])?[tripID] ?? ""
    }

    static func setNote(_ text: String, for tripID: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        dict[tripID] = trimmed.isEmpty ? nil : trimmed
        UserDefaults.standard.set(dict, forKey: key)
    }
}
