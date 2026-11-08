import XCTest
@testable import Photrail

/// The daily postcard: one calendar day of a trip, and when its notification may go out.
final class DayPostcardBuilderTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
    }

    private func photo(_ id: String, day: Int, hour: Int, minute: Int = 0,
                       lat: Double, lon: Double, city: String?, country: String = "PT") -> GeoPhoto {
        GeoPhoto(id: id, coordinate: .init(latitude: lat, longitude: lon), date: date(day, hour, minute),
                 country: "Portugal", countryCode: country, city: city, isGeocoded: true)
    }

    private var lisbonTrip: [GeoPhoto] {
        [
            photo("d1", day: 10, hour: 12, lat: 38.7077, lon: -9.1365, city: "Lisbon"),
            // Day 12: Belém in the morning, the city centre later, two photos of one square.
            photo("a", day: 12, hour: 9, lat: 38.6916, lon: -9.2160, city: "Belém"),
            photo("b", day: 12, hour: 14, lat: 38.7077, lon: -9.1365, city: "Lisbon"),
            photo("c", day: 12, hour: 14, minute: 5, lat: 38.7078, lon: -9.1366, city: "Lisbon"),
            photo("d", day: 12, hour: 18, lat: 38.7110, lon: -9.1290, city: "Lisbon"),
            photo("e", day: 13, hour: 10, lat: 38.7980, lon: -9.3880, city: "Sintra"),
        ]
    }

    func testOnlyThatDaysPhotosInTimeOrder() {
        let postcard = DayPostcardBuilder.make(day: date(12, 20), tripStart: date(10, 12), plan: nil,
                                               photos: Array(lisbonTrip.reversed()), calendar: calendar)
        XCTAssertEqual(postcard?.photoIDs, ["a", "b", "c", "d"])
        XCTAssertEqual(postcard?.day, calendar.startOfDay(for: date(12, 0)))
    }

    func testDayNumberWithoutPlanCountsFromTripStart() {
        let postcard = DayPostcardBuilder.make(day: date(12, 9), tripStart: date(10, 12), plan: nil,
                                               photos: lisbonTrip, calendar: calendar)
        XCTAssertEqual(postcard?.dayNumber, 3)
        XCTAssertNil(postcard?.totalDays)
    }

    func testDayNumberAndLengthFromPlan() {
        let plan = PlannedTrip(name: nil, countryCode: "PT", startDate: date(11, 0), endDate: date(18, 0),
                               calendar: calendar)
        let postcard = DayPostcardBuilder.make(day: date(12, 9), tripStart: date(10, 12), plan: plan,
                                               photos: lisbonTrip, calendar: calendar)
        XCTAssertEqual(postcard?.dayNumber, 2)
        XCTAssertEqual(postcard?.totalDays, 8)
    }

    func testCitiesInOrderOnce() {
        let postcard = DayPostcardBuilder.make(day: date(12, 9), tripStart: date(10, 12), plan: nil,
                                               photos: lisbonTrip, calendar: calendar)
        XCTAssertEqual(postcard?.cities, ["Belém", "Lisbon"])
        XCTAssertEqual(postcard?.countryCode, "PT")
        XCTAssertEqual(postcard?.countryName, "Portugal")
    }

    func testPhotosCloseTogetherAreOneRoutePoint() {
        let postcard = DayPostcardBuilder.make(day: date(12, 9), tripStart: date(10, 12), plan: nil,
                                               photos: lisbonTrip, calendar: calendar)
        // a, b, d — c is a few metres from b.
        XCTAssertEqual(postcard?.route.count, 3)
        XCTAssertEqual(postcard?.distanceKm ?? 0, 7.8, accuracy: 1.0)
    }

    func testDayWithoutPhotosIsNil() {
        XCTAssertNil(DayPostcardBuilder.make(day: date(11, 9), tripStart: date(10, 12), plan: nil,
                                             photos: lisbonTrip, calendar: calendar))
    }

    // MARK: - Notification timing

    func testTimingBeforeEightIsEightTonight() {
        XCTAssertEqual(NotificationService.postcardTiming(now: date(12, 15), calendar: calendar),
                       .at(date(12, 20)))
    }

    func testTimingInTheEveningIsNow() {
        XCTAssertEqual(NotificationService.postcardTiming(now: date(12, 21, 30), calendar: calendar), .now)
    }

    func testTimingLateAtNightIsSkipped() {
        XCTAssertEqual(NotificationService.postcardTiming(now: date(12, 22, 15), calendar: calendar), .skip)
    }

    func testPostcardRouteRoundTrip() {
        let day = date(12, 0)
        guard case .postcard(let parsed)? = NotificationRoute(userInfo: NotificationRoute.postcard(day: day).userInfo)
        else { return XCTFail("postcard route didn't survive userInfo") }
        XCTAssertEqual(parsed, day)
    }
}
