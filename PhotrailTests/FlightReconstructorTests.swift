import XCTest
import CoreLocation
@testable import Photrail

/// Flight hints for past trips: photos at airports (and from the plane) become a route, with
/// the home airport and the airport nearest the first and last stop filling the gaps.
final class FlightReconstructorTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()

    private let bruges = CLLocationCoordinate2D(latitude: 51.209, longitude: 3.2247)
    private let lima = (lat: -12.046, lon: -77.043)
    private let amsterdam = (lat: 52.373, lon: 4.893)
    private let bru = (lat: 50.9014, lon: 4.4844)
    private let fra = (lat: 50.0267, lon: 8.5584)
    private let lim = (lat: -12.0219, lon: -77.1143)

    private func time(_ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: d, hour: h))!
    }

    private func photo(_ place: (lat: Double, lon: Double), _ date: Date, altitude: Double? = nil) -> GeoPhoto {
        GeoPhoto(id: UUID().uuidString, coordinate: .init(latitude: place.lat, longitude: place.lon),
                 date: date, altitude: altitude)
    }

    private func trip(at place: (lat: Double, lon: Double), from start: Int, to end: Int, code: String) -> Trip {
        Trip(id: "t", countryCode: code, country: code, flag: "🏳️",
             countries: [.init(id: code, name: code, flag: "🏳️", photoCount: 1)],
             startDate: time(start, 22), endDate: time(end, 10), photoCount: 1, cities: [],
             stops: [.init(id: "c,\(code)", name: "City", countryCode: code, flag: "🏳️",
                           latitude: place.lat, longitude: place.lon, firstVisit: time(start, 22), photoCount: 1)],
             photoIDs: ["x"], coordinate: .init(latitude: place.lat, longitude: place.lon),
             highestAltitude: nil, wonders: [])
    }

    private func hint(_ trip: Trip, _ photos: [GeoPhoto], homeAirports: [String] = ["BRU"],
                      requireEvidence: Bool = true) -> FlightHint? {
        FlightReconstructor.make(trip: trip, photos: photos, homeAirports: homeAirports,
                                 home: bruges, homeCountryCode: "BE", requireEvidence: requireEvidence,
                                 calendar: calendar)
    }

    private func route(_ hint: FlightHint?) -> [String]? {
        hint.map { $0.flights.map { "\($0.from)-\($0.to)" } }
    }

    func testAirportPhotosBecomeTheRouteWithTheLandingInferred() {
        let photos = [
            photo(bru, time(1, 8)), photo(fra, time(1, 11)), photo(lima, time(1, 22)), photo(lima, time(5)),
            photo(lim, time(10, 20)), photo(fra, time(11, 13)), photo(bru, time(11, 16)),
        ]
        let result = hint(trip(at: lima, from: 1, to: 10, code: "PE"), photos)
        XCTAssertEqual(route(result), ["BRU-FRA", "FRA-LIM", "LIM-FRA", "FRA-BRU"])
        XCTAssertEqual(result?.legs.map(\.toSeen), [true, false, true, true])
        XCTAssertEqual(result?.routeText, "BRU → FRA → LIM? → FRA → BRU")
        XCTAssertEqual(result?.flights.first?.date, calendar.startOfDay(for: time(1)))
        XCTAssertEqual(result?.homeIsGuess, false)
    }

    func testNoAirportPhotoGivesNoHintEvenWithAPlanePhoto() {
        let photos = [photo((30, -40), time(1, 15), altitude: 10_500), photo(lima, time(1, 22)), photo(lima, time(5))]
        XCTAssertNil(hint(trip(at: lima, from: 1, to: 10, code: "PE"), photos))
    }

    func testPrefillGuessesBothWaysFromTheUsualAirportWithoutEvidence() {
        let photos = [photo(lima, time(1, 22))]
        let result = hint(trip(at: lima, from: 1, to: 10, code: "PE"), photos, requireEvidence: false)
        XCTAssertEqual(route(result), ["BRU-LIM", "LIM-BRU"])
        XCTAssertEqual(result?.legs.map(\.fromSeen), [false, false])
        XCTAssertEqual(result?.legs.map(\.toSeen), [false, false])
        // The way home is dated on the trip's last day.
        XCTAssertEqual(result?.flights.last?.date, calendar.startOfDay(for: time(10)))
        XCTAssertEqual(result?.routeText, "BRU? → LIM? → BRU?")
    }

    func testWithoutHistoryTheNearestHomeAirportIsAGuessThatCanBeReplaced() {
        let photos = [photo(lima, time(1, 22))]
        let result = hint(trip(at: lima, from: 1, to: 10, code: "PE"), photos, homeAirports: [],
                          requireEvidence: false)
        XCTAssertEqual(result?.homeIsGuess, true)
        XCTAssertEqual(result?.homeAirport, "OST")
        XCTAssertEqual(route(result?.replacingHomeAirport(with: "BRU")), ["BRU-LIM", "LIM-BRU"])
    }

    func testTripCloseToHomeWithOnlyAHomeAirportPhotoGivesNoHint() {
        // Dropping someone off at BRU, then a weekend in Amsterdam by car.
        let photos = [photo(bru, time(1, 7)), photo(amsterdam, time(1, 22))]
        XCTAssertNil(hint(trip(at: amsterdam, from: 1, to: 3, code: "NL"), photos))
    }

    // MARK: Same way back

    private let crl = (lat: 50.4592, lon: 4.4538)
    private let buenosAires = (lat: -34.6037, lon: -58.3816)

    func testOneCountryTripFliesBackTheWayItCame() {
        // Photos at BRU and the FRA layover on the way out, none on the way home.
        let photos = [photo(bru, time(1, 8)), photo(fra, time(1, 11)), photo(lima, time(1, 22)), photo(lima, time(5))]
        let result = hint(trip(at: lima, from: 1, to: 10, code: "PE"), photos)
        XCTAssertEqual(route(result), ["BRU-FRA", "FRA-LIM", "LIM-FRA", "FRA-BRU"])
        XCTAssertEqual(result?.legs.suffix(2).map(\.fromSeen), [false, false])
        XCTAssertEqual(result?.legs.suffix(2).map(\.toSeen), [false, false])
        XCTAssertEqual(result?.flights.last?.date, calendar.startOfDay(for: time(10)))
    }

    func testSameWayBackEndsAtTheHomeAirportAPhotoShows() {
        let photos = [photo(bru, time(1, 8)), photo(fra, time(1, 11)), photo(lima, time(1, 22)),
                      photo(crl, time(11, 9))]
        let result = hint(trip(at: lima, from: 1, to: 10, code: "PE"), photos)
        XCTAssertEqual(route(result), ["BRU-FRA", "FRA-LIM", "LIM-FRA", "FRA-CRL"])
        XCTAssertEqual(result?.legs.last?.toSeen, true)
    }

    func testTripThatEndsElsewhereDoesntFlyBackTheSameWay() {
        // Landed in Lima, ended in Buenos Aires: home from there, not via Lima and Frankfurt.
        let photos = [photo(bru, time(1, 8)), photo(fra, time(1, 11)), photo(lima, time(1, 22)),
                      photo(buenosAires, time(9))]
        let start = time(1, 22), end = time(10, 10)
        let trip = Trip(id: "t", countryCode: "PE", country: "PE", flag: "🏳️",
                        countries: [.init(id: "PE", name: "PE", flag: "🏳️", photoCount: 1),
                                    .init(id: "AR", name: "AR", flag: "🏳️", photoCount: 1)],
                        startDate: start, endDate: end, photoCount: 2, cities: [],
                        stops: [.init(id: "lima,PE", name: "Lima", countryCode: "PE", flag: "🏳️",
                                      latitude: lima.lat, longitude: lima.lon, firstVisit: start, photoCount: 1),
                                .init(id: "ba,AR", name: "Buenos Aires", countryCode: "AR", flag: "🏳️",
                                      latitude: buenosAires.lat, longitude: buenosAires.lon,
                                      firstVisit: time(9), photoCount: 1)],
                        photoIDs: ["x", "y"], coordinate: .init(latitude: lima.lat, longitude: lima.lon),
                        highestAltitude: nil, wonders: [])
        let result = hint(trip, photos)
        XCTAssertEqual(route(result).map { Array($0.prefix(2)) }, ["BRU-FRA", "FRA-LIM"])
        XCTAssertEqual(result?.flights.count, 3)
        XCTAssertNotEqual(result?.flights.last?.from, "LIM")
        XCTAssertEqual(result?.flights.last?.to, "BRU")
    }

    func testManyPhotosOnALayoverAreOneVisit() {
        let photos = (0..<30).map { photo(fra, time(1, 8).addingTimeInterval(Double($0) * 300)) }
        XCTAssertEqual(FlightReconstructor.visits(in: photos).map(\.iata), ["FRA"])
    }
}
