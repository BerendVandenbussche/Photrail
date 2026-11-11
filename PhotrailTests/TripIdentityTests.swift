import XCTest
@testable import Photrail

/// A trip's id is its first day, so it moves when that day does. The user's names, notes,
/// flights and so on must follow the trip, and never be overwritten or thrown away.
final class TripIdentityTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "TripIdentityTests"

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func date(_ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: m, day: d, hour: hour))!
    }

    private func span(_ id: String, _ start: Date, _ end: Date) -> TripIdentity.Span {
        TripIdentity.Span(id: id, start: start, end: end)
    }

    // MARK: Matching

    func testEarlierStartMovesToTheNewID() {
        let old = [span("trip-2025-07-03", date(7, 3), date(7, 12))]
        let new = [span("trip-2025-07-01", date(7, 1), date(7, 12))]
        XCTAssertEqual(TripIdentity.matches(old: old, new: new, calendar: calendar),
                       ["trip-2025-07-03": "trip-2025-07-01"])
    }

    func testUnchangedIDsAndManualTripsDontMove() {
        let old = [span("trip-2025-07-03", date(7, 3), date(7, 12)),
                   span("manual:abc", date(8, 1), date(8, 5))]
        let new = [span("trip-2025-07-03", date(7, 3), date(7, 14)),
                   span("trip-2025-08-01", date(8, 1), date(8, 5))]
        XCTAssertEqual(TripIdentity.matches(old: old, new: new, calendar: calendar), [:])
    }

    func testTripThatIsGoneWithoutOverlapKeepsItsData() {
        let old = [span("trip-2025-03-01", date(3, 1), date(3, 4))]
        let new = [span("trip-2025-07-01", date(7, 1), date(7, 12))]
        XCTAssertEqual(TripIdentity.matches(old: old, new: new, calendar: calendar), [:])
    }

    func testMostSharedDaysWins() {
        // The old trip was split: its id is gone, and most of it is in the second part.
        let old = [span("trip-2025-07-01#2", date(7, 1, hour: 20), date(7, 12))]
        let new = [span("trip-2025-07-01", date(7, 1, hour: 8), date(7, 2)),
                   span("trip-2025-07-04", date(7, 4), date(7, 12))]
        XCTAssertEqual(TripIdentity.matches(old: old, new: new, calendar: calendar),
                       ["trip-2025-07-01#2": "trip-2025-07-04"])
    }

    func testOneDayTripsOnTheSameDayOverlap() {
        let old = [span("trip-2025-07-05", date(7, 5, hour: 9), date(7, 5, hour: 18))]
        let new = [span("trip-2025-07-04", date(7, 4, hour: 22), date(7, 5, hour: 18))]
        XCTAssertEqual(TripIdentity.matches(old: old, new: new, calendar: calendar),
                       ["trip-2025-07-05": "trip-2025-07-04"])
    }

    // MARK: Moving the data

    func testEveryKindOfDataMoves() throws {
        defaults.set(["trip-a": "Summer in Rome"], forKey: TripNameStore.key)
        defaults.set(["trip-a": "Great pasta"], forKey: TripNoteStore.key)
        defaults.set(["trip-a": "photo-1"], forKey: TripCoverStore.key)
        let flight = PlannedTrip.Flight(from: "BRU", to: "FCO", date: date(7, 1))
        defaults.set(try JSONEncoder().encode(["trip-a": [flight]]), forKey: TripFlightStore.key)
        defaults.set(["trip-x", "trip-a"], forKey: TripFlightHintStore.key)
        defaults.set(["trip-a"], forKey: TripUserData.notifiedTripsKey)
        defaults.set("trip-a", forKey: FreeFilmAllowance.key)

        TripUserData.move(from: "trip-a", to: "trip-b", in: defaults)

        XCTAssertEqual(defaults.dictionary(forKey: TripNameStore.key) as? [String: String], ["trip-b": "Summer in Rome"])
        XCTAssertEqual(defaults.dictionary(forKey: TripNoteStore.key) as? [String: String], ["trip-b": "Great pasta"])
        XCTAssertEqual(defaults.dictionary(forKey: TripCoverStore.key) as? [String: String], ["trip-b": "photo-1"])
        let flights = try JSONDecoder().decode([String: [PlannedTrip.Flight]].self,
                                               from: XCTUnwrap(defaults.data(forKey: TripFlightStore.key)))
        XCTAssertEqual(flights, ["trip-b": [flight]])
        XCTAssertEqual(defaults.stringArray(forKey: TripFlightHintStore.key), ["trip-x", "trip-b"])
        XCTAssertEqual(defaults.stringArray(forKey: TripUserData.notifiedTripsKey), ["trip-b"])
        XCTAssertEqual(defaults.string(forKey: FreeFilmAllowance.key), "trip-b")
        XCTAssertFalse(TripUserData.hasData(for: "trip-a", in: defaults))
    }

    func testNeverOverwritesTheTargetsOwnData() {
        defaults.set(["trip-a": "Old name", "trip-b": "Own name"], forKey: TripNameStore.key)
        defaults.set(["trip-a": "Only a note here"], forKey: TripNoteStore.key)

        TripUserData.move(from: "trip-a", to: "trip-b", in: defaults)

        // The name can't move, so it stays where it was; the note moves.
        XCTAssertEqual(defaults.dictionary(forKey: TripNameStore.key) as? [String: String],
                       ["trip-a": "Old name", "trip-b": "Own name"])
        XCTAssertEqual(defaults.dictionary(forKey: TripNoteStore.key) as? [String: String],
                       ["trip-b": "Only a note here"])
    }

    // MARK: Relinking after a scan

    func testRelinkMovesDataAndRemembersTheNewTrips() {
        TripIdentity.save([span("trip-2025-07-03", date(7, 3), date(7, 12))], to: defaults)
        defaults.set(["trip-2025-07-03": "Rome"], forKey: TripNameStore.key)

        let moved = TripIdentity.relink([trip("trip-2025-07-01", date(7, 1), date(7, 12))],
                                        in: defaults, calendar: calendar)

        XCTAssertTrue(moved)
        XCTAssertEqual(defaults.dictionary(forKey: TripNameStore.key) as? [String: String], ["trip-2025-07-01": "Rome"])
        XCTAssertEqual(TripIdentity.load(from: defaults).map(\.id), ["trip-2025-07-01"])
    }

    func testRelinkIgnoresAnEmptyList() {
        // A reindex wipes the photo cache first: forgetting the trips then would lose the match.
        let remembered = [span("trip-2025-07-03", date(7, 3), date(7, 12))]
        TripIdentity.save(remembered, to: defaults)
        XCTAssertFalse(TripIdentity.relink([], in: defaults, calendar: calendar))
        XCTAssertEqual(TripIdentity.load(from: defaults), remembered)
    }

    func testTripThatComesBackGetsItsDataBack() {
        defaults.set(["trip-2025-07-03": "Rome"], forKey: TripNameStore.key)
        TripIdentity.save([span("trip-2025-07-03", date(7, 3), date(7, 12))], to: defaults)
        // An older photo moves the start, then gets excluded again.
        TripIdentity.relink([trip("trip-2025-07-01", date(7, 1), date(7, 12))], in: defaults, calendar: calendar)
        TripIdentity.relink([trip("trip-2025-07-03", date(7, 3), date(7, 12))], in: defaults, calendar: calendar)
        XCTAssertEqual(defaults.dictionary(forKey: TripNameStore.key) as? [String: String], ["trip-2025-07-03": "Rome"])
    }

    private func trip(_ id: String, _ start: Date, _ end: Date) -> Trip {
        Trip(id: id, countryCode: "IT", country: "Italy", flag: "🇮🇹", countries: [],
             startDate: start, endDate: end, photoCount: 10, cities: [], stops: [], photoIDs: [],
             coordinate: GeoPhoto.Coordinate(latitude: 41.9, longitude: 12.5),
             highestAltitude: nil, wonders: [])
    }
}
