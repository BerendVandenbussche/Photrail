import Foundation

/// The one trip film a free user may share. Lifetime makes films unlimited.
///
/// The free film belongs to one trip, so sharing it again (after a cancelled share sheet, or
/// to another app) stays free. It's claimed only once a film has actually rendered, so a
/// failed or cancelled export doesn't use it up. Kept on the device: a reinstall resets it.
enum FreeFilmAllowance {
    static let key = "freeFilmTripID"

    /// The trip that used the free film, if any.
    static func claimedTripID(in defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key)
    }

    /// True while the free film hasn't been used on any trip.
    static func hasFreeFilmLeft(in defaults: UserDefaults = .standard) -> Bool {
        claimedTripID(in: defaults) == nil
    }

    /// Whether a film of this trip may be exported.
    static func canExport(tripID: String, hasLifetime: Bool,
                          in defaults: UserDefaults = .standard) -> Bool {
        if hasLifetime { return true }
        guard let claimed = claimedTripID(in: defaults) else { return true }
        return claimed == tripID
    }

    /// Use the free film on this trip. Does nothing once it's been used.
    static func claim(tripID: String, in defaults: UserDefaults = .standard) {
        guard hasFreeFilmLeft(in: defaults) else { return }
        defaults.set(tripID, forKey: key)
    }

    /// What a free user sees for a trip's film.
    enum Status: Equatable {
        /// Lifetime: no badge, no caption.
        case unlimited
        /// The free film hasn't been used yet.
        case freeLeft
        /// This is the trip that used the free film.
        case thisTripIsFree
        /// The free film went to another trip: Lifetime needed.
        case locked
    }

    static func status(tripID: String, hasLifetime: Bool,
                       in defaults: UserDefaults = .standard) -> Status {
        if hasLifetime { return .unlimited }
        guard let claimed = claimedTripID(in: defaults) else { return .freeLeft }
        return claimed == tripID ? .thisTripIsFree : .locked
    }
}
