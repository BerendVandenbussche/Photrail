import XCTest
@testable import Photrail

/// "Same route back" (the way out, mirrored onto the trip's last day) and the default day
/// of a new flight.
final class ReturnFlightsTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: d))!
    }

    private func leg(_ from: String, _ to: String, _ d: Int?) -> PlannedTrip.Flight {
        PlannedTrip.Flight(from: from, to: to, date: d.map(day))
    }

    private func route(_ flights: [PlannedTrip.Flight]?) -> [String]? {
        flights.map { $0.map { "\($0.from)-\($0.to)" } }
    }

    func testDirectFlightIsMirrored() {
        let back = FlightSuggestions.returnFlights(for: [leg("BRU", "LIS", 1)], on: day(8), calendar: calendar)
        XCTAssertEqual(route(back), ["LIS-BRU"])
        XCTAssertEqual(back?.first?.date, day(8))
    }

    func testConnectionIsMirroredInReverseOrder() {
        let out = [leg("BRU", "IST", 1), leg("IST", "NRT", 2)]
        let back = FlightSuggestions.returnFlights(for: out, on: day(15), calendar: calendar)
        XCTAssertEqual(route(back), ["NRT-IST", "IST-BRU"])
    }

    func testFlightDaysLaterIsNotPartOfTheWayOut() {
        // Tokyo → Osaka a week in is a flight on the trip, not a connection.
        let flights = [leg("BRU", "NRT", 1), leg("NRT", "KIX", 8)]
        let back = FlightSuggestions.returnFlights(for: flights, on: day(15), calendar: calendar)
        XCTAssertEqual(route(back), ["NRT-BRU"])
    }

    func testNothingWhenAlreadyFlyingHome() {
        let flights = [leg("BRU", "LIS", 1), leg("LIS", "BRU", 8)]
        XCTAssertNil(FlightSuggestions.returnFlights(for: flights, on: day(8), calendar: calendar))
    }

    func testNothingWithoutFlights() {
        XCTAssertNil(FlightSuggestions.returnFlights(for: [], on: day(8), calendar: calendar))
    }

    func testUndatedConnectionCounts() {
        let out = [leg("BRU", "FRA", nil), leg("FRA", "JFK", nil)]
        let back = FlightSuggestions.returnFlights(for: out, on: day(10), calendar: calendar)
        XCTAssertEqual(route(back), ["JFK-FRA", "FRA-BRU"])
    }

    // MARK: - Default day of a new flight

    /// Portugal 1–5, Spain 5–9.
    private var segments: [FlightSuggestions.Segment] {
        [.init(countryCode: "PT", start: day(1), end: day(5)),
         .init(countryCode: "ES", start: day(5), end: day(9))]
    }

    func testFlightIntoTheTripIsOnTheFirstDay() {
        XCTAssertEqual(FlightSuggestions.date(fromCountry: "BE", toCountry: "PT", segments: segments), day(1))
    }

    func testFlightHomeIsOnTheLastDay() {
        XCTAssertEqual(FlightSuggestions.date(fromCountry: "ES", toCountry: "BE", segments: segments), day(9))
    }

    func testFlightBetweenCountriesIsWhenTheNextStarts() {
        XCTAssertEqual(FlightSuggestions.date(fromCountry: "PT", toCountry: "ES", segments: segments), day(5))
    }

    func testFlightOutsideTheTripHasNoGuess() {
        XCTAssertNil(FlightSuggestions.date(fromCountry: "BE", toCountry: "NL", segments: segments))
    }

    func testAirportsAreResolvedToCountries() {
        XCTAssertEqual(FlightSuggestions.date(from: "BRU", to: "LIS", segments: segments), day(1))
        XCTAssertEqual(FlightSuggestions.date(from: "MAD", to: "BRU", segments: segments), day(9))
        XCTAssertNil(FlightSuggestions.date(from: "LIS", to: "OPO", segments: segments))
    }

    // MARK: - Groups in the flights list

    private func codes(_ flights: [PlannedTrip.Flight]) -> [String] { flights.map { "\($0.from)-\($0.to)" } }

    func testOutAndHomeWithConnections() {
        // The screenshot: Paris → Lima via Montréal and back the same way.
        let flights = [leg("CDG", "YUL", 19), leg("YUL", "LIM", 19), leg("LIM", "YUL", 35), leg("YUL", "CDG", 35)]
        let groups = FlightSuggestions.grouped(flights, calendar: calendar)
        XCTAssertEqual(codes(groups.outbound), ["CDG-YUL", "YUL-LIM"])
        XCTAssertEqual(codes(groups.during), [])
        XCTAssertEqual(codes(groups.home), ["LIM-YUL", "YUL-CDG"])
    }

    func testFlightsDuringTheTripSitInBetween() {
        let flights = [leg("BRU", "LIM", 1), leg("LIM", "CUZ", 4), leg("CUZ", "LIM", 8), leg("LIM", "BRU", 12)]
        let groups = FlightSuggestions.grouped(flights, calendar: calendar)
        XCTAssertEqual(codes(groups.outbound), ["BRU-LIM"])
        XCTAssertEqual(codes(groups.during), ["LIM-CUZ", "CUZ-LIM"])
        XCTAssertEqual(codes(groups.home), ["LIM-BRU"])
    }

    func testNoHomeGroupWhenTheLastFlightDoesNotGoBack() {
        let flights = [leg("BRU", "NRT", 1), leg("NRT", "KIX", 8)]
        let groups = FlightSuggestions.grouped(flights, calendar: calendar)
        XCTAssertEqual(codes(groups.outbound), ["BRU-NRT"])
        XCTAssertEqual(codes(groups.during), ["NRT-KIX"])
        XCTAssertEqual(codes(groups.home), [])
    }

    func testHomeIntoAnotherAirportOfTheSameCountry() {
        let flights = [leg("BRU", "LIS", 1), leg("LIS", "CRL", 8)]
        let groups = FlightSuggestions.grouped(flights, calendar: calendar)
        XCTAssertEqual(codes(groups.outbound), ["BRU-LIS"])
        XCTAssertEqual(codes(groups.home), ["LIS-CRL"])
    }
}
