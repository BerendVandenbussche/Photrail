import XCTest
import CoreLocation
@testable import Photrail

/// The date logic behind upcoming trips: countdowns, underway/over across midnight, the
/// calendar's planned days, and matching a plan to the photo trip it became.
final class PlannedTripTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func plan(_ start: Date, _ end: Date, code: String = "JP") -> PlannedTrip {
        PlannedTrip(id: "p", name: "Tokyo", countryCode: code,
                    startDate: start, endDate: end, calendar: calendar)
    }

    private func trip(id: String, _ start: Date, _ end: Date, code: String = "JP") -> Trip {
        Trip(id: id, countryCode: code, country: code, flag: "🏳️",
             countries: [.init(id: code, name: code, flag: "🏳️", photoCount: 1)],
             startDate: start, endDate: end, photoCount: 1, cities: [], stops: [],
             photoIDs: ["x"], coordinate: .init(latitude: 0, longitude: 0),
             highestAltitude: nil, wonders: [])
    }

    func testDatesAreStoredAsWholeDaysAndEndNeverBeforeStart() {
        let p = plan(date(2026, 3, 12, 18), date(2026, 3, 10, 9))
        XCTAssertEqual(p.startDate, calendar.startOfDay(for: date(2026, 3, 12)))
        XCTAssertEqual(p.endDate, p.startDate)
        XCTAssertEqual(p.length(calendar: calendar), 1)
    }

    func testCountdownCountsCalendarDaysNotHours() {
        let p = plan(date(2026, 3, 12), date(2026, 3, 19))
        // 23:59 the evening before is still "1 day", 00:01 on the day is "0".
        XCTAssertEqual(p.daysUntilStart(now: date(2026, 3, 11, 23, 59), calendar: calendar), 1)
        XCTAssertEqual(p.daysUntilStart(now: date(2026, 3, 12, 0, 1), calendar: calendar), 0)
        XCTAssertEqual(p.daysUntilStart(now: date(2026, 3, 5, 8), calendar: calendar), 7)
    }

    func testUnderwayIncludesBothEndsAndOverStartsTheDayAfter() {
        let p = plan(date(2026, 3, 12), date(2026, 3, 19))
        XCTAssertFalse(p.isUnderway(now: date(2026, 3, 11, 23, 59), calendar: calendar))
        XCTAssertTrue(p.isUnderway(now: date(2026, 3, 12, 0, 1), calendar: calendar))
        XCTAssertTrue(p.isUnderway(now: date(2026, 3, 19, 23, 59), calendar: calendar))
        XCTAssertFalse(p.isOver(now: date(2026, 3, 19, 23, 59), calendar: calendar))
        XCTAssertTrue(p.isOver(now: date(2026, 3, 20, 0, 1), calendar: calendar))
        XCTAssertEqual(p.dayNumber(now: date(2026, 3, 14), calendar: calendar), 3)
        XCTAssertNil(p.dayNumber(now: date(2026, 3, 20), calendar: calendar))
        XCTAssertEqual(p.length(calendar: calendar), 8)
    }

    func testCalendarPlannedDaysSkipDaysCoveredByPhotos() {
        let p = plan(date(2026, 3, 30), date(2026, 4, 2))
        let march = TripCalendar.plannedEntries(for: date(2026, 3, 1), planned: [p],
                                                excluding: [31], calendar: calendar)
        XCTAssertEqual(Set(march.keys), [30])
        let april = TripCalendar.plannedEntries(for: date(2026, 4, 1), planned: [p], calendar: calendar)
        XCTAssertEqual(Set(april.keys), [1, 2])
    }

    func testMatchingTripPicksMostSharedDaysThenTheDestination() {
        let p = plan(date(2026, 3, 12), date(2026, 3, 19))
        let before = trip(id: "before", date(2026, 3, 1), date(2026, 3, 5))
        let small = trip(id: "small", date(2026, 3, 11), date(2026, 3, 12), code: "KR")
        let main = trip(id: "main", date(2026, 3, 13), date(2026, 3, 18))
        XCTAssertEqual(p.matchingTrip(in: [before, small, main], calendar: calendar)?.id, "main")
        XCTAssertNil(p.matchingTrip(in: [before], calendar: calendar))

        // Equal overlap: the trip through the planned country wins.
        let elsewhere = trip(id: "elsewhere", date(2026, 3, 12), date(2026, 3, 13), code: "KR")
        let destination = trip(id: "destination", date(2026, 3, 18), date(2026, 3, 19))
        XCTAssertEqual(p.matchingTrip(in: [elsewhere, destination], calendar: calendar)?.id, "destination")
    }

    // MARK: - Flights

    func testPlansSavedBeforeFlightsStillDecode() throws {
        let legacy = #"{"id":"p","name":"Tokyo","countryCode":"JP","startDate":0,"endDate":86400}"#
        let decoded = try JSONDecoder().decode(PlannedTrip.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.countryCode, "JP")
        XCTAssertTrue(decoded.flights.isEmpty)
    }

    func testFlightsRoundTrip() throws {
        var p = plan(date(2026, 3, 12), date(2026, 3, 19))
        p.flights = [.init(from: "BRU", to: "IST"), .init(from: "IST", to: "NRT")]
        let decoded = try JSONDecoder().decode(PlannedTrip.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.flights.map(\.to), ["IST", "NRT"])
    }

    func testAirportDirectoryLookupAndSearch() {
        XCTAssertEqual(AirportDirectory.airport("bru")?.countryCode, "BE")
        XCTAssertEqual(AirportDirectory.search("NRT").first?.iata, "NRT")
        // Accent-insensitive city match.
        XCTAssertTrue(AirportDirectory.search("zurich").contains { $0.iata == "ZRH" })
        // From Antwerp, the suggested departure is Brussels rather than the small local airport.
        let antwerp = CLLocationCoordinate2D(latitude: 51.2194, longitude: 4.4025)
        XCTAssertEqual(AirportDirectory.nearest(to: antwerp)?.iata, "BRU")
    }

    // MARK: - Multi-country

    private func twoCountryPlan() -> PlannedTrip {
        PlannedTrip(id: "p", name: nil, stays: [
            // Given out of order on purpose: the plan sorts them.
            .init(countryCode: "BR", startDate: date(2026, 12, 6), endDate: date(2026, 12, 14)),
            .init(countryCode: "PE", startDate: date(2026, 11, 29), endDate: date(2026, 12, 6)),
        ], calendar: calendar)
    }

    func testTripDatesSpanAllCountries() {
        let p = twoCountryPlan()
        XCTAssertEqual(p.countryCodes, ["PE", "BR"])
        XCTAssertEqual(p.startDate, calendar.startOfDay(for: date(2026, 11, 29)))
        XCTAssertEqual(p.endDate, calendar.startOfDay(for: date(2026, 12, 14)))
        XCTAssertEqual(p.length(calendar: calendar), 16)
    }

    func testSharedTravelDayBelongsToTheNextCountry() {
        let p = twoCountryPlan()
        XCTAssertEqual(p.stay(on: date(2026, 12, 5), calendar: calendar)?.countryCode, "PE")
        XCTAssertEqual(p.stay(on: date(2026, 12, 6), calendar: calendar)?.countryCode, "BR")
        XCTAssertNil(p.stay(on: date(2026, 12, 15), calendar: calendar))
    }

    func testSingleCountryPlansFromBeforeMultiCountryDecodeAsOneStay() throws {
        let legacy = #"{"id":"p","countryCode":"JP","startDate":0,"endDate":86400,"flights":[{"id":"f","from":"BRU","to":"NRT"}]}"#
        let decoded = try JSONDecoder().decode(PlannedTrip.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.stays.count, 1)
        XCTAssertEqual(decoded.countryCode, "JP")
        XCTAssertNil(decoded.flights.first?.date)
        // And it now saves in the new shape.
        let again = try JSONDecoder().decode(PlannedTrip.self, from: JSONEncoder().encode(decoded))
        XCTAssertEqual(again.stays.map(\.countryCode), ["JP"])
    }

    func testFlightsSortByDateWithUndatedLast() {
        let flights: [PlannedTrip.Flight] = [
            .init(id: "undated", from: "LIM", to: "GRU"),
            .init(id: "home", from: "GRU", to: "BRU", date: date(2026, 12, 14)),
            .init(id: "out", from: "BRU", to: "LIM", date: date(2026, 11, 29)),
        ]
        XCTAssertEqual(PlannedTrip.sorted(flights).map(\.id), ["out", "home", "undated"])
    }

    func testSuggestionsCoverGettingThereEachBorderAndHome() {
        let suggestions = FlightSuggestions.make(segments: FlightSuggestions.segments(for: twoCountryPlan()),
                                                 home: nil)
        XCTAssertEqual(suggestions.map(\.kind), [.outbound, .between(from: "PE", to: "BR"), .home])
        XCTAssertEqual(suggestions.map { calendar.startOfDay(for: $0.date) },
                       [date(2026, 11, 29), date(2026, 12, 6), date(2026, 12, 14)].map(calendar.startOfDay(for:)))
    }
}
