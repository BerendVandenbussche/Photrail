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
                                               photos: lisbonTrip, calendar: calendar,
                                               planCalendar: calendar)
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

    // MARK: - Time zones

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    func testTripTimeZoneIsTheNearestZoneOfTheCountry() {
        XCTAssertEqual(TripTimeZone.zone(countryCode: "BR", latitude: -22.95, longitude: -43.21)?.identifier,
                       "America/Sao_Paulo")                                  // Rio
        XCTAssertEqual(TripTimeZone.zone(countryCode: "US", latitude: 37.77, longitude: -122.42)?.identifier,
                       "America/Los_Angeles")                                // San Francisco
        XCTAssertEqual(TripTimeZone.zone(countryCode: "PT", latitude: 38.72, longitude: -9.14)?.identifier,
                       "Europe/Lisbon")
        XCTAssertEqual(TripTimeZone.zone(countryCode: "be", latitude: 50.85, longitude: 4.35)?.identifier,
                       "Europe/Brussels")
        XCTAssertNil(TripTimeZone.zone(countryCode: "ZZ", latitude: 0, longitude: 0))
    }

    /// Evening photos in Rio stay on their day, also when the postcard is opened in Belgium.
    func testEveningPhotosFarAwayStayOnTheirDay() {
        let rio = calendar("America/Sao_Paulo")
        func at(_ day: Int, _ hour: Int) -> Date {
            rio.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour))!
        }
        let photos = [
            GeoPhoto(id: "morning", coordinate: .init(latitude: -22.95, longitude: -43.21),
                     date: at(1, 10), countryCode: "BR", city: "Rio de Janeiro", isGeocoded: true),
            // 22:00 in Rio is 03:00 the next morning in Brussels.
            GeoPhoto(id: "evening", coordinate: .init(latitude: -22.97, longitude: -43.18),
                     date: at(1, 22), countryCode: "BR", city: "Rio de Janeiro", isGeocoded: true),
        ]
        let postcard = DayPostcardBuilder.make(day: at(1, 12), tripStart: at(1, 10), plan: nil,
                                               photos: photos, calendar: rio,
                                               planCalendar: calendar("Europe/Brussels"))
        XCTAssertEqual(postcard?.photoIDs, ["morning", "evening"])
        XCTAssertEqual(postcard?.timeZoneIdentifier, "America/Sao_Paulo")
        // A Brussels calendar would have split them over two days.
        XCTAssertFalse(calendar("Europe/Brussels").isDate(at(1, 10), inSameDayAs: at(1, 22)))
    }

    /// A plan entered in Belgium for a trip to Tokyo: day numbers follow the calendar dates.
    func testPlanDayNumberAcrossTimeZones() {
        let brussels = calendar("Europe/Brussels"), tokyo = calendar("Asia/Tokyo")
        let plan = PlannedTrip(name: nil, countryCode: "JP",
                               startDate: brussels.date(from: DateComponents(year: 2026, month: 4, day: 1))!,
                               endDate: brussels.date(from: DateComponents(year: 2026, month: 4, day: 7))!,
                               calendar: brussels)
        func at(_ day: Int, _ hour: Int) -> Date {
            tokyo.date(from: DateComponents(year: 2026, month: 4, day: day, hour: hour))!
        }
        let photos = (1...3).map {
            GeoPhoto(id: "d\($0)", coordinate: .init(latitude: 35.68, longitude: 139.76),
                     date: at($0, 20), countryCode: "JP", city: "Tokyo", isGeocoded: true)
        }
        for day in 1...3 {
            let postcard = DayPostcardBuilder.make(day: at(day, 12), tripStart: at(1, 20), plan: plan,
                                                   photos: photos, calendar: tokyo, planCalendar: brussels)
            XCTAssertEqual(postcard?.dayNumber, day, "Tokyo, \(day) April")
            XCTAssertEqual(postcard?.totalDays, 7)
        }
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
