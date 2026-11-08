import XCTest
@testable import Photrail

/// The one free trip film: usable on any trip until claimed, then only on that trip.
final class FreeFilmAllowanceTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "FreeFilmAllowanceTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testAnyTripCanExportBeforeTheClaim() {
        XCTAssertTrue(FreeFilmAllowance.hasFreeFilmLeft(in: defaults))
        XCTAssertTrue(FreeFilmAllowance.canExport(tripID: "trip-2025-03-01", hasLifetime: false, in: defaults))
        XCTAssertEqual(FreeFilmAllowance.status(tripID: "trip-2025-03-01", hasLifetime: false, in: defaults), .freeLeft)
    }

    func testAfterTheClaimOnlyThatTripIsFree() {
        FreeFilmAllowance.claim(tripID: "trip-2025-03-01", in: defaults)

        XCTAssertFalse(FreeFilmAllowance.hasFreeFilmLeft(in: defaults))
        XCTAssertTrue(FreeFilmAllowance.canExport(tripID: "trip-2025-03-01", hasLifetime: false, in: defaults))
        XCTAssertFalse(FreeFilmAllowance.canExport(tripID: "trip-2025-07-10", hasLifetime: false, in: defaults))
        XCTAssertEqual(FreeFilmAllowance.status(tripID: "trip-2025-03-01", hasLifetime: false, in: defaults), .thisTripIsFree)
        XCTAssertEqual(FreeFilmAllowance.status(tripID: "trip-2025-07-10", hasLifetime: false, in: defaults), .locked)
    }

    func testASecondClaimDoesNotMoveTheFreeFilm() {
        FreeFilmAllowance.claim(tripID: "trip-2025-03-01", in: defaults)
        FreeFilmAllowance.claim(tripID: "trip-2025-07-10", in: defaults)
        XCTAssertEqual(FreeFilmAllowance.claimedTripID(in: defaults), "trip-2025-03-01")
    }

    func testLifetimeCanAlwaysExport() {
        FreeFilmAllowance.claim(tripID: "trip-2025-03-01", in: defaults)
        XCTAssertTrue(FreeFilmAllowance.canExport(tripID: "trip-2025-07-10", hasLifetime: true, in: defaults))
        XCTAssertEqual(FreeFilmAllowance.status(tripID: "trip-2025-07-10", hasLifetime: true, in: defaults), .unlimited)
    }
}
