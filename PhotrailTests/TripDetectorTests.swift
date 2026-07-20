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
    // A Canada road trip through a border town that geocodes to the US side.
    private let wawa       = (lat: 47.99, lon: -84.77, code: "CA", name: "Canada", city: "Wawa")
    private let saultUS    = (lat: 46.50, lon: -84.34, code: "US", name: "United States", city: "Sault Ste. Marie")
    private let timmins    = (lat: 48.47, lon: -81.33, code: "CA", name: "Canada", city: "Timmins")

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

    func testPragueThenCanadaNextDayStillSplits() {
        // Flew Prague → home → Canada within a day (barely any gap). The "direct travel"
        // shortcut used to merge these because they happened fast — but home sits between
        // Prague and Canada, so it's two trips. Mirrors the real Czech + Canada report.
        let photos = [
            photo(prague, day: 0), photo(prague, day: 1),
            photo(toronto, day: 2), photo(toronto, day: 3), photo(toronto, day: 9),
        ]
        let trips = detector.detect(from: photos, homeCoordinate: home)
        XCTAssertEqual(trips.count, 2, "A fast hop through home is still two trips")
        XCTAssertEqual(Set(trips.flatMap(\.countryCodes)), ["CZ", "CA"])
        // The Canada trip stays whole (all same-country photos never split).
        let canada = trips.first { $0.countryCodes.contains("CA") }
        XCTAssertEqual(canada?.countryCodes, ["CA"])
    }

    func testBorderTownBlipDoesNotSplitTheTrip() {
        // A Canada road trip where one photo near the border geocoded to the US side,
        // with a multi-day gap around it. The lone US label used to split the trip in two;
        // a short physical hop is the same journey even across a border.
        let photos = [
            photo(wawa, day: 0), photo(wawa, day: 1),
            photo(saultUS, day: 7),                       // border town, 6-day gap
            photo(timmins, day: 8), photo(timmins, day: 12),
        ]
        let trips = detector.detect(from: photos, homeCoordinate: home)
        XCTAssertEqual(trips.count, 1, "A border-town blip shouldn't split one road trip")
        XCTAssertEqual(Set(trips[0].countryCodes), ["CA", "US"])
    }

    func testStopInHomeCountryEndsTheTripEvenAwayFromHomeTown() {
        // Prague → a Belgian city that ISN'T the home town (Ghent, ~55km from Brussels) →
        // Canada. Passing back through the home *country* must end the Czech trip, so Prague
        // and Canada are separate — this is the "Czech merged into Canada" report.
        let ghent = (lat: 51.05, lon: 3.72, code: "BE", name: "Belgium", city: "Ghent")
        let photos = [
            photo(prague, day: 0), photo(prague, day: 1),
            photo(ghent, day: 2),
            photo(toronto, day: 3), photo(toronto, day: 8),
        ]
        let trips = detector.detect(from: photos, homeCountryCode: "BE", homeCoordinate: home)
        XCTAssertEqual(trips.count, 2, "A stop in the home country splits Prague from Canada")
        XCTAssertEqual(Set(trips.flatMap(\.countryCodes)), ["CZ", "CA"])
        for trip in trips { XCTAssertFalse(trip.countryCodes.contains("BE"), "Home country isn't a trip") }
    }

    func testLayoverAtAirportDoesNotAddTransitCountry() {
        // Home (Belgium) → a photo at Frankfurt airport (layover) → Brazil. The Frankfurt
        // photo must not turn the Brazil holiday into a "Germany + Brazil" trip.
        let homeLoc = (lat: home.latitude, lon: home.longitude, code: "BE", name: "Belgium", city: "Brussels")
        let frankfurtAirport = (lat: 50.037, lon: 8.562, code: "DE", name: "Germany", city: "Frankfurt")
        let saoPaulo = (lat: -23.55, lon: -46.63, code: "BR", name: "Brazil", city: "São Paulo")
        let photos = [
            photo(homeLoc, day: 0),
            photo(frankfurtAirport, day: 0, seq: 6),
            photo(saoPaulo, day: 0, seq: 14), photo(saoPaulo, day: 5),
        ]
        let trips = detector.detect(from: photos, homeCountryCode: "BE", homeCoordinate: home)
        XCTAssertEqual(trips.count, 1, "One Brazil trip")
        XCTAssertEqual(trips[0].countryCodes, ["BR"], "The Frankfurt layover isn't part of the trip")
    }

    func testHomeGpsSpikeMidTripDoesNotSplit() {
        // A Canada road trip with one photo that geocoded to home (Belgium) in the middle —
        // a screenshot or GPS-defaulted image. It's ~6000km from the Canada photos on both
        // sides, which are close together. It must be ignored, not used as a trip boundary.
        let homeLoc = (lat: home.latitude, lon: home.longitude, code: "BE", name: "Belgium", city: "Brussels")
        let photos = [
            photo(wawa, day: 0), photo(wawa, day: 1),
            photo(homeLoc, day: 1, seq: 12),          // spurious Belgium spike mid-trip
            photo(timmins, day: 1, seq: 20), photo(timmins, day: 3),
        ]
        let trips = detector.detect(from: photos, homeCoordinate: home)
        XCTAssertEqual(trips.count, 1, "A home-GPS spike mustn't split the Canada trip")
        XCTAssertEqual(trips[0].countryCodes, ["CA"], "The spurious BE photo is excluded")
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
