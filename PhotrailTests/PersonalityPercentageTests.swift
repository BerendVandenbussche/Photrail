import XCTest
@testable import Photrail

/// Verifies the travel-personality percentages always add up to exactly 100 %,
/// with no rounding drift (the "it only summed to 93 %" bug).
final class PersonalityPercentageTests: XCTestCase {

    private let aggregator = TravelPersonalityAggregator()
    private let engine = TravelPersonalityEngine()

    private func scores(_ dict: [TravelCategory: Double]) -> TravelCategoryScores {
        TravelCategoryScores(dict)
    }

    private func sum(_ result: [TravelCategory: Int]) -> Int {
        result.values.reduce(0, +)
    }

    // MARK: - The rounding helper

    func testEvenSevenWaySplitSumsTo100() {
        // 100 / 7 = 14.285… → naive rounding gives 7×14 = 98. Largest-remainder must fix it.
        let even = scores(Dictionary(uniqueKeysWithValues: TravelCategory.allCases.map { ($0, 1.0) }))
        let result = TravelPersonalityAggregator.percentagesSummingTo100(even)
        XCTAssertEqual(sum(result), 100)
        for value in result.values { XCTAssert(value == 14 || value == 15) }
    }

    func testAssortedVectorsSumTo100() {
        let cases: [[TravelCategory: Double]] = [
            [.urban: 1, .nature: 1, .coastal: 1],                  // 33.33 ×3
            [.urban: 5, .culture: 3, .mountain: 1, .transit: 1],
            [.mountain: 0.4, .nature: 0.3, .adventure: 0.3],       // sub-1 fractions
            [.urban: 999, .nature: 1],                              // very skewed
            [.coastal: 2, .nature: 2, .culture: 2, .transit: 2, .adventure: 1, .urban: 1, .mountain: 1],
        ]
        for dict in cases {
            let result = TravelPersonalityAggregator.percentagesSummingTo100(scores(dict))
            XCTAssertEqual(sum(result), 100, "Failed for \(dict)")
        }
    }

    func testEmptyScoresAreAllZero() {
        let result = TravelPersonalityAggregator.percentagesSummingTo100(scores([:]))
        XCTAssertEqual(sum(result), 0)
        XCTAssertEqual(result.count, TravelCategory.allCases.count)
    }

    // MARK: - End-to-end profile

    private func photo(_ id: String, lat: Double, lon: Double, city: String? = nil) -> GeoPhoto {
        GeoPhoto(id: id, coordinate: .init(latitude: lat, longitude: lon),
                 date: Date(timeIntervalSince1970: 1_000),
                 country: "Testland", countryCode: "XX", city: city, isGeocoded: true)
    }

    func testProfileSlicesSumTo100() {
        // A mix that lights up several categories.
        var photos: [GeoPhoto] = (0..<4).map { photo("city\($0)", lat: 48.85, lon: 2.35, city: "Paris") }
        photos += (0..<4).map { photo("wild\($0)", lat: 60.0, lon: 10.0) }
        let coast = ["city0": 5.0, "wild0": 3.0]     // some coastal signal
        let cityDist = ["wild0": 40.0, "wild1": 40.0] // some remote signal

        let profile = engine.makeProfile(photos: photos,
                                         coastalDistanceByPhoto: coast,
                                         cityDistanceByPhoto: cityDist)
        let total = profile.slices.reduce(0) { $0 + $1.percentage }
        XCTAssertEqual(total, 100, accuracy: 0.001)
    }

    func testSingleCategoryProfileIs100() {
        let photos = (0..<5).map { photo("\($0)", lat: 48.85, lon: 2.35, city: "Paris") }
        let profile = engine.makeProfile(photos: photos)
        let total = profile.slices.reduce(0) { $0 + $1.percentage }
        XCTAssertEqual(total, 100, accuracy: 0.001)
    }
}
