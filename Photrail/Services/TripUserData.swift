import Foundation

/// Everything kept per detected trip, keyed by the trip's id, and how to move it when that id
/// changes. See `TripIdentity` for when that happens.
///
/// Rules for anything stored per trip id:
/// 1. **Register it in `entries`.** Data that isn't listed stays behind under the old id the
///    first time its trip's id moves (an older photo imported, a photo excluded, a reindex).
/// 2. **Never prune data whose trip is gone.** A later scan can bring the trip back, and
///    `TripIdentity` then moves the data to wherever it went. Only the user removes data.
/// 3. Pure caches that are rebuilt anyway (`TripInsightsStore`, `TripSuperlativeStore`) don't
///    belong here.
enum TripUserData {

    /// How a defaults value holds trip ids.
    enum Shape: Equatable {
        /// `[tripID: value]`, stored as a property-list dictionary.
        case dictionary
        /// `[tripID: value]`, stored as JSON data.
        case jsonDictionary
        /// `[tripID]`: trips something applies to (dismissed, notified).
        case idList
        /// One trip id.
        case singleID
    }

    struct Entry: Equatable {
        let key: String
        let shape: Shape
    }

    /// The trips "Your trip is ready" was sent for, so moving a trip doesn't announce it again.
    static let notifiedTripsKey = "notifiedTripIDs"

    static let entries: [Entry] = [
        Entry(key: TripNameStore.key, shape: .dictionary),
        Entry(key: TripNoteStore.key, shape: .dictionary),
        Entry(key: TripCoverStore.key, shape: .dictionary),
        Entry(key: TripFlightStore.key, shape: .jsonDictionary),
        Entry(key: TripFlightHintStore.key, shape: .idList),
        Entry(key: notifiedTripsKey, shape: .idList),
        Entry(key: FreeFilmAllowance.key, shape: .singleID),
    ]

    /// Moves every registered piece of data from `old` to `new`. Per entry only when `new` has
    /// nothing there yet, so a trip's own data is never overwritten; what can't move stays
    /// under `old`.
    static func move(from old: String, to new: String, in defaults: UserDefaults = .standard) {
        guard old != new else { return }
        for entry in entries { move(entry, from: old, to: new, in: defaults) }
    }

    /// Whether any registered entry holds something for `tripID`.
    static func hasData(for tripID: String, in defaults: UserDefaults = .standard) -> Bool {
        entries.contains { holds($0, tripID, in: defaults) }
    }

    private static func move(_ entry: Entry, from old: String, to new: String, in defaults: UserDefaults) {
        guard holds(entry, old, in: defaults), !holds(entry, new, in: defaults) else { return }
        switch entry.shape {
        case .dictionary:
            guard var dict = defaults.dictionary(forKey: entry.key) else { return }
            dict[new] = dict.removeValue(forKey: old)
            defaults.set(dict, forKey: entry.key)
        case .jsonDictionary:
            guard var dict = jsonDictionary(entry.key, in: defaults) else { return }
            dict[new] = dict.removeValue(forKey: old)
            // Only the outer keys change; each value is written back exactly as it was read.
            if let data = try? JSONSerialization.data(withJSONObject: dict) {
                defaults.set(data, forKey: entry.key)
            }
        case .idList:
            let ids = defaults.stringArray(forKey: entry.key) ?? []
            defaults.set(ids.map { $0 == old ? new : $0 }, forKey: entry.key)
        case .singleID:
            defaults.set(new, forKey: entry.key)
        }
    }

    private static func holds(_ entry: Entry, _ tripID: String, in defaults: UserDefaults) -> Bool {
        switch entry.shape {
        case .dictionary: return defaults.dictionary(forKey: entry.key)?[tripID] != nil
        case .jsonDictionary: return jsonDictionary(entry.key, in: defaults)?[tripID] != nil
        case .idList: return (defaults.stringArray(forKey: entry.key) ?? []).contains(tripID)
        case .singleID: return defaults.string(forKey: entry.key) == tripID
        }
    }

    private static func jsonDictionary(_ key: String, in defaults: UserDefaults) -> [String: Any]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
