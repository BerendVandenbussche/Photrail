import XCTest
import CoreLocation
@testable import Photrail

/// Verifies trips are split on geographic plausibility, not just a flat time gap —
/// the "Prague weekend + Canada holiday merged into one trip" bug.
final class TripDetectorTests: XCTestCase {

    private let detector = TripDetector()

    // Home base for these tests: Brussels, Belgium.
    private let home = GeoPhoto.Coordinate(latitude: 50.85, longitude: 4.35)

    // A few reference locations.
    private let prague     = (lat: 50.09, lon: 14.42, code: "CZ", name: "Czechia",     city: "Prague")
    private let toronto    = (lat: 43.65, lon: -79.38, code: "CA", name: "Canada",     city: "Toronto")
    private let paris      = (lat: 48.85, lon: 2.35,  code: "FR", name: "France",      city: "Paris")
    private let milan      = (lat: 45.46, lon: 9.19,  code: "IT", name: "Italy",       city: "Milan")
    private let bangkok    = (lat: 13.75, lon: 100.50, code: "TH", name: "Thailand",   city: "Bangkok")
    private let sydney     = (lat: -33.87, lon: 151.21, code: "AU", name: "Australia", city: "Sydney")

    private func photo(_ loc: (lat: Double, lon: Double, code: String, name: String, city: String),
                       day: Int, seq: Int = 0) -> GeoPhoto {
        // day + seq (hours) → a deterministic date. seq keeps same-day photos ordered.
        let t = TimeInterval(day) * 86_400 + TimeInterval(seq) * 3_600
        return GeoPhoto(id: "\(loc.city)-\(day)-\(seq)",
                        coordinate: .init(latitude: loc.lat, longitude: loc.lon),
                        date: Date(timeIntervalSince1970: t),
                        country: loc.name, countryCode: loc.code,
                        city: loc.city, isGeocoded: true)
    }

    // MARK: - The reported bug

    func testPragueWeekendAndCanadaHolidayAreSeparateTrips() {
        // Weekend in Prague, then ~5 days later a holiday in Canada. No home photo in
        // between (nothing geotagged at home) — the old flat 7-day gap merged these.
        let photos = [
            photo(prague, day: 0), photo(prague, day: 1),
            photo(toronto, day: 6), photo(toronto, day: 7), photo(toronto, day: 12),
        ]
        let trips = detector.detect(from: photos, homeCoordinate: home)
        XCTAssertEqual(trips.count, 2, "Prague and Canada should be two trips")
        XCTAssertEqual(Set(trips.flatMap(\.countryCodes)), ["CZ", "CA"])
        for trip in trips { XCTAssertFalse(trip.isMultiCountry, "Neither trip spans countries") }
    }

    // MARK: - Genuine journeys stay whole

    func testEuropeanRoadTripStaysOneTrip() {
        // Belgium-based road trip: Paris → Milan, a few days apart, staying abroad.
        let photos = [
            photo(paris, day: 0), photo(paris, day: 1),
            photo(milan, day: 3), photo(milan, day: 4),
        ]
        let trips = detector.detect(from: photos, homeCoordinate: home)
        XCTAssertEqual(trips.count, 1, "A continuous Euro trip is one trip")
        XCTAssertTrue(trips[0].isMultiCountry)
        XCTAssertEqual(Set(trips[0].countryCodes), ["FR", "IT"])
    }

    func testDirectLongHaulLegStaysOneTrip() {
        // Bangkok → Sydney the next day (a direct flight leg) — one big trip, no home visit.
        let photos = [
            photo(bangkok, day: 0), photo(bangkok, day: 1),
            photo(sydney, day: 2), photo(sydney, day: 4),
        ]
        let trips = detector.detect(from: photos, homeCoordinate: home)
        XCTAssertEqual(trips.count, 1, "A same-journey long-haul leg shouldn't split")
        XCTAssertEqual(Set(trips[0].countryCodes), ["TH", "AU"])
    }

    func testReturningHomeEndsTheTrip() {
        // Prague, home for a bit, then Paris → two trips regardless of scoring.
        let homeLoc = (lat: home.latitude, lon: home.longitude, code: "BE", name: "Belgium", city: "Brussels")
        let photos = [
            photo(prague, day: 0),
            photo(homeLoc, day: 2),
            photo(paris, day: 4),
        ]
        let trips = detector.detect(from: photos, homeCoordinate: home)
        XCTAssertEqual(trips.count, 2)
    }

    // MARK: - The score directly

    func testSameTripProbabilityRanksPlausibilityCorrectly() {
        let homeLoc = CLLocation(latitude: home.latitude, longitude: home.longitude)

        // Prague → Canada, 5-day gap: implausible as one journey.
        let pragueToCanada = detector.sameTripProbability(
            from: photo(prague, day: 0), to: photo(toronto, day: 5),
            gapDays: 5, home: homeLoc)
        XCTAssertLessThan(pragueToCanada, 0.5)

        // Paris → Milan, 2-day gap: plausibly the same trip.
        let parisToMilan = detector.sameTripProbability(
            from: photo(paris, day: 0), to: photo(milan, day: 2),
            gapDays: 2, home: homeLoc)
        XCTAssertGreaterThanOrEqual(parisToMilan, 0.5)

        // Same-day travel is always the same journey, however far.
        let sameDay = detector.sameTripProbability(
            from: photo(bangkok, day: 0), to: photo(sydney, day: 0, seq: 6),
            gapDays: 0.25, home: homeLoc)
        XCTAssertEqual(sameDay, 1)
    }
}
