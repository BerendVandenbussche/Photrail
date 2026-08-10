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
    let photoCount: Int
    let keywords: [String]
    let thumbnailData: Data?

    init(entry: TripSearchEntry) {
        id = entry.id
        title = entry.title
        englishTitle = entry.englishTitle
        dateRangeText = entry.dateRangeText
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
        let needle = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return TripSearchStore.load()
            .filter { entry in
                ([entry.title, entry.englishTitle] + entry.keywords).contains {
                    $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        .contains(needle)
                }
            }
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
