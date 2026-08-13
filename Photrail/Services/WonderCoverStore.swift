import Photos

/// The chosen photo for each wonder, remembered across launches.
///
/// Mirrors `TripCoverStore`. Separate from `WonderStat.representativePhotoID`, which is the
/// newest photo taken inside the wonder's radius — a location fact and nothing more. At Christ
/// the Redeemer that's as likely to be the monkeys on the roof as the statue.
enum WonderCoverStore {
    private static let key = "wonderCoverPhotoIDs"

    static func coverID(for wonderID: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String])?[wonderID]
    }

    static func setCoverID(_ id: String, for wonderID: String) {
        var map = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        map[wonderID] = id
        UserDefaults.standard.set(map, forKey: key)
    }
}

/// Picks the photo that actually shows a wonder, once, and remembers it.
///
/// Every surface that shows a single photo for a wonder goes through here — the trip's wonder
/// row, the wonder detail grid, the recap, the trip film — so they can't disagree about which
/// photo represents the place. The Vision pass runs at most once per wonder per device.
enum WonderCover {

    /// Twelve candidates is what the recap has always used: enough to find a good frame, few
    /// enough that the classification stays under a second.
    private static let maxCandidates = 12

    /// The best photo of `wonderID` among `candidates`, cached after the first call.
    ///
    /// Returns the newest candidate rather than nothing when no photo convincingly depicts the
    /// wonder — a mediocre photo of the right place beats an empty tile.
    static func resolve(wonderID: String, candidates: [String]) async -> String? {
        guard !candidates.isEmpty else { return nil }

        // A remembered cover can outlive the photo it points at.
        if let cached = WonderCoverStore.coverID(for: wonderID),
           PHAsset.fetchAssets(withLocalIdentifiers: [cached], options: nil).firstObject != nil {
            return cached
        }

        // A lower bar than the recap's old 0.25, with a fallback behind it. Vision's taxonomy is
        // coarse: a photo of Christ the Redeemer against the sky may score on nothing we ask
        // for, and demanding a confident match just hands the slot back to the newest photo —
        // which is the monkeys. With `allowFallback` the wildlife and the lunch still lose,
        // because they score heavily *against* the subject.
        let best = await PhotoCurator().bestPhoto(
            candidateIDs: Array(candidates.prefix(maxCandidates)),
            subject: .forWonder(id: wonderID),
            minMatch: 0.15,
            allowFallback: true
        )
        guard let best else { return candidates.first }
        WonderCoverStore.setCoverID(best, for: wonderID)
        return best
    }
}
