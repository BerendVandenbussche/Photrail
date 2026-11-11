import XCTest
@testable import Photrail

/// Spotlight keywords for dates: "2015", "trips 2015" and "July 2025" must find the right trips.
final class TripSearchKeywordsTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testYearMonthsAndTripWordsInBothLanguages() {
        let words = TripSearchIndexer.dateKeywords(start: date(2025, 7, 20), end: date(2025, 8, 3),
                                                   calendar: calendar, locale: Locale(identifier: "nl_BE"))
        for expected in ["2025", "trip", "reis", "July", "August", "juli", "augustus", "July 2025", "augustus 2025"] {
            XCTAssertTrue(words.contains(expected), "missing \(expected)")
        }
        XCTAssertFalse(words.contains("2024"))
        XCTAssertFalse(words.contains("September"))
    }

    func testTripOverNewYearHasBothYears() {
        let words = TripSearchIndexer.dateKeywords(start: date(2014, 12, 28), end: date(2015, 1, 4),
                                                   calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(words.contains("2014"))
        XCTAssertTrue(words.contains("2015"))
        XCTAssertTrue(words.contains("December 2014"))
        XCTAssertTrue(words.contains("January 2015"))
    }
}
