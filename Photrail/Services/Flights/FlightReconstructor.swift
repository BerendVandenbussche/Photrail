import Foundation
import CoreLocation

/// A guess at how a past trip was flown, offered as a hint the user can add, edit or dismiss.
/// Never saved on its own.
struct FlightHint: Equatable {
    struct Leg: Equatable {
        var flight: PlannedTrip.Flight
        /// Whether a photo was taken at that airport; otherwise it's inferred.
        var fromSeen: Bool
        var toSeen: Bool
    }

    var legs: [Leg]
    /// The home airport filled in where no photo shows one, when there was no history to learn
    /// it from: the user should get to pick it.
    var homeIsGuess: Bool
    /// That inferred home airport, so a different pick can replace it.
    var homeAirport: String?

    var flights: [PlannedTrip.Flight] { legs.map(\.flight) }

    /// The route for display, inferred airports marked: "BRU? → FRA → LIM?".
    var routeText: String {
        var parts: [String] = []
        var lastCode: String?
        for leg in legs {
            if leg.flight.from != lastCode { parts.append(leg.flight.from + (leg.fromSeen ? "" : "?")) }
            parts.append(leg.flight.to + (leg.toSeen ? "" : "?"))
            lastCode = leg.flight.to
        }
        return parts.joined(separator: " → ")
    }

    /// The same hint with another inferred home airport.
    func replacingHomeAirport(with code: String) -> FlightHint {
        guard let homeAirport, code != homeAirport else { return self }
        var copy = self
        for i in copy.legs.indices {
            if !copy.legs[i].fromSeen, copy.legs[i].flight.from == homeAirport { copy.legs[i].flight.from = code }
            if !copy.legs[i].toSeen, copy.legs[i].flight.to == homeAirport { copy.legs[i].flight.to = code }
        }
        copy.homeAirport = code
        return copy
    }
}

/// Reconstructs a trip's flights from the photos around it: photos taken at airports show where
/// and when you flew; home airports and the airport nearest your first and
/// last stop fill the gaps. Pure: no photo library, no network.
enum FlightReconstructor {
    /// Two airport visits further apart than this aren't one flight (with a connection).
    static let maxLegGap: TimeInterval = 30 * 3600
    /// Airports closer together than this aren't a flight (CDG and ORY, a road trip past one).
    static let minLegKm: Double = 100
    /// With only a photo at the home airport, a trip this close to home was most likely driven.
    static let minGuessKm: Double = 300
    /// An airport further than this from the first (or last) stop was a layover, not where the
    /// trip landed (or left from).
    static let layoverKm: Double = 300

    /// Photos at the same airport within this long are one visit.
    private static let visitMerge: TimeInterval = 12 * 3600

    struct Visit: Equatable {
        let iata: String
        var start: Date
        var end: Date
    }

    /// The photos to pass to `make`: from the day before the trip until the day after.
    static func window(for trip: Trip, calendar: Calendar = .current) -> ClosedRange<Date> {
        let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: trip.startDate))
            ?? trip.startDate
        let end = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: trip.endDate))
            ?? trip.endDate
        return start...end
    }

    /// - Parameters:
    ///   - photos: every photo in `window(for: trip)`, not only the trip's own: airport hubs
    ///     are left out of trips, and a photo at the home airport falls outside the trip.
    ///   - homeAirports: `HomeAirports.rank`, most used first.
    ///   - requireEvidence: true for a hint shown unasked, which needs a photo taken at an
    ///     airport; false to prefill the editor when the user adds flights themselves.
    static func make(trip: Trip,
                     photos: [GeoPhoto],
                     homeAirports: [String],
                     home: CLLocationCoordinate2D?,
                     homeCountryCode: String?,
                     requireEvidence: Bool = true,
                     calendar: Calendar = .current) -> FlightHint? {
        guard !trip.isManual else { return nil }
        let range = window(for: trip, calendar: calendar)
        let inWindow = photos.filter { range.contains($0.date) }.sorted { $0.date < $1.date }

        let visits = Self.visits(in: inWindow)
        func isHome(_ code: String) -> Bool {
            if homeAirports.contains(code) { return true }
            guard let airport = AirportDirectory.airport(code) else { return false }
            if let homeCountryCode, airport.countryCode == homeCountryCode { return true }
            guard let home else { return false }
            return CLLocation(latitude: airport.latitude, longitude: airport.longitude)
                .distance(from: CLLocation(latitude: home.latitude, longitude: home.longitude)) <= HomeAirports.maxKm * 1000
        }

        // Evidence: a photo taken at an airport. Without one there's no hint at all (a guess
        // from nothing feels wrong more often than right). A photo at the home airport alone
        // (dropping someone off) only counts for a trip far from home: one close to home without
        // a photo at an airport abroad was most likely driven.
        if requireEvidence {
            guard !visits.isEmpty else { return nil }
            if !visits.contains(where: { !isHome($0.iata) }), let home {
                let km = CLLocation(latitude: trip.coordinate.latitude, longitude: trip.coordinate.longitude)
                    .distance(from: CLLocation(latitude: home.latitude, longitude: home.longitude)) / 1000
                guard km >= minGuessKm else { return nil }
            }
        }

        // The home airport for ends no photo shows: the most used one, else the nearest.
        let learned = homeAirports.first
        let homeCode = learned ?? home.flatMap {
            HomeAirports.candidates(home: $0, homeCountryCode: homeCountryCode).first?.iata
        }

        var legs = evidenceLegs(visits, calendar: calendar)
        let stops = trip.stops.sorted { $0.firstVisit < $1.firstVisit }
        let firstPlace = stops.first.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            ?? CLLocationCoordinate2D(latitude: trip.coordinate.latitude, longitude: trip.coordinate.longitude)
        let lastPlace = stops.last.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            ?? firstPlace
        var usedHomeGuess = false

        // Getting there.
        let firstDay = calendar.startOfDay(for: trip.startDate)
        let outboundUntil = calendar.date(byAdding: .day, value: 1, to: firstDay) ?? firstDay
        let outboundCovered = legs.first.map { isHome($0.flight.from) && ($0.flight.date ?? .distantFuture) < outboundUntil } ?? false
        if !outboundCovered {
            var from: (code: String, seen: Bool)?
            if let visit = visits.first, isHome(visit.iata), visit.start < outboundUntil {
                from = (visit.iata, true)
            } else if let homeCode {
                from = (homeCode, false)
            }
            var to: (code: String, seen: Bool)?
            if let leg = legs.first, !isHome(leg.flight.from), (leg.flight.date ?? .distantFuture) < outboundUntil {
                to = (leg.flight.from, leg.fromSeen)
            } else if let visit = visits.first(where: { !isHome($0.iata) && $0.start < outboundUntil }) {
                to = (visit.iata, true)
            } else if let airport = AirportDirectory.nearestLarge(to: firstPlace) {
                to = (airport.iata, false)
            }
            if let from, let to, isFlight(from.code, to.code) {
                legs.insert(FlightHint.Leg(flight: PlannedTrip.Flight(from: from.code, to: to.code, date: firstDay),
                                           fromSeen: from.seen, toSeen: to.seen), at: 0)
                if !from.seen { usedHomeGuess = true }
            }
        }
        // A way out that stops at a layover (photos at BRU and FRA, none on arrival): on to
        // the airport nearest the first stop.
        if let first = legs.first, (first.flight.date ?? .distantFuture) < outboundUntil {
            var end = 0
            // Only on past a layover: an airport near the first stop is where the trip landed.
            while end + 1 < legs.count, isFar(legs[end].flight.to, from: firstPlace),
                  legs[end + 1].flight.from == legs[end].flight.to,
                  (legs[end + 1].flight.date ?? .distantFuture) < outboundUntil { end += 1 }
            let reached = legs[end]
            if isFar(reached.flight.to, from: firstPlace),
               let airport = AirportDirectory.nearestLarge(to: firstPlace),
               isFlight(reached.flight.to, airport.iata) {
                legs.insert(FlightHint.Leg(flight: PlannedTrip.Flight(from: reached.flight.to, to: airport.iata,
                                                                      date: reached.flight.date),
                                           fromSeen: reached.toSeen, toSeen: false), at: end + 1)
            }
        }

        // Coming home.
        let lastDay = calendar.startOfDay(for: trip.endDate)
        let returnFrom = lastDay
        let returnCovered = legs.last.map { isHome($0.flight.to) && ($0.flight.date ?? .distantPast) >= returnFrom } ?? false
        if !returnCovered {
            var to: (code: String, seen: Bool)?
            if let visit = visits.last, isHome(visit.iata), visit.end >= returnFrom {
                to = (visit.iata, true)
            } else if let homeCode {
                to = (homeCode, false)
            }
            var from: (code: String, seen: Bool)?
            if let leg = legs.last, !isHome(leg.flight.to), (leg.flight.date ?? .distantPast) >= returnFrom {
                from = (leg.flight.to, leg.toSeen)
            } else if let visit = visits.last(where: { !isHome($0.iata) && $0.end >= returnFrom }) {
                from = (visit.iata, true)
            } else if let airport = AirportDirectory.nearestLarge(to: lastPlace) {
                from = (airport.iata, false)
            }
            if let from, let to, isFlight(from.code, to.code) {
                legs.append(FlightHint.Leg(flight: PlannedTrip.Flight(from: from.code, to: to.code, date: lastDay),
                                           fromSeen: from.seen, toSeen: to.seen))
                if !to.seen { usedHomeGuess = true }
            }
        }
        // A way home that starts at a layover: from the airport nearest the last stop.
        if let last = legs.last, (last.flight.date ?? .distantPast) >= returnFrom {
            var start = legs.count - 1
            // Only back past a layover: an airport near the last stop is where the trip left from.
            while start > 0, isFar(legs[start].flight.from, from: lastPlace),
                  legs[start - 1].flight.to == legs[start].flight.from,
                  (legs[start - 1].flight.date ?? .distantPast) >= returnFrom { start -= 1 }
            let leaving = legs[start]
            if isFar(leaving.flight.from, from: lastPlace),
               let airport = AirportDirectory.nearestLarge(to: lastPlace),
               isFlight(airport.iata, leaving.flight.from) {
                legs.insert(FlightHint.Leg(flight: PlannedTrip.Flight(from: airport.iata, to: leaving.flight.from,
                                                                      date: leaving.flight.date),
                                           fromSeen: false, toSeen: leaving.fromSeen), at: start)
            }
        }

        guard !legs.isEmpty else { return nil }
        return FlightHint(legs: legs,
                          homeIsGuess: usedHomeGuess && learned == nil,
                          homeAirport: usedHomeGuess ? homeCode : nil)
    }

    /// Photos at airports, in time order, with photos at the same airport merged.
    static func visits(in photos: [GeoPhoto]) -> [Visit] {
        var result: [Visit] = []
        for photo in photos {
            let coordinate = CLLocationCoordinate2D(latitude: photo.coordinate.latitude,
                                                    longitude: photo.coordinate.longitude)
            guard let airport = AirportDirectory.airport(at: coordinate) else { continue }
            if let last = result.last, last.iata == airport.iata,
               photo.date.timeIntervalSince(last.end) <= visitMerge {
                result[result.count - 1].end = photo.date
            } else {
                result.append(Visit(iata: airport.iata, start: photo.date, end: photo.date))
            }
        }
        return result
    }

    /// One leg for each two airports photographed shortly after one another, far enough apart.
    private static func evidenceLegs(_ visits: [Visit], calendar: Calendar) -> [FlightHint.Leg] {
        zip(visits, visits.dropFirst()).compactMap { a, b in
            guard b.start.timeIntervalSince(a.end) <= maxLegGap, isFlight(a.iata, b.iata) else { return nil }
            return FlightHint.Leg(flight: PlannedTrip.Flight(from: a.iata, to: b.iata,
                                                             date: calendar.startOfDay(for: a.end)),
                                  fromSeen: true, toSeen: true)
        }
    }

    /// Whether an airport is too far from a place to be where the trip landed or left from.
    private static func isFar(_ code: String, from place: CLLocationCoordinate2D) -> Bool {
        guard let airport = AirportDirectory.airport(code) else { return false }
        return CLLocation(latitude: airport.latitude, longitude: airport.longitude)
            .distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude)) > layoverKm * 1000
    }

    private static func isFlight(_ from: String, _ to: String) -> Bool {
        guard from != to, let a = AirportDirectory.airport(from), let b = AirportDirectory.airport(to) else { return false }
        let meters = CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        return meters >= minLegKm * 1000
    }
}
