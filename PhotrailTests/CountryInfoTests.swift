import XCTest
@testable import Photrail

/// The "Good to know" tips: the bundled country table and the advice held against home.
final class CountryInfoTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private let brussels = TimeZone(identifier: "Europe/Brussels")!

    private func tips(_ destination: String, home: String? = "BE", on day: Date? = nil) -> CountryTips? {
        CountryTips.make(destination: destination, home: home, on: day ?? date(2026, 7, 1), homeZone: brussels)
    }

    func testTableCoversEveryCountry() {
        let all = CountryInfoDirectory.all
        XCTAssertGreaterThanOrEqual(all.count, 190)
        for (code, info) in all {
            XCTAssertFalse(info.plugs.isEmpty, code)
            XCTAssertFalse(info.volts.isEmpty, code)
            XCTAssertFalse(info.languages.isEmpty, code)
            XCTAssertNotNil(info.currencyCode, code)
        }
    }

    func testPeru() throws {
        let peru = try XCTUnwrap(CountryInfoDirectory.info(for: "PE"))
        XCTAssertEqual(peru.plugs, ["A", "C"])
        XCTAssertEqual(peru.volts, [220])
        XCTAssertEqual(peru.languages.first, "es")
        XCTAssertEqual(peru.currencyCode, "PEN")
        XCTAssertFalse(peru.drivesOnLeft)
        XCTAssertEqual(peru.callingCodeText, "+51")
    }

    func testBelgiumToPeruNeedsAnAdapterForE() throws {
        let t = try XCTUnwrap(tips("PE"))
        XCTAssertEqual(t.plugAdvice, .partly(fitting: ["C"], needAdapter: ["E"]))
        XCTAssertEqual(t.socketsForHomePlugs, ["C"])   // the A socket gets no check
        XCTAssertEqual(t.homePlugs, ["C", "E"])
        XCTAssertTrue(t.homePlugFits("C"))
        XCTAssertFalse(t.homePlugFits("E"))
        XCTAssertEqual(t.voltageAdvice, .same)
        XCTAssertEqual(t.sameCurrency, false)
        XCTAssertEqual(t.sameDrivingSide, true)
        // July: Brussels UTC+2, Lima UTC−5.
        XCTAssertEqual(t.timeDifference, .hours(min: -7, max: -7))
    }

    func testTimeDifferenceFollowsSummerTime() throws {
        // January: Brussels UTC+1.
        XCTAssertEqual(try XCTUnwrap(tips("PE", on: date(2026, 1, 15))).timeDifference, .hours(min: -6, max: -6))
    }

    func testBelgiumToUSA() throws {
        let t = try XCTUnwrap(tips("US"))
        XCTAssertEqual(t.plugAdvice, .adapter)
        XCTAssertEqual(t.voltageAdvice, .lower)
        guard case let .hours(low, high)? = t.timeDifference else { return XCTFail() }
        XCTAssertLessThan(low, high)   // several zones: a range
    }

    func testBelgiumToNetherlands() throws {
        let t = try XCTUnwrap(tips("NL"))
        XCTAssertEqual(t.plugAdvice, .fits)
        XCTAssertEqual(t.sameCurrency, true)
        XCTAssertEqual(t.sameDrivingSide, true)
        XCTAssertEqual(t.timeDifference, .same)
    }

    func testBelgiumToUK() throws {
        let t = try XCTUnwrap(tips("GB"))
        XCTAssertEqual(t.plugAdvice, .adapter)
        XCTAssertEqual(t.sameDrivingSide, false)
        XCTAssertEqual(t.timeDifference, .hours(min: -1, max: -1))
    }

    func testUSAToEuropeWarnsAboutHigherVoltage() throws {
        let t = try XCTUnwrap(tips("FR", home: "US"))
        XCTAssertEqual(t.voltageAdvice, .higher)
        XCTAssertEqual(t.plugAdvice, .adapter)
    }

    func testWithoutHomeOnlyFacts() throws {
        let t = try XCTUnwrap(tips("PE", home: nil))
        XCTAssertNil(t.plugAdvice)
        XCTAssertNil(t.sameCurrency)
        XCTAssertNil(t.sameDrivingSide)
        XCTAssertEqual(t.voltageAdvice, .same)
    }
}
