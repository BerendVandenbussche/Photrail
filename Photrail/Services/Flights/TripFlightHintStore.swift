import Foundation

/// The trips whose flight hint the user dismissed, so it doesn't come back.
enum TripFlightHintStore {
    private static let key = "dismissedFlightHints"

    static func isDismissed(_ tripID: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(tripID)
    }

    static func dismiss(_ tripID: String) {
        var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !ids.contains(tripID) else { return }
        ids.append(tripID)
        UserDefaults.standard.set(ids, forKey: key)
    }
}
