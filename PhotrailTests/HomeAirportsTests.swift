import XCTest
import CoreLocation
@testable import Photrail

/// Learning which airports you fly from: photo days at airports near home, and the flights
/// you entered, weigh more than being the nearest.
final class HomeAirportsTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()

    private let bruges = CLLocationCoordinate2D(latitude: 51.209, longitude: 3.2247)
    private let bru = (lat: 50.9014, lon: 4.4844)
    private let crl = (lat: 50.4620, lon: 4.4596)
    private let fra = (lat: 50.0267, lon: 8.5584)

    /// Two photos on each of `days` days at `place`.
    private func photos(at place: (lat: Double, lon: Double), days: Int, month: Int) -> [GeoPhoto] {
        (1...days).flatMap { day in
            [8, 9].map { hour in
                GeoPhoto(id: UUID().uuidString, coordinate: .init(latitude: place.lat, longitude: place.lon),
                         date: calendar.date(from: DateComponents(year: 2025, month: month, day: day, hour: hour))!,
                         countryCode: "BE")
            }
        }
    }

    private func rank(_ photos: [GeoPhoto], _ flights: [PlannedTrip.Flight] = []) -> [String] {
        HomeAirports.rank(photos: photos, flights: flights, home: bruges, homeCountryCode: "BE", calendar: calendar)
    }

    func testMostPhotographedDaysWinOverTheNearest() {
        let ranking = rank(photos(at: bru, days: 5, month: 1) + photos(at: crl, days: 2, month: 2))
        XCTAssertEqual(ranking, ["BRU", "CRL"])
        XCTAssertFalse(ranking.contains("OST"))
    }

    func testEnteredFlightsWeighMore() {
        let flights = [PlannedTrip.Flight(from: "CRL", to: "FCO"), PlannedTrip.Flight(from: "FCO", to: "CRL")]
        let ranking = rank(photos(at: bru, days: 3, month: 1) + photos(at: crl, days: 1, month: 2), flights)
        XCTAssertEqual(ranking.first, "CRL")
    }

    func testAirportsAbroadDontCount() {
        let abroad = photos(at: fra, days: 4, month: 3).map {
            GeoPhoto(id: $0.id, coordinate: $0.coordinate, date: $0.date, countryCode: "DE")
        }
        XCTAssertEqual(rank(abroad), [])
    }

    func testNoHistoryLeavesTheChoiceToTheNearest() {
        XCTAssertEqual(rank([]), [])
        // Belgian airports first, so Brussels and Charleroi are among them; Lille after.
        let candidates = HomeAirports.candidates(home: bruges, homeCountryCode: "BE")
        XCTAssertEqual(candidates.map(\.iata), ["OST", "BRU", "CRL", "LIL"])
    }
}
