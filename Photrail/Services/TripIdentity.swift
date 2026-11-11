import Foundation

/// Keeps the user's data on a trip when the trip's id moves.
///
/// A detected trip's id is its first day (`trip-2025-07-01`, see `TripDetector`), so it moves
/// whenever that day does: an older photo imported, a photo's location set or excluded, an
/// updated dataset, a reindex. The names, notes, flights and so on in `TripUserData` would stay
/// behind under the old id.
///
/// So after every finished scan this remembers each trip's span, and the next time compares:
/// a trip id that's gone hands its data to the new trip that shares the most days with it.
/// Manual trips (`manual:…`) have ids of their own and are left alone.
enum TripIdentity {

    struct Span: Codable, Equatable, Sendable {
        let id: String
        let start: Date
        let end: Date
    }

    static let key = "lastTripSpans"

    /// Old id → new id, for every remembered trip whose id is gone and that shares at least one
    /// day with a trip now. Most shared days wins, then the closest start. Several old trips can
    /// map to one new trip (they merged); `TripUserData.move` keeps the first one's data and
    /// leaves the rest where it was.
    static func matches(old: [Span], new: [Span], calendar: Calendar = .current) -> [String: String] {
        let newIDs = Set(new.map(\.id))
        let detected = new.filter { isDetected($0.id) }
        var result: [String: String] = [:]
        for gone in old where isDetected(gone.id) && !newIDs.contains(gone.id) {
            let best = detected
                .map { (span: $0, days: sharedDays(gone, $0, calendar: calendar)) }
                .filter { $0.days > 0 }
                .max { a, b in
                    if a.days != b.days { return a.days < b.days }
                    // Fewer days apart at the start is better, so it should sort last.
                    return abs(a.span.start.timeIntervalSince(gone.start))
                        > abs(b.span.start.timeIntervalSince(gone.start))
                }
            if let best { result[gone.id] = best.span.id }
        }
        return result
    }

    /// Moves data from trips whose id changed since the last finished scan, then remembers
    /// `trips` for next time. Call only with the trips of a finished scan: half-scanned trips
    /// are cut short and would pull data the wrong way.
    ///
    /// - Returns: whether any id moved, so the caller can re-read names into its trips.
    @discardableResult
    static func relink(_ trips: [Trip], in defaults: UserDefaults = .standard,
                       calendar: Calendar = .current) -> Bool {
        let new = trips.filter { isDetected($0.id) }
            .map { Span(id: $0.id, start: $0.startDate, end: $0.endDate) }
        // No trips at all is a wiped cache (a reindex just started), not a real answer:
        // remembering it would forget every trip the next scan has to match against.
        guard !new.isEmpty else { return false }

        let moves = matches(old: load(from: defaults), new: new, calendar: calendar)
        // Oldest first, so when trips merged the earliest one's data is the one that moves.
        for (old, new) in moves.sorted(by: { $0.key < $1.key }) {
            TripUserData.move(from: old, to: new, in: defaults)
        }
        save(new, to: defaults)
        return !moves.isEmpty
    }

    static func load(from defaults: UserDefaults = .standard) -> [Span] {
        guard let data = defaults.data(forKey: key),
              let spans = try? JSONDecoder().decode([Span].self, from: data) else { return [] }
        return spans
    }

    static func save(_ spans: [Span], to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(spans) { defaults.set(data, forKey: key) }
    }

    private static func isDetected(_ id: String) -> Bool { id.hasPrefix("trip-") }

    /// Calendar days both spans touch, counting first and last day.
    private static func sharedDays(_ a: Span, _ b: Span, calendar: Calendar) -> Int {
        let start = max(calendar.startOfDay(for: a.start), calendar.startOfDay(for: b.start))
        let end = min(calendar.startOfDay(for: a.end), calendar.startOfDay(for: b.end))
        guard start <= end else { return 0 }
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }
}
