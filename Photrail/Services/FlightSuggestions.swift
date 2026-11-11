import Foundation
import CoreLocation

/// The flights a trip most likely had, as starting points for adding them: getting there, one
/// per change of country, and coming home. Shared by plans and past trips.
///
/// Only the home side gets an airport filled in (the one nearest home). The country side is
/// left open, with the airport search pre-filled with the country's name, because guessing
/// which of a country's airports someone flew to is wrong too often to be helpful.
struct FlightSuggestion: Identifiable, Hashable {
    enum Kind: Hashable {
        case outbound
        case between(from: String, to: String)   // country codes
        case home
    }

    let kind: Kind
    /// The day of the flight.
    let date: Date
    /// IATA code to fill in, when known (the home airport).
    let fromAirport: String?
    let toAirport: String?
    /// Country names to start the airport searches with.
    let fromSearch: String?
    let toSearch: String?

    var id: String { "\(kind)-\(date.timeIntervalSince1970)" }

    var title: String {
        switch kind {
        case .outbound: return String(localized: "Getting there")
        case .home: return String(localized: "Coming home")
        case let .between(from, to):
            return "\(CountryCatalog.flag(for: from)) \(CountryCatalog.name(for: from)) → "
                + "\(CountryCatalog.flag(for: to)) \(CountryCatalog.name(for: to))"
        }
    }
}

enum FlightSuggestions {
    /// A stretch of a trip spent in one country.
    struct Segment: Equatable {
        let countryCode: String
        let start: Date
        let end: Date
    }

    static func make(segments: [Segment], home: CLLocationCoordinate2D?) -> [FlightSuggestion] {
        guard let first = segments.first, let last = segments.last else { return [] }
        let homeAirport = home.flatMap { AirportDirectory.nearest(to: $0)?.iata }

        var result = [FlightSuggestion(kind: .outbound, date: first.start,
                                       fromAirport: homeAirport, toAirport: nil,
                                       fromSearch: nil, toSearch: CountryCatalog.name(for: first.countryCode))]
        for (a, b) in zip(segments, segments.dropFirst()) where a.countryCode != b.countryCode {
            result.append(FlightSuggestion(kind: .between(from: a.countryCode, to: b.countryCode),
                                           date: b.start, fromAirport: nil, toAirport: nil,
                                           fromSearch: CountryCatalog.name(for: a.countryCode),
                                           toSearch: CountryCatalog.name(for: b.countryCode)))
        }
        result.append(FlightSuggestion(kind: .home, date: last.end,
                                       fromAirport: nil, toAirport: homeAirport,
                                       fromSearch: CountryCatalog.name(for: last.countryCode), toSearch: nil))
        return result
    }

    /// A trip's flights in three groups, each in travel order: the way out (the first flight
    /// and its connections), the way home (the last flight and the connections before it,
    /// when it lands back in the country the trip left from) and everything in between.
    struct Groups: Equatable {
        var outbound: [PlannedTrip.Flight] = []
        var during: [PlannedTrip.Flight] = []
        var home: [PlannedTrip.Flight] = []
    }

    static func grouped(_ flights: [PlannedTrip.Flight], calendar: Calendar = .current) -> Groups {
        let sorted = PlannedTrip.sorted(flights)
        guard let first = sorted.first, let last = sorted.last else { return Groups() }

        // The way out: forward from the first flight while each leg connects.
        var outCount = 1
        while outCount < sorted.count,
              connects(sorted[outCount - 1], sorted[outCount], calendar: calendar),
              !isSamePlace(sorted[outCount].to, first.from) {
            outCount += 1
        }

        // The way home: backward from the last flight, only if it ends where the trip began.
        var homeStart = sorted.count
        if sorted.count > outCount, isSamePlace(last.to, first.from) {
            homeStart -= 1
            while homeStart > outCount,
                  connects(sorted[homeStart - 1], sorted[homeStart], calendar: calendar) {
                homeStart -= 1
            }
        }

        return Groups(outbound: Array(sorted[..<outCount]),
                      during: Array(sorted[outCount..<homeStart]),
                      home: Array(sorted[homeStart...]))
    }

    /// The way out, mirrored: reversed and flipped, all on `date`. So BRU → IST, IST → NRT
    /// gives NRT → IST, IST → BRU. Nil when there's nothing to mirror or a flight already
    /// lands back where the trip started.
    static func returnFlights(for flights: [PlannedTrip.Flight], on date: Date,
                              calendar: Calendar = .current) -> [PlannedTrip.Flight]? {
        guard let first = PlannedTrip.sorted(flights).first,
              !flights.contains(where: { $0.to == first.from }) else { return nil }
        let day = calendar.startOfDay(for: date)
        return grouped(flights, calendar: calendar).outbound.reversed()
            .map { PlannedTrip.Flight(from: $0.to, to: $0.from, date: day) }
    }

    /// `next` leaves where `previous` landed, at most a day later (undated legs count).
    private static func connects(_ previous: PlannedTrip.Flight, _ next: PlannedTrip.Flight,
                                 calendar: Calendar) -> Bool {
        guard next.from == previous.to else { return false }
        guard let a = previous.date, let b = next.date else { return true }
        return abs(calendar.dateComponents([.day], from: a, to: b).day ?? 0) <= 1
    }

    /// The same airport, or two in the same country (out from BRU, back into CRL).
    private static func isSamePlace(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard let x = AirportDirectory.airport(a)?.countryCode,
              let y = AirportDirectory.airport(b)?.countryCode else { return false }
        return x == y
    }

    /// The likely day of a flight between two airports, from where they are in the trip:
    /// into the trip on the first day there, out of it (home) on the last day there, and
    /// between two of its countries on the day the next one starts. Nil for a flight within
    /// one country, or one the trip doesn't explain.
    static func date(from: String, to: String, segments: [Segment]) -> Date? {
        guard let fromCountry = AirportDirectory.airport(from)?.countryCode,
              let toCountry = AirportDirectory.airport(to)?.countryCode,
              fromCountry != toCountry else { return nil }
        return date(fromCountry: fromCountry, toCountry: toCountry, segments: segments)
    }

    static func date(fromCountry: String, toCountry: String, segments: [Segment]) -> Date? {
        let fromIndex = segments.firstIndex { $0.countryCode == fromCountry }
        let toIndex = segments.firstIndex { $0.countryCode == toCountry }
        switch (fromIndex, toIndex) {
        case (nil, let to?):
            return segments[to].start
        case (_?, nil):
            return segments.last { $0.countryCode == fromCountry }?.end
        case (let from?, _?):
            let next = segments[(from + 1)...].first { $0.countryCode == toCountry }
                ?? segments.first { $0.countryCode == toCountry }
            return next?.start
        case (nil, nil):
            return nil
        }
    }

    /// A plan's segments: its stays.
    static func segments(for plan: PlannedTrip) -> [Segment] {
        plan.stays.map { Segment(countryCode: $0.countryCode, start: $0.startDate, end: $0.endDate) }
    }

    /// A past trip's segments. Photo trips have dated stops, so each run of stops in one
    /// country is a segment; a manual trip only knows its country order and overall dates.
    static func segments(for trip: Trip, calendar: Calendar = .current) -> [Segment] {
        let stops = trip.stops.sorted { $0.firstVisit < $1.firstVisit }
        guard !stops.isEmpty, !trip.isManual else {
            return trip.countryCodes.enumerated().map { index, code in
                Segment(countryCode: code,
                        start: index == 0 ? trip.startDate : trip.endDate,
                        end: index == trip.countryCodes.count - 1 ? trip.endDate : trip.startDate)
            }
        }
        var result: [Segment] = []
        for stop in stops {
            let day = calendar.startOfDay(for: stop.firstVisit)
            if let last = result.last, last.countryCode == stop.countryCode { continue }
            if let last = result.popLast() {
                result.append(Segment(countryCode: last.countryCode, start: last.start, end: day))
            }
            result.append(Segment(countryCode: stop.countryCode, start: day, end: day))
        }
        if let last = result.popLast() {
            result.append(Segment(countryCode: last.countryCode, start: last.start,
                                  end: calendar.startOfDay(for: trip.endDate)))
        }
        return result
    }
}
