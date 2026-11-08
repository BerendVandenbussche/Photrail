import Foundation

/// A trip the user has planned but not taken yet: one or more countries, each with its own
/// dates, an optional name and optional flights.
///
/// Deliberately separate from `ManualTrip`: a manual trip is a record of somewhere the user
/// *has been* and feeds every visited stat, while a plan must never count as visited. It
/// drives the countdown, the reminders and the calendar before the trip, labels the live
/// trip during it, and hands its name and flights to the photo trip afterwards (see
/// `AppViewModel.reconcilePlannedTrips()`).
struct PlannedTrip: Codable, Sendable, Identifiable, Hashable {
    let id: String
    var name: String?
    /// The countries in travel order. Never empty; kept sorted by start date.
    private(set) var stays: [Stay]
    /// The flights: one leg per take-off, so a transfer is two legs. Optional.
    var flights: [Flight] = []

    /// Time in one country. Neighbouring stays may share a day (the day you travel on).
    struct Stay: Codable, Sendable, Hashable, Identifiable {
        var id: String = UUID().uuidString
        var countryCode: String
        /// Start of the first day.
        var startDate: Date
        /// Start of the last day; never before `startDate`.
        var endDate: Date

        var flag: String { CountryCatalog.flag(for: countryCode) }
        var localizedCountry: String { CountryCatalog.name(for: countryCode) }

        func length(calendar: Calendar = .current) -> Int {
            (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
        }
    }

    /// One flight leg, by IATA airport code (see `AirportDirectory`).
    struct Flight: Codable, Sendable, Hashable, Identifiable {
        var id: String = UUID().uuidString
        var from: String
        var to: String
        /// The day of the flight, when the user gave one (start of day).
        var date: Date? = nil
    }

    init(id: String = UUID().uuidString, name: String?, stays: [Stay], flights: [Flight] = [],
         calendar: Calendar = .current) {
        self.id = id
        self.name = name
        self.flights = flights
        self.stays = []
        setStays(stays, calendar: calendar)
    }

    /// A single-country plan.
    init(id: String = UUID().uuidString, name: String?, countryCode: String,
         startDate: Date, endDate: Date, flights: [Flight] = [], calendar: Calendar = .current) {
        self.init(id: id, name: name,
                  stays: [Stay(countryCode: countryCode, startDate: startDate, endDate: endDate)],
                  flights: flights, calendar: calendar)
    }

    /// Replace the stays: dates snapped to whole days, ends never before starts, sorted.
    mutating func setStays(_ newStays: [Stay], calendar: Calendar = .current) {
        stays = newStays.map { stay in
            var s = stay
            s.startDate = calendar.startOfDay(for: stay.startDate)
            s.endDate = max(s.startDate, calendar.startOfDay(for: stay.endDate))
            return s
        }
        .sorted { ($0.startDate, $0.endDate) < ($1.startDate, $1.endDate) }
    }

    // MARK: - Saved data

    private enum CodingKeys: String, CodingKey {
        case id, name, stays, flights
        // Plans saved before multi-country support had one country and one date range.
        case countryCode, startDate, endDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        flights = try c.decodeIfPresent([Flight].self, forKey: .flights) ?? []
        if let stays = try c.decodeIfPresent([Stay].self, forKey: .stays), !stays.isEmpty {
            self.stays = stays
        } else {
            stays = [Stay(countryCode: try c.decode(String.self, forKey: .countryCode),
                          startDate: try c.decode(Date.self, forKey: .startDate),
                          endDate: try c.decode(Date.self, forKey: .endDate))]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encode(stays, forKey: .stays)
        try c.encode(flights, forKey: .flights)
    }

    // MARK: - Derived

    /// The first day of the first stay.
    var startDate: Date { stays.map(\.startDate).min() ?? .distantPast }
    /// The last day of the last stay.
    var endDate: Date { stays.map(\.endDate).max() ?? .distantPast }

    /// The countries in travel order, each once.
    var countryCodes: [String] {
        var seen = Set<String>()
        return stays.map(\.countryCode).filter { seen.insert($0).inserted }
    }
    /// The first country.
    var countryCode: String { stays.first?.countryCode ?? "" }

    var flag: String { CountryCatalog.flag(for: countryCode) }
    /// Up to three flags, e.g. "🇵🇪🇧🇷".
    var flags: String {
        let all = countryCodes.map(CountryCatalog.flag(for:))
        return all.prefix(3).joined() + (all.count > 3 ? "…" : "")
    }

    /// The user's name for the trip, else its countries: "Peru, Brazil".
    var displayName: String {
        if let name, !name.isEmpty { return name }
        let names = countryCodes.map(CountryCatalog.name(for:))
        guard names.count > 3 else { return names.joined(separator: ", ") }
        return names.prefix(3).joined(separator: ", ") + " +\(names.count - 3)"
    }

    /// Flights in travel order: dated ones by date, undated ones after them as entered.
    var sortedFlights: [PlannedTrip.Flight] { Self.sorted(flights) }

    static func sorted(_ flights: [Flight]) -> [Flight] {
        flights.enumerated()
            .sorted { a, b in
                switch (a.element.date, b.element.date) {
                case let (x?, y?) where x != y: return x < y
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.offset < b.offset
                }
            }
            .map(\.element)
    }

    /// The stay the user is in on `date`. On a day two stays share, the later one: that's
    /// the country they travel to.
    func stay(on date: Date, calendar: Calendar = .current) -> Stay? {
        let day = calendar.startOfDay(for: date)
        return stays.last { day >= $0.startDate && day <= $0.endDate }
    }

    // MARK: - Dates

    /// How many days the trip lasts, both ends included.
    func length(calendar: Calendar = .current) -> Int {
        (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
    }

    /// Calendar days until the first day: 0 on the day itself, negative once it has started.
    func daysUntilStart(now: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: startDate).day ?? 0
    }

    /// Which day of the trip `now` falls on (1-based), or nil outside the trip.
    func dayNumber(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard isUnderway(now: now, calendar: calendar) else { return nil }
        return -daysUntilStart(now: now, calendar: calendar) + 1
    }

    func hasStarted(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: now) >= startDate
    }

    /// True from the first day up to and including the last.
    func isUnderway(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: now)
        return today >= startDate && today <= endDate
    }

    /// True from the day after the last day.
    func isOver(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: now) > endDate
    }

    // MARK: - Matching photo trips

    /// The photo trip that is this plan, if there is one. See `matchingTrip(from:to:countryCodes:in:)`.
    func matchingTrip(in trips: [Trip], calendar: Calendar = .current) -> Trip? {
        Self.matchingTrip(from: startDate, to: endDate, countryCodes: Set(countryCodes),
                          in: trips, calendar: calendar)
    }

    /// The photo trip taken between two days: of the trips whose days overlap the range, the
    /// one with the most days in common, preferring one through any of `countryCodes` on a
    /// tie. Manual trips are left out — they're the user's own record, not a trip in progress.
    static func matchingTrip(from start: Date, to end: Date, countryCodes: Set<String> = [],
                             in trips: [Trip], calendar: Calendar = .current) -> Trip? {
        let first = calendar.startOfDay(for: start), last = calendar.startOfDay(for: end)
        func shared(_ trip: Trip) -> Int {
            let from = max(first, calendar.startOfDay(for: trip.startDate))
            let to = min(last, calendar.startOfDay(for: trip.endDate))
            return (calendar.dateComponents([.day], from: from, to: to).day ?? -1) + 1
        }
        func visits(_ trip: Trip) -> Bool { trip.countryCodes.contains(where: countryCodes.contains) }
        return trips
            .filter { !$0.isManual && shared($0) > 0 }
            .max { a, b in
                let (sa, sb) = (shared(a), shared(b))
                if sa != sb { return sa < sb }
                return !visits(a) && visits(b)
            }
    }
}
