import Foundation

/// Individual photos the user has excluded from evaluation — dropped from every stat,
/// trip, city, country and memory, as if they weren't in the library. Fully reversible.
///
/// Use case: someone downloads photos from a place they never actually visited
/// (e.g. a family member sharing a trip album) and doesn't want them counted.
/// Because exclusion is per-photo — not per-country — that place resurfaces on its own
/// the moment the user takes their own photos there.
enum ExcludedPhotosStore {
    private static let key = "excludedPhotoIDs"

    /// All excluded photo IDs (`PHAsset.localIdentifier`).
    static func load() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func save(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}
