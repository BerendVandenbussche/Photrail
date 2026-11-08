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
