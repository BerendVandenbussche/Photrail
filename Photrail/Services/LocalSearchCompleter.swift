import Foundation
import MapKit

/// City/place search backed by Apple Maps, for pickers where the user may name anywhere on
/// earth — their home town, or a stop in a trip they're adding by hand.
///
/// Two sources feed one list, because neither is sufficient alone:
///
/// * **`MKLocalSearchCompleter`** is the fast per-keystroke autocomplete, but it ranks almost
///   entirely by proximity to the device. Someone in Qingdao typing "London" gets streets in
///   Qingdao; typing "Freiburg" gets nothing at all. That is fine for "add a place near here"
///   and useless for "set my home", and this class serves both.
/// * **`MKLocalSearch`** with an explicit world region answers the far-away case: it takes the
///   raw text and returns real map items wherever they are. It costs a network round trip, so
///   it runs debounced rather than on every keystroke.
///
/// Results are merged, de-duplicated, and nudged so that a row whose *title* is what the user
/// actually typed floats above one that merely contains it — "London" before "London Road".
/// No result-type filter is applied: an earlier `resultTypes = [.address]` was meant to keep
/// businesses out of a city picker, but it also stripped whole cities out of the list, which
/// is the worse failure of the two.
@MainActor
@Observable
final class LocalSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {

    /// One row in the list. Either an autocomplete suggestion (still needs resolving into a
    /// coordinate) or a map item the world-wide search already resolved for us.
    struct Suggestion: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        fileprivate let completion: MKLocalSearchCompletion?
        fileprivate let item: MKMapItem?

        static func == (lhs: Suggestion, rhs: Suggestion) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    var query: String = "" {
        didSet {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            worldSearch?.cancel()
            guard !trimmed.isEmpty else {
                completions = []
                found = []
                completerPending = false
                searchPending = false
                return
            }
            completerPending = true
            completer.queryFragment = trimmed
            worldSearch = Task { [weak self] in
                // Long enough that a fast typist sends one search rather than eight; short
                // enough that a pause of a keystroke or two already has the answer coming.
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await self?.searchWorldwide(for: trimmed)
            }
        }
    }

    /// Merged, de-duplicated, lightly re-ranked rows for the list.
    var results: [Suggestion] { merged() }

    /// True between a keystroke and Apple Maps answering it. On a slow connection that gap is
    /// seconds long with nothing on screen, which reads as the field being broken.
    var isSearching: Bool { completerPending || searchPending }

    private var completions: [Suggestion] = []
    private var found: [Suggestion] = []
    private var completerPending = false
    private var searchPending = false
    private var worldSearch: Task<Void, Never>?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        // Explicitly the whole planet. The completer still weights nearby matches heavily —
        // that's the server's ranking, not this region — but nothing here narrows it further.
        completer.region = MKCoordinateRegion(MKMapRect.world)
    }

    /// Bias autocomplete toward a region (e.g. the country being edited) so nearby places
    /// rank first. Pass a wide span to cover a whole country.
    func setRegion(latitude: Double, longitude: Double, spanDegrees: Double = 12) {
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees)
        )
    }

    // MARK: - Sources

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let updated = completer.results
        Task { @MainActor in
            self.completions = updated.map {
                Suggestion(id: "c:\($0.title)|\($0.subtitle)",
                           title: $0.title,
                           subtitle: $0.subtitle,
                           completion: $0,
                           item: nil)
            }
            self.completerPending = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.completions = []
            self.completerPending = false
        }
    }

    /// The un-biased half of the search: whatever the user typed, looked up across the world.
    private func searchWorldwide(for text: String) async {
        searchPending = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        // Cities and towns are `.address` results; without it this returns businesses only.
        request.resultTypes = [.address, .pointOfInterest]
        request.region = MKCoordinateRegion(MKMapRect.world)

        let response = try? await MKLocalSearch(request: request).start()
        // A stale answer for an earlier query would replace the list the user is looking at.
        guard !Task.isCancelled,
              query.trimmingCharacters(in: .whitespaces) == text else {
            searchPending = false
            return
        }
        found = (response?.mapItems ?? []).prefix(12).map { item in
            let placemark = item.placemark
            let name = item.name ?? text
            let context = [placemark.locality, placemark.administrativeArea, placemark.country]
                .compactMap { $0 }
                .filter { $0 != name }
            return Suggestion(
                id: "s:\(name)|\(placemark.coordinate.latitude),\(placemark.coordinate.longitude)",
                title: name,
                subtitle: context.joined(separator: ", "),
                completion: nil,
                item: item
            )
        }
        searchPending = false
    }

    // MARK: - Merging

    private func merged() -> [Suggestion] {
        var seen = Set<String>()
        var rows: [Suggestion] = []
        for suggestion in completions + found {
            // The same city reached both ways is one row, not two.
            let key = "\(suggestion.title)|\(suggestion.subtitle)".lowercased()
            if seen.insert(key).inserted { rows.append(suggestion) }
        }

        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return rows }

        // A stable sort by how directly the title answers the query: exact, then prefix, then
        // everything else in the order the two sources produced it.
        func rank(_ suggestion: Suggestion) -> Int {
            let title = suggestion.title.lowercased()
            if title == needle { return 0 }
            if title.hasPrefix(needle) { return 1 }
            return 2
        }
        return rows.enumerated()
            .sorted { rank($0.element) == rank($1.element)
                      ? $0.offset < $1.offset
                      : rank($0.element) < rank($1.element) }
            .map(\.element)
    }

    // MARK: - Resolving

    /// A resolved place the user can set as home.
    struct Place: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
        let countryCode: String?
    }

    /// Resolve a row into a concrete place (coordinate + country code). Rows that came from
    /// the world-wide search already carry their map item and cost nothing to resolve.
    func resolve(_ suggestion: Suggestion) async -> Place? {
        let resolved: MKMapItem?
        if let item = suggestion.item {
            resolved = item
        } else if let completion = suggestion.completion {
            let request = MKLocalSearch.Request(completion: completion)
            resolved = try? await MKLocalSearch(request: request).start().mapItems.first
        } else {
            resolved = nil
        }
        guard let item = resolved else { return nil }

        let placemark = item.placemark
        let name = item.name ?? suggestion.title
        let display = [name, placemark.country].compactMap { $0 }.joined(separator: ", ")
        return Place(name: display.isEmpty ? name : display,
                     latitude: placemark.coordinate.latitude,
                     longitude: placemark.coordinate.longitude,
                     countryCode: placemark.isoCountryCode)
    }
}
