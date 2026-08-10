import AppIntents
import CoreSpotlight
import Photos
import UIKit

/// Publishes the user's trips to Spotlight so they're findable from system search.
///
/// Runs off the main actor and is called from the same seam as `publishWidgetStats()` —
/// once stats are final, not on every `stats` assignment (a scan reassigns `stats` once per
/// geocoding chunk, which would mean dozens of reindexes per scan).
enum TripSearchIndexer {

    /// Thumbnail edge in points. Small on purpose: this runs for every trip after every scan.
    private static let thumbnailSize = CGSize(width: 180, height: 180)

    /// Rebuild the snapshot and the Spotlight index from scratch.
    ///
    /// Deliberately a full replace rather than a diff: trip ids are derived from the start date
    /// and can shift between scans (`TripDetector`), so diffing would strand orphaned entries
    /// pointing at trips that no longer exist. Trip counts are in the dozens — replacing is free.
    static func reindex(trips: [Trip]) async {
        var entries: [TripSearchEntry] = []
        for trip in trips {
            entries.append(TripSearchEntry(
                id: trip.id,
                title: trip.displayName,
                englishTitle: trip.englishDisplayName,
                dateRangeText: trip.dateRangeText,
                startDate: trip.startDate,
                endDate: trip.endDate,
                photoCount: trip.photoCount,
                keywords: keywords(for: trip),
                thumbnailData: await thumbnailData(for: trip)
            ))
        }
        TripSearchStore.save(entries)

        let index = CSSearchableIndex.default()
        // Trips are the only thing this app indexes, so a blanket delete is the simplest
        // way to guarantee no stale entries survive.
        try? await index.deleteAllSearchableItems()
        try? await index.indexAppEntities(entries.map(TripEntity.init(entry:)))

        // Siri caches the vocabulary behind the parameterized "open my <trip> trip" phrase.
        // Without this a newly-scanned trip is findable in Spotlight but not speakable.
        PhotrailShortcuts.updateAppShortcutParameters()
    }

    /// Everything a user might plausibly type, in both the app's language and English —
    /// country names, city names, and the custom trip name if there is one.
    private static func keywords(for trip: Trip) -> [String] {
        var words: [String] = []
        for country in trip.countries {
            words.append(country.localizedName)
            words.append(country.englishName)
        }
        words.append(contentsOf: trip.cities)
        if let custom = trip.customName, !custom.isEmpty { words.append(custom) }
        // Case-insensitively unique, order preserved.
        var seen = Set<String>()
        return words.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    /// The trip's cover photo, small.
    ///
    /// Uses the *remembered* cover only — never `PhotoCurator`, whose Vision pass over a whole
    /// trip is far too expensive to run for every trip at the end of every scan. A trip the user
    /// has never opened gets its first photo; once they open it, `TripCoverStore` is populated
    /// and the next reindex picks the curated cover up for free.
    private static func thumbnailData(for trip: Trip) async -> Data? {
        guard let id = TripCoverStore.coverID(for: trip.id) ?? trip.photoIDs.first,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else { return nil }

        let image: UIImage? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            // `.fastFormat` + no network, as in `PhotoCurator`: `.highQualityFormat` returns nil
            // for an asset whose full image lives only in iCloud, which under "Optimize iPhone
            // Storage" is most of a real library. A missing thumbnail is fine here (the result
            // falls back to the app icon); stalling the end of a scan is not.
            options.deliveryMode = .fastFormat
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false
            options.resizeMode = .fast
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: options
            ) { img, _ in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: img)
            }
        }
        return image?.jpegData(compressionQuality: 0.7)
    }
}
