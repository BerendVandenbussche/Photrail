import Foundation

/// A trip, flattened to just what Spotlight and the App Intents query need.
///
/// `TripEntityQuery` can be asked to resolve a trip when the app isn't running, so it can't
/// read `AppViewModel.stats.trips` (main-actor, in-process, empty until a scan finishes).
/// This snapshot is the shared source of truth instead — the same trick `WidgetSharedStore`
/// uses for the widgets.
struct TripSearchEntry: Codable, Sendable, Identifiable {
    let id: String
    /// Title in the app's language at index time (a custom name, or the countries).
    let title: String
    /// Always-English title, so search matches "Belgium" as well as "België".
    let englishTitle: String
    /// Human date range, e.g. "Apr 3 – Apr 12, 2025".
    let dateRangeText: String
    let startDate: Date
    let endDate: Date
    let photoCount: Int
    /// Country names in both languages, plus every city — these become Spotlight keywords,
    /// which is how typing "Split" finds the Croatia trip without indexing cities separately.
    let keywords: [String]
    /// JPEG data for the result thumbnail. Nil is fine — the result falls back to the app icon.
    let thumbnailData: Data?
}

/// Reads/writes the trip snapshot in the App Group container.
///
/// Unlike `WidgetSharedStore` this writes a *file* rather than a `UserDefaults` value: the
/// thumbnails make the payload a megabyte or so, which is far past what defaults is for.
enum TripSearchStore {
    private static let fileName = "trip-search-index.json"

    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSharedStore.appGroup)?
            .appendingPathComponent(fileName)
    }

    static func save(_ entries: [TripSearchEntry]) {
        guard let url, let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> [TripSearchEntry] {
        guard let url,
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([TripSearchEntry].self, from: data)
        else { return [] }
        return entries
    }

    /// Exact id first, then the trip whose date range contains the id's date.
    ///
    /// Trip ids are `trip-YYYY-MM-DD` built from the start date (`TripDetector`), and trips are
    /// re-derived on every scan — importing an older photo moves the boundary and silently
    /// reassigns the id. Without this fallback an older Spotlight result would open nothing.
    static func entry(matching id: String) -> TripSearchEntry? {
        let entries = load()
        if let exact = entries.first(where: { $0.id == id }) { return exact }
        guard let date = startDate(fromID: id) else { return nil }
        return entries.first { date >= $0.startDate && date <= $0.endDate }
    }

    /// Parses the `trip-YYYY-MM-DD` id back into its start date (nil for manual trips).
    /// Shared with `MainTabView`, which does the same fallback against live `stats.trips`.
    static func startDate(fromID id: String) -> Date? {
        let parts = id.split(separator: "-")
        guard parts.count == 4, parts[0] == "trip",
              let year = Int(parts[1]), let month = Int(parts[2]), let day = Int(parts[3])
        else { return nil }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }
}
