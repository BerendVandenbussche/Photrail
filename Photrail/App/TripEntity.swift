import AppIntents
import CoreSpotlight
import UniformTypeIdentifiers

/// A trip, exposed to the system as an addressable thing.
///
/// One type covers three surfaces: `IndexedEntity` puts it in Spotlight (via
/// `TripSearchIndexer`), `AppEntity` makes `OpenTripIntent` take a trip *parameter* so Siri can
/// hear "open my Croatia trip", and both together give a Shortcuts action for free.
///
/// Backed by `TripSearchStore`, never by `AppViewModel` — the query runs when the app doesn't.
struct TripEntity: AppEntity, IndexedEntity {
    let id: String
    let title: String
    let englishTitle: String
    let dateRangeText: String
    let startDate: Date
    let endDate: Date
    let photoCount: Int
    let keywords: [String]
    let thumbnailData: Data?

    init(entry: TripSearchEntry) {
        id = entry.id
        title = entry.title
        englishTitle = entry.englishTitle
        dateRangeText = entry.dateRangeText
        startDate = entry.startDate
        endDate = entry.endDate
        photoCount = entry.photoCount
        keywords = entry.keywords
        thumbnailData = entry.thumbnailData
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Trip"
    static let defaultQuery = TripEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(dateRangeText)",
            image: thumbnailData.map { .init(data: $0) }
        )
    }

    /// What Spotlight actually stores. The keywords are the whole reason cities and countries
    /// don't need index entries of their own.
    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .content)
        set.title = title
        set.displayName = title
        set.contentDescription = dateRangeText
        set.keywords = keywords
        // Real dates as well, so Spotlight can match "trips from 2025" on the date itself.
        set.startDate = startDate
        set.endDate = endDate
        set.contentCreationDate = startDate
        set.thumbnailData = thumbnailData
        return set
    }
}

/// Resolves trips for Spotlight taps, Siri and Shortcuts.
struct TripEntityQuery: EntityQuery, EntityStringQuery {

    func entities(for identifiers: [TripEntity.ID]) async throws -> [TripEntity] {
        identifiers.compactMap { TripSearchStore.entry(matching: $0).map(TripEntity.init(entry:)) }
    }

    /// Free-text matching for Siri and the Shortcuts picker. Matches the title in either
    /// language plus every keyword, so a city name resolves the trip it belongs to.
    func entities(matching string: String) async throws -> [TripEntity] {
        func fold(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
        // Every meaningful word must match somewhere: "trips 2015" finds the 2015 trips,
        // "Croatia 2023" only the Croatia trip of that year.
        let words = fold(string).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let needles = words.filter { !TripSearchIndexer.genericWords.contains($0) }
        guard !needles.isEmpty else { return try await suggestedEntities() }
        return TripSearchStore.load()
            .filter { entry in
                let haystack = ([entry.title, entry.englishTitle] + entry.keywords).map(fold)
                return needles.allSatisfy { needle in haystack.contains { $0.contains(needle) } }
            }
            .sorted { $0.startDate > $1.startDate }
            .map(TripEntity.init(entry:))
    }

    /// The picker's default list — most recent trips first.
    func suggestedEntities() async throws -> [TripEntity] {
        TripSearchStore.load()
            .sorted { $0.startDate > $1.startDate }
            .prefix(20)
            .map(TripEntity.init(entry:))
    }
}
