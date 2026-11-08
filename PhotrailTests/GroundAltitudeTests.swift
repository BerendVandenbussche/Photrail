import XCTest
@testable import Photrail

/// Photos taken from a plane carry cruising altitude; "highest point" records must skip them.
final class GroundAltitudeTests: XCTestCase {

    private func photo(altitude: Double?) -> GeoPhoto {
        GeoPhoto(id: UUID().uuidString,
                 coordinate: .init(latitude: 46.0, longitude: 7.7),
                 date: Date(), altitude: altitude)
    }

    func testMountainAltitudeIsKept() {
        XCTAssertEqual(photo(altitude: 3_883).groundAltitude, 3_883)          // Klein Matterhorn
        XCTAssertEqual(photo(altitude: GeoPhoto.maxGroundAltitude).groundAltitude,
                       GeoPhoto.maxGroundAltitude)
    }

    func testCruisingAltitudeIsDropped() {
        XCTAssertNil(photo(altitude: 11_000).groundAltitude)
        XCTAssertNil(photo(altitude: GeoPhoto.maxGroundAltitude + 1).groundAltitude)
    }

    func testNoAltitudeStaysNil() {
        XCTAssertNil(photo(altitude: nil).groundAltitude)
    }
}
