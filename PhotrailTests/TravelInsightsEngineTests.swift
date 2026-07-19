import XCTest
import CoreLocation
@testable import Photrail

/// Unit tests for the pure HealthKit-insights computation. No `HKHealthStore` involved —
/// the engine takes raw sample arrays, so everything is testable without entitlements.
final class TravelInsightsEngineTests: XCTestCase {

    private let engine = TravelInsightsEngine()

    // MARK: - Fixtures

    private func geoPhoto(id: String, day: Int, seq: Int = 0) -> GeoPhoto {
        let t = TimeInterval(day) * 86_400 + TimeInterval(seq) * 3_600
        return GeoPhoto(id: id, coordinate: .init(latitude: 48.85, longitude: 2.35),
                        date: Date(timeIntervalSince1970: t),
                        country: "France", countryCode: "FR", city: "Paris", isGeocoded: true)
    }

    private func trip(id: String = "trip-1", code: String = "FR",
                      startDay: Int = 0, endDay: Int = 0, photoCount: Int = 10) -> Trip {
        Trip(id: id, countryCode: code, country: "France", flag: "🇫🇷",
             countries: [.init(id: code, name: "France", flag: "🇫🇷", photoCount: photoCount)],
             startDate: Date(timeIntervalSince1970: TimeInterval(startDay) * 86_400),
             endDate: Date(timeIntervalSince1970: TimeInterval(endDay) * 86_400),
             photoCount: photoCount, cities: ["Paris"], stops: [],
             photoIDs: (0..<photoCount).map { "p\($0)" },
             coordinate: .init(latitude: 48.85, longitude: 2.35),
             highestAltitude: nil, wonders: [])
    }

    // MARK: - 2. Vertical Exploration

    func testElevationMilestonePicksTallestLandmarkClimbed() {
        // 110 flights × 3 m = 330 m = exactly one Eiffel Tower.
        let m = engine.elevationMilestone(flights: 110)
        XCTAssertEqual(m?.landmarkName, "Eiffel Tower")
        XCTAssertEqual(m?.multiple ?? 0, 1.0, accuracy: 0.01)
    }

    func testElevationMilestoneUsesSmallestLandmarkForTinyClimbs() {
        // 10 flights = 30 m: below every landmark → smallest (Statue of Liberty), fractional.
        let m = engine.elevationMilestone(flights: 10)
        XCTAssertEqual(m?.landmarkName, "Statue of Liberty")
        XCTAssertLessThan(m?.multiple ?? 1, 1)
    }

    func testElevationMilestoneNilForNoClimb() {
        XCTAssertNil(engine.elevationMilestone(flights: 0))
    }

    // MARK: - 3. Travel Fuel

    func testFoodEquivalentUsesLocalFoodAndCount() {
        // 460 kcal in France ≈ 2 croissants (230 kcal each).
        let food = engine.foodEquivalent(kcal: 460, countryCode: "FR")
        XCTAssertEqual(food?.foodKey, "croissant")
        XCTAssertEqual(food?.count, 2)
    }

    func testFoodEquivalentFallsBackForUnknownCountry() {
        let food = engine.foodEquivalent(kcal: 1000, countryCode: "ZZ")
        XCTAssertEqual(food?.foodKey, "meal")
        XCTAssertEqual(food?.count, 2)   // 1000 / 500
    }

    func testFoodEquivalentNilForNoEnergy() {
        XCTAssertNil(engine.foodEquivalent(kcal: 0, countryCode: "FR"))
    }

    // MARK: - 5. Travel Persona

    func testPersonaFlaneurStopsConstantly() {
        // Many photos per step, low daily steps → the Flâneur.
        let p = engine.persona(steps: 5_000, photoCount: 100, trip: trip(startDay: 0, endDay: 0))
        XCTAssertEqual(p?.archetypeKey, "flaneur")
    }

    func testPersonaMissionCoversGround() {
        let p = engine.persona(steps: 10_000, photoCount: 5, trip: trip(startDay: 0, endDay: 0))
        XCTAssertEqual(p?.archetypeKey, "mission")
    }

    func testPersonaExplorerHighStepsAndPhotos() {
        let p = engine.persona(steps: 30_000, photoCount: 200, trip: trip(startDay: 0, endDay: 0))
        XCTAssertEqual(p?.archetypeKey, "explorer")
    }

    func testPersonaNilWithoutSteps() {
        XCTAssertNil(engine.persona(steps: nil, photoCount: 50, trip: trip()))
        XCTAssertNil(engine.persona(steps: 0, photoCount: 50, trip: trip()))
    }

    // MARK: - 1. Excitement Meter

    func testExcitementMatchesNearestSampleAndNormalizes() {
        let photos = [geoPhoto(id: "a", day: 0, seq: 0), geoPhoto(id: "b", day: 0, seq: 1)]
        let hr = [
            HealthKitService.HeartRateSample(date: Date(timeIntervalSince1970: 30), bpm: 80),
            HealthKitService.HeartRateSample(date: Date(timeIntervalSince1970: 3_600 + 10), bpm: 140),
        ]
        let result = engine.excitement(photos: photos, heartRate: hr)
        XCTAssertEqual(result.count, 2)
        let byID = Dictionary(uniqueKeysWithValues: result.map { ($0.photoID, $0) })
        XCTAssertEqual(byID["a"]?.bpm, 80)
        XCTAssertEqual(byID["b"]?.bpm, 140)
        XCTAssertEqual(byID["a"]?.vibe ?? 1, 0, accuracy: 0.001)   // lowest → 0
        XCTAssertEqual(byID["b"]?.vibe ?? 0, 1, accuracy: 0.001)   // highest → 1
    }

    func testExcitementSkipsPhotosOutsideWindow() {
        let photos = [geoPhoto(id: "a", day: 0, seq: 0)]
        let hr = [HealthKitService.HeartRateSample(date: Date(timeIntervalSince1970: 10_000), bpm: 90)]
        XCTAssertTrue(engine.excitement(photos: photos, heartRate: hr).isEmpty)
    }

    func testExcitementEmptyWithoutSamples() {
        XCTAssertTrue(engine.excitement(photos: [geoPhoto(id: "a", day: 0)], heartRate: []).isEmpty)
    }

    func testExcitementOnlyBadgesAuthoredPhotos() {
        let photos = [geoPhoto(id: "mine", day: 0, seq: 0), geoPhoto(id: "received", day: 0, seq: 0)]
        let hr = [HealthKitService.HeartRateSample(date: Date(timeIntervalSince1970: 10), bpm: 100)]
        let result = engine.excitement(photos: photos, heartRate: hr, authoredPhotoIDs: ["mine"])
        XCTAssertEqual(result.map(\.photoID), ["mine"])
    }

    // MARK: - Photo authorship (filename heuristic)

    func testForeignFilenamesRejected() {
        for name in ["WhatsApp Image 2023.jpg", "IMG-20230101-WA0001.jpg", "Screenshot 2023.png",
                     "FB_IMG_123.jpg", "image.jpg", "telegram-photo.jpg", "download.jpeg"] {
            XCTAssertTrue(PhotoAuthorship.isForeignFilename(name), "\(name) should be foreign")
        }
    }

    func testCameraCaptureFilenamesAccepted() {
        for name in ["IMG_1234.HEIC", "IMG_0042.JPG", "DSC_0001.JPG"] {
            XCTAssertFalse(PhotoAuthorship.isForeignFilename(name), "\(name) should be a capture")
        }
    }

    // MARK: - Health → lifetime personality direction

    func testHealthDirectionTiltsMountainForClimbsAndHiking() {
        let d = TravelPersonalityEngine.healthDirection(
            flightsClimbed: 200, averageStepsPerDay: nil, workoutActivityKeys: ["hiking"])
        XCTAssertGreaterThan(d[.mountain], 0)
        XCTAssertGreaterThan(d[.adventure], 0)
    }

    func testHealthDirectionActiveDaysLeanAdventure() {
        let d = TravelPersonalityEngine.healthDirection(
            flightsClimbed: nil, averageStepsPerDay: 15_000, workoutActivityKeys: [])
        XCTAssertGreaterThan(d[.adventure], 0)
    }

    func testHealthDirectionSwimmingLeansCoastal() {
        let d = TravelPersonalityEngine.healthDirection(
            flightsClimbed: nil, averageStepsPerDay: nil, workoutActivityKeys: ["swimming"])
        XCTAssertGreaterThan(d[.coastal], 0)
    }

    func testHealthDirectionEmptyWithoutSignals() {
        let d = TravelPersonalityEngine.healthDirection(
            flightsClimbed: nil, averageStepsPerDay: nil, workoutActivityKeys: [])
        XCTAssertEqual(d.total, 0)
    }

    // MARK: - 4. Workout Chapters

    func testWorkoutChapterGroupsPhotosInWindow() {
        let photos = [
            geoPhoto(id: "in1", day: 0, seq: 0),
            geoPhoto(id: "in2", day: 0, seq: 1),
            geoPhoto(id: "out", day: 5, seq: 0),
        ]
        let workout = HealthKitService.RawWorkout(
            id: "w1", activityRawValue: 37,   // running
            start: Date(timeIntervalSince1970: -60),
            end: Date(timeIntervalSince1970: 3_600 + 60),
            distanceMeters: 5_000, energyKcal: 400,
            route: [.init(latitude: 48.85, longitude: 2.35)])
        let chapters = engine.workoutChapters(workouts: [workout], photos: photos)
        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters[0].activityKey, "running")
        XCTAssertEqual(chapters[0].photoIDs, ["in1", "in2"])
        XCTAssertTrue(chapters[0].hasRoute)
    }

    func testWorkoutChapterWithoutPhotosDropped() {
        let workout = HealthKitService.RawWorkout(
            id: "w1", activityRawValue: 52, start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 200), distanceMeters: nil, energyKcal: nil, route: [])
        XCTAssertTrue(engine.workoutChapters(workouts: [workout], photos: []).isEmpty)
    }

    // MARK: - Assembly

    func testBuildWithEmptyInputsHasNoContent() {
        let insights = engine.build(
            trip: trip(), signature: "sig", authorized: true, photos: [],
            heartRate: [], flightsClimbed: nil, activeEnergyKcal: nil,
            steps: nil, workouts: [], now: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(insights.hasAnyContent)
        XCTAssertNil(insights.flightsClimbed)
        XCTAssertNil(insights.persona)
        XCTAssertTrue(insights.excitement.isEmpty)
        XCTAssertTrue(insights.authorized)
    }

    func testBuildAssemblesAllFeatures() {
        let photos = [geoPhoto(id: "p0", day: 0, seq: 0)]
        let hr = [HealthKitService.HeartRateSample(date: Date(timeIntervalSince1970: 20), bpm: 100)]
        let workout = HealthKitService.RawWorkout(
            id: "w1", activityRawValue: 13, start: Date(timeIntervalSince1970: -30),
            end: Date(timeIntervalSince1970: 300), distanceMeters: 8_000, energyKcal: 300, route: [])
        let insights = engine.build(
            trip: trip(photoCount: 1), signature: "sig", authorized: true, photos: photos,
            heartRate: hr, flightsClimbed: 110, activeEnergyKcal: 460, steps: 5_000,
            workouts: [workout], now: Date(timeIntervalSince1970: 0))

        XCTAssertTrue(insights.hasAnyContent)
        XCTAssertEqual(insights.flightsClimbed, 110)
        XCTAssertEqual(insights.elevationMilestone?.landmarkName, "Eiffel Tower")
        XCTAssertEqual(insights.foodEquivalent?.count, 2)
        XCTAssertEqual(insights.workoutChapters.count, 1)
        XCTAssertEqual(insights.persona?.archetypeKey, "flaneur")
        XCTAssertEqual(insights.excitement.count, 1)
    }
}
