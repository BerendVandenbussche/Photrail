import Foundation
import HealthKit
import CoreLocation

/// The single point of contact with HealthKit. Wraps `HKHealthStore`, requests read-only
/// authorization, and exposes typed queries that return `Sendable` value types — so the
/// pure `TravelInsightsEngine` never touches HealthKit directly and stays unit-testable.
///
/// Privacy: reads only, never writes; all data stays on device.
actor HealthKitService {

    // MARK: - Raw sample value types (Sendable outputs for the engine)

    struct HeartRateSample: Sendable {
        let date: Date
        let bpm: Double
    }

    struct RawWorkout: Sendable {
        let id: String
        let activityRawValue: UInt
        let start: Date
        let end: Date
        let distanceMeters: Double?
        let energyKcal: Double?
        let route: [GeoPhoto.Coordinate]
    }

    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// **Bump `readTypesVersion` whenever you add anything to this set.**
    ///
    /// iOS presents the permission sheet only for types it has never asked about, and it will
    /// not re-ask on its own. A type added after a user first granted access is therefore
    /// silently never authorised — reads return empty forever, and reinstalling the app is the
    /// only thing that fixes it. That is exactly what happened to `workoutRoute`: every user who
    /// turned Insights on before it was added has been getting workouts with no GPS track.
    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.heartRate),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.stepCount),
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()   // added in v2 — see `readTypesVersion`
        ]
    }

    /// The shape of `readTypes`. Bumping it re-presents the sheet once, for the new types only.
    static let readTypesVersion = 2
    private static let versionKey = "healthKitReadTypesVersion"

    /// True when the app now asks for Health types it hadn't asked for last time the sheet was
    /// presented — including the case of a user who granted access before this versioning
    /// existed, which reads as version 0.
    ///
    /// Callers should gate this on the user having opted into Insights at all: someone who never
    /// turned the feature on shouldn't be shown a permission sheet out of nowhere.
    static var needsAuthorizationRefresh: Bool {
        isAvailable && UserDefaults.standard.integer(forKey: versionKey) < readTypesVersion
    }

    /// Present the native permission sheet (read-only). Returns whether the request
    /// completed without error. Note: HealthKit deliberately hides *read* grant status,
    /// so a `true` here does not guarantee the user allowed any specific type — callers
    /// must treat "no samples returned" the same as "denied".
    ///
    /// Re-presenting is cheap and quiet: iOS shows the sheet only for types the user hasn't
    /// already decided on, so for an up-to-date install this is a no-op.
    func requestAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // Stamped only on success, so a transient failure retries next time.
            UserDefaults.standard.set(Self.readTypesVersion, forKey: Self.versionKey)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Aggregates (HKStatisticsQuery — HealthKit does the summation)

    /// Cumulative sum of a quantity type over a window (e.g. flights, energy, steps).
    /// Returns nil when there are no samples.
    func cumulativeSum(_ identifier: HKQuantityTypeIdentifier,
                       unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard Self.isAvailable else { return nil }
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func flightsClimbed(start: Date, end: Date) async -> Int? {
        await cumulativeSum(.flightsClimbed, unit: .count(), start: start, end: end).map { Int($0.rounded()) }
    }

    func activeEnergyKcal(start: Date, end: Date) async -> Double? {
        await cumulativeSum(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
    }

    func steps(start: Date, end: Date) async -> Int? {
        await cumulativeSum(.stepCount, unit: .count(), start: start, end: end).map { Int($0.rounded()) }
    }

    // MARK: - Heart rate (HKSampleQuery — individual samples matter)

    /// All heart-rate samples in a window, ascending by date. Fetched once per trip so the
    /// engine can match each photo to the nearest sample in memory (no per-photo query).
    func heartRateSamples(start: Date, end: Date) async -> [HeartRateSample] {
        guard Self.isAvailable else { return [] }
        let type = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, _ in
                let result = (samples as? [HKQuantitySample])?.map {
                    HeartRateSample(date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit))
                } ?? []
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    // MARK: - Workouts (+ optional routes)

    /// Workouts overlapping the window (includes third-party writes like Strava), each with
    /// its GPS route if one exists (empty otherwise). Pass `includeRoutes: false` to skip the
    /// per-workout route query when only the stats/activity type are needed (e.g. the
    /// personality tilt) — routes are relatively expensive.
    func workouts(start: Date, end: Date, includeRoutes: Bool = true) async -> [RawWorkout] {
        guard Self.isAvailable else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        var result: [RawWorkout] = []
        for workout in workouts {
            let route = includeRoutes ? await routeCoordinates(for: workout) : []
            result.append(RawWorkout(
                id: workout.uuid.uuidString,
                activityRawValue: workout.workoutActivityType.rawValue,
                start: workout.startDate,
                end: workout.endDate,
                distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
                energyKcal: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                route: route
            ))
        }
        return result
    }

    /// Fetch the GPS route for a workout (empty if none — common for non-Apple sources).
    private func routeCoordinates(for workout: HKWorkout) async -> [GeoPhoto.Coordinate] {
        let routeSamples: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let query = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(), predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }
        guard let route = routeSamples.first else { return [] }

        return await withCheckedContinuation { continuation in
            var coords: [GeoPhoto.Coordinate] = []
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, _ in
                if let locations {
                    coords.append(contentsOf: locations.map {
                        GeoPhoto.Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                    })
                }
                if done { continuation.resume(returning: coords) }
            }
            store.execute(query)
        }
    }
}
