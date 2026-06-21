import XCTest
@testable import Photrail

final class TravelPersonalityEngineTests: XCTestCase {

    private let engine = TravelPersonalityEngine()

    private func photo(_ id: String,
                       lat: Double, lon: Double,
                       city: String? = nil,
                       date: Date = Date(timeIntervalSince1970: 1_000)) -> GeoPhoto {
        GeoPhoto(id: id,
                 coordinate: .init(latitude: lat, longitude: lon),
                 date: date,
                 country: "Testland",
                 countryCode: "XX",
                 city: city,
                 isGeocoded: true)
    }

    func testEmptyInputProducesEmptyProfile() {
        let profile = engine.makeProfile(photos: [])
        XCTAssertEqual(profile, .empty)
        XCTAssertNil(profile.dominantCategory)
    }

    func testCityPhotosAreUrbanDominant() {
        let photos = (0..<5).map { photo("\($0)", lat: 48.85, lon: 2.35, city: "Paris") }
        let profile = engine.makeProfile(photos: photos)
        XCTAssertEqual(profile.dominantCategory, .urban)
    }

    func testRuralPhotosAreNatureDominant() {
        // No city → nature lean, all at the same remote spot (no movement)
        let photos = (0..<5).map { photo("\($0)", lat: 60.0, lon: 10.0) }
        let profile = engine.makeProfile(photos: photos)
        XCTAssertEqual(profile.dominantCategory, .nature)
    }

    func testWonderProximityAddsCulture() {
        let p = photo("w1", lat: 41.8902, lon: 12.4922) // Colosseum, no city
        let profile = engine.makeProfile(photos: [p], wonderIDByPhoto: ["w1": "colosseum"])
        XCTAssertEqual(profile.dominantCategory, .culture)
        XCTAssertGreaterThan(profile.categoryPercentages[.culture] ?? 0, 0)
    }

    func testLongMovementSameDayAddsTransit() {
        let paris = photo("a", lat: 48.85, lon: 2.35, date: Date(timeIntervalSince1970: 0))
        let nyc = photo("b", lat: 40.71, lon: -74.0, date: Date(timeIntervalSince1970: 3_600))
        let profile = engine.makeProfile(photos: [paris, nyc])
        XCTAssertGreaterThan(profile.categoryPercentages[.transit] ?? 0, 0)
    }

    func testPercentagesSumToHundred() {
        let photos = [
            photo("1", lat: 48.85, lon: 2.35, city: "Paris"),
            photo("2", lat: 60.0, lon: 10.0),
            photo("3", lat: 41.8902, lon: 12.4922)
        ]
        let profile = engine.makeProfile(photos: photos, wonderIDByPhoto: ["3": "colosseum"])
        let sum = profile.slices.reduce(0) { $0 + $1.percentage }
        XCTAssertEqual(sum, 100, accuracy: 0.01)
    }

    func testSinglePhotoScoreIsUrbanWhenCityPresent() {
        let scores = engine.score(photo: photo("x", lat: 1, lon: 1, city: "Tokyo"),
                                  previous: nil, next: nil, wonderKind: nil)
        XCTAssertGreaterThan(scores[.urban], 0)
        XCTAssertEqual(scores[.nature], 0)
    }

    func testPhotosNearHomeAreExcluded() {
        // Many urban photos at home + one rural photo far away.
        var photos = (0..<10).map { photo("h\($0)", lat: 48.85, lon: 2.35, city: "Paris") }
        photos.append(photo("away", lat: 60.0, lon: 10.0)) // ~1300km away, no city
        let home = GeoPhoto.Coordinate(latitude: 48.85, longitude: 2.35)

        let withoutFilter = engine.makeProfile(photos: photos)
        XCTAssertEqual(withoutFilter.dominantCategory, .urban)   // home dominates

        let withFilter = engine.makeProfile(photos: photos, home: home)
        XCTAssertEqual(withFilter.dominantCategory, .nature)     // only the trip counts
        XCTAssertEqual(withFilter.photoCount, 1)
    }

    func testHomeFilterFallsBackWhenAllNearHome() {
        let photos = (0..<5).map { photo("\($0)", lat: 48.85, lon: 2.35, city: "Paris") }
        let home = GeoPhoto.Coordinate(latitude: 48.85, longitude: 2.35)
        let profile = engine.makeProfile(photos: photos, home: home)
        // Everything is near home → fall back to using all photos rather than empty.
        XCTAssertEqual(profile.photoCount, 5)
        XCTAssertEqual(profile.dominantCategory, .urban)
    }

    func testConfidenceGrowsWithSampleSize() {
        let few = engine.makeProfile(photos: (0..<10).map { photo("\($0)", lat: 1, lon: Double($0)) })
        let many = engine.makeProfile(photos: (0..<300).map { photo("\($0)", lat: 1, lon: Double($0)) })
        XCTAssertLessThan(few.confidence, many.confidence)
        XCTAssertEqual(many.confidence, 1, accuracy: 0.0001)
    }
}
