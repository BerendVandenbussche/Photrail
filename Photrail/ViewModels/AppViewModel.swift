import Foundation
import Photos
import SwiftUI
import SwiftData
import WidgetKit
import CoreLocation

@MainActor
@Observable
final class AppViewModel {

    // MARK: - Navigation state

    enum NavState {
        case onboarding
        case dashboard
        case permissionDenied
    }

    // MARK: - Background scan progress (drives the in-dashboard banner)

    enum ScanProgress: Equatable {
        case idle
        case scanning(progress: Double, found: Int)
        case resolvingCountries(progress: Double, total: Int)
        case geocoding(progress: Double, total: Int)
        case complete
        case failed(String)

        var isActive: Bool {
            switch self {
            case .idle, .complete: return false
            default: return true
            }
        }
    }

    enum AppTab: Hashable { case today, map, places, me }

    var navState: NavState = .onboarding
    var scanProgress: ScanProgress = .idle
    var stats: TravelStats = .empty {
        didSet {
            refreshCountryBounds()
            checkAchievements()
        }
    }

    /// Secret milestone achievements the user has unlocked (IDs from `AchievementCatalog`).
    private(set) var unlockedAchievementIDs: Set<String> = []
    /// Newly-earned achievements awaiting their one-time confetti toast (FIFO).
    var achievementQueue: [Achievement] = []
    /// "On this day" memories for today — photos from this calendar day in past years.
    var memories: [Memory] = []

    /// Cached country border bounding boxes (from the offline geocoder), keyed by ISO code.
    /// Populated lazily so the Places grid can show a "geographic spread" coverage bar.
    private(set) var countryBorderBounds: [String: GeoBounds] = [:]

    /// A recap presented from an App Intent (Siri / Shortcuts). Drives a root sheet.
    var presentedRecap: RecapModel?

    /// "Explorer rarity" 0–100 — how off-the-beaten-path your photos are (distance to
    /// the nearest town), computed alongside the personality profile. 0 = not enough data.
    var explorerRarity: Int = 0

    /// Countries the user added by hand (photos deleted / never on device). Persisted.
    var manualCountries: [ManualCountry] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(manualCountries) {
                UserDefaults.standard.set(data, forKey: "manualCountries")
            }
        }
    }

    /// Individual photos the user has excluded from evaluation — dropped from every stat.
    /// Persisted, fully reversible. Per-photo (not per-country) so a place resurfaces on
    /// its own once the user takes their own photos there. See `ExcludedPhotosStore`.
    private(set) var excludedPhotoIDs: Set<String> = []

    /// Bumped whenever a trip's insights are (re)computed and cached. Views that derive a
    /// trip's display "vibe" from cached insights read this so SwiftUI re-renders them when
    /// the UserDefaults-backed `TripInsightsStore` changes — e.g. a list row updates from
    /// "Mountains" to "Ski trip" after the detail view computes Health data.
    private(set) var insightsRevision = 0

    /// In-app purchase entitlement manager for "Photrail Lifetime".
    let storeService = StoreService()

    /// Whether the user has unlocked Lifetime (via purchase or grandfathering). Free users
    /// keep the full map, trips, stats and "On This Day"; this gates the delight layer.
    var hasLifetime: Bool { storeService.hasLifetime }

    /// Localized price for paywall CTAs (from StoreKit, e.g. "€2,99").
    var lifetimePrice: String { storeService.displayPrice }

    /// Buy Lifetime. Returns true on success. Republishes widget stats on change.
    @discardableResult
    func purchaseLifetime() async -> Bool {
        let ok = await storeService.purchase()
        if ok { publishWidgetStats() }
        return ok
    }

    /// Restore a previous purchase (App Review requirement).
    func restorePurchases() async {
        await storeService.restore()
        publishWidgetStats()
    }

    /// Selected bottom-tab; mutable so other views (e.g. the "set home" CTA) can switch tabs.
    var selectedTab: AppTab = .today

    /// Master switch for the (optional) HealthKit Insights module. Off by default —
    /// the user opts in contextually from a trip. Enabling it triggers the Health
    /// permission sheet via `enableInsights()`.
    var insightsEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(insightsEnabled, forKey: "insightsEnabled")
            // Turning it off strips Health influence from the personality. Turning it on
            // recomputes via `enableInsights()` once permission has been resolved.
            if !insightsEnabled { Task { await recomputePersonality() } }
        }
    }

    /// Whether the user dismissed the contextual "Enable Insights" card. Once dismissed,
    /// the opt-in prompt no longer appears on any trip (they can still enable Insights from
    /// the Me tab). Reset to `false` if they ever enable it.
    var insightsPromptDismissed: Bool = false {
        didSet { UserDefaults.standard.set(insightsPromptDismissed, forKey: "insightsPromptDismissed") }
    }

    /// Master switch for all travel nudges (new-country, trip-ready, year recap). Default on.
    var travelNudgesEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(travelNudgesEnabled, forKey: "travelNudgesEnabled")
            if travelNudgesEnabled { Task { await NotificationService.requestAuthorization() } }
        }
    }

    /// Emoji the user picked as their profile avatar.
    var profileEmoji: String {
        didSet { UserDefaults.standard.set(profileEmoji, forKey: "profileEmoji") }
    }

    /// Travel personality profile derived from photo locations (cached).
    var personalityProfile: TravelPersonalityProfile?
    private let personalityCacheKey = "travelPersonalityProfile"

    /// The user's home country (ISO code), set in Settings. Used for "furthest from home".
    var homeCountryCode: String? {
        didSet {
            UserDefaults.standard.set(homeCountryCode, forKey: "homeCountryCode")
            Task { await recomputePersonality() }
        }
    }

    /// Display name for the configured home (e.g. "Paris, France"), chosen via Maps search.
    var homeName: String? {
        didSet { UserDefaults.standard.set(homeName, forKey: "homeName") }
    }

    /// Precise home coordinate, resolved from an Apple Maps search result.
    private var homeLatitude: Double? {
        didSet { UserDefaults.standard.set(homeLatitude, forKey: "homeLatitude") }
    }
    private var homeLongitude: Double? {
        didSet { UserDefaults.standard.set(homeLongitude, forKey: "homeLongitude") }
    }

    struct FurthestTrip { let trip: Trip; let distanceKm: Double }

    /// Set the user's home from an Apple Maps search result.
    func setHome(name: String, latitude: Double, longitude: Double, countryCode: String?) {
        homeName = name
        homeLatitude = latitude
        homeLongitude = longitude
        homeCountryCode = countryCode   // triggers recomputePersonality()
    }

    /// Clear the configured home.
    func clearHome() {
        homeName = nil
        homeLatitude = nil
        homeLongitude = nil
        homeCountryCode = nil            // triggers recomputePersonality()
    }

    /// Display name for the configured home.
    var homeDisplayName: String? { homeName }

    /// Coordinate used as the origin for distance calculations — the precise home
    /// location if set, otherwise the home country's representative coordinate.
    var homeCoordinate: GeoPhoto.Coordinate? {
        if let lat = homeLatitude, let lon = homeLongitude {
            return GeoPhoto.Coordinate(latitude: lat, longitude: lon)
        }
        if let code = homeCountryCode, let country = stats.countries.first(where: { $0.id == code }) {
            return country.representativeCoordinate
        }
        return nil
    }

    /// Fetch border bounding boxes for any visited countries we haven't cached yet.
    private func refreshCountryBounds() {
        let missing = stats.countries.map(\.id).filter { countryBorderBounds[$0] == nil }
        guard !missing.isEmpty else { return }
        let geocoder = offlineGeocoder
        Task { [weak self] in
            var fetched: [String: GeoBounds] = [:]
            for code in missing {
                if let bounds = await geocoder.bounds(for: code) { fetched[code] = bounds }
            }
            guard !fetched.isEmpty else { return }
            await MainActor.run {
                guard let self else { return }
                self.countryBorderBounds.merge(fetched) { _, new in new }
            }
        }
    }

    /// How much of a country's extent your photos span, 0…1 ("geographic spread"):
    /// the area of your photos' bounding box relative to the country's border bounding box.
    /// Returns nil until the country's borders are cached or if there's nothing to show.
    func coverage(for country: CountryStat) -> Double? {
        guard let visited = country.visitedBounds,
              let border = countryBorderBounds[country.id] else { return nil }
        let borderArea = border.areaKm2
        guard borderArea > 0 else { return nil }
        return min(1, max(0, visited.areaKm2 / borderArea))
    }

    /// Countries ranked by number of distinct trips (excluding home).
    var mostVisitedCountries: [CountryStat] {
        stats.countries
            .filter { $0.id != homeCountryCode }
            .sorted { ($0.tripCount, $0.photoCount) > ($1.tripCount, $1.photoCount) }
    }

    /// The trip furthest from the user's home (nil until home is set).
    var furthestTrip: FurthestTrip? {
        guard let home = homeCoordinate else { return nil }
        let homeLocation = CLLocation(latitude: home.latitude, longitude: home.longitude)

        let best = stats.trips
            .map { trip -> (Trip, Double) in
                let loc = CLLocation(latitude: trip.coordinate.latitude, longitude: trip.coordinate.longitude)
                return (trip, homeLocation.distance(from: loc) / 1000)
            }
            .max { $0.1 < $1.1 }

        return best.map { FurthestTrip(trip: $0.0, distanceKm: $0.1) }
    }

    /// True whenever a scan is running or queued — used to schedule/cancel BGProcessingTask.
    var isScanNeeded: Bool {
        switch scanProgress {
        case .scanning, .resolvingCountries, .geocoding: return true
        default: return false
        }
    }

    var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenOnboarding") }
    }

    private let scanService = PhotoScanService()
    private let offlineCityGeocoder = OfflineCityGeocoder()
    private let offlineGeocoder = OfflineCountryGeocoder()
    private let offlineCoastline = OfflineCoastline()
    private let offlinePlaces = OfflinePlaces()
    private let photoCurator = PhotoCurator()
    private let store: PhotoStore
    private let statsEngine = StatisticsEngine()
    private let healthKit = HealthKitService()
    private let insightsEngine = TravelInsightsEngine()

    private let changeTokenKey = "lastChangeToken"
    private let datasetVersionKey = "datasetVersion"
    // Single version for all bundled geo datasets (countries.geojson, cities1000.tsv, …).
    // Lives in Version.xcconfig (DATASET_VERSION), read from Info.plist; bumping it forces a
    // one-time re-resolution of every photo's country and city on the next scan.
    private static let datasetVersion =
        (Bundle.main.object(forInfoDictionaryKey: "DatasetVersion") as? String).flatMap(Int.init) ?? 1

    // Tracks the active foreground scan task so we can cancel it on background
    private var foregroundScanTask: Task<Void, Never>?
    // Incremented on every new scan; progress closures from a cancelled scan bail when mismatched
    private var scanGeneration = 0
    // Country codes already encountered during the current scan (seeded from the store).
    private var scanSeenCountryCodes: Set<String> = []

    // Persisted set of countries we've already sent a "new country" notification for.
    private let notifiedCountryCodesKey = "notifiedCountryCodes"
    private var notifiedCountryCodes: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: notifiedCountryCodesKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: notifiedCountryCodesKey) }
    }

    init(store: PhotoStore) {
        self.store = store
        let loadedCountry = UserDefaults.standard.string(forKey: "homeCountryCode")
        let loadedName = UserDefaults.standard.string(forKey: "homeName")
        let loadedLat = UserDefaults.standard.object(forKey: "homeLatitude") as? Double
        let loadedLon = UserDefaults.standard.object(forKey: "homeLongitude") as? Double
        UserDefaults.standard.removeObject(forKey: "homeCityID")   // retired: home is now a Maps coordinate
        // Clean cutover: the legacy home only stored a country code (no coordinate). Clear it
        // fully so the user re-picks via Maps search — otherwise the dangling code hides the
        // "set home" prompt while the display name shows nothing. (Property observers don't
        // fire during init, so the stale keys are removed from UserDefaults explicitly.)
        let legacyHome = loadedCountry != nil && (loadedLat == nil || loadedLon == nil)
        if legacyHome {
            for key in ["homeCountryCode", "homeName", "homeLatitude", "homeLongitude"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        self.homeCountryCode = legacyHome ? nil : loadedCountry
        self.homeName = legacyHome ? nil : loadedName
        self.homeLatitude = legacyHome ? nil : loadedLat
        self.homeLongitude = legacyHome ? nil : loadedLon
        self.profileEmoji = UserDefaults.standard.string(forKey: "profileEmoji") ?? "🧭"
        if let data = UserDefaults.standard.data(forKey: personalityCacheKey),
           let cached = try? JSONDecoder().decode(TravelPersonalityProfile.self, from: data) {
            self.personalityProfile = cached
        }
        if let data = UserDefaults.standard.data(forKey: "manualCountries"),
           let decoded = try? JSONDecoder().decode([ManualCountry].self, from: data) {
            self.manualCountries = decoded
        }
        self.excludedPhotoIDs = ExcludedPhotosStore.load()
        if let enabled = UserDefaults.standard.object(forKey: "travelNudgesEnabled") as? Bool {
            self.travelNudgesEnabled = enabled
        }
        self.insightsEnabled = UserDefaults.standard.bool(forKey: "insightsEnabled")
        self.insightsPromptDismissed = UserDefaults.standard.bool(forKey: "insightsPromptDismissed")
        self.explorerRarity = UserDefaults.standard.integer(forKey: "explorerRarity")
        self.unlockedAchievementIDs = AchievementStore.load()
        // Skip the onboarding flash on relaunch: if the user already onboarded,
        // start straight on the dashboard. The async permission check still runs
        // and will redirect to .permissionDenied if access was revoked.
        if UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            self.navState = .dashboard
        }

        // Resolve the IAP entitlement (product, current entitlements, grandfathering) and
        // republish widget stats whenever it changes.
        storeService.onEntitlementChange = { [weak self] in self?.publishWidgetStats() }
        Task { [weak self] in
            await self?.storeService.start()
            self?.publishWidgetStats()
        }
    }

    /// In-memory instance for SwiftUI previews.
    @MainActor static var preview: AppViewModel {
        let container = try! ModelContainer(
            for: StoredPhoto.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = AppViewModel(store: PhotoStore(modelContainer: container))
        vm.stats = .mock
        return vm
    }

    // MARK: - Achievements

    /// Re-evaluate every achievement against the current stats. Persists the unlocked set
    /// and queues genuinely-new unlocks for celebration. The very first evaluation after
    /// install/update adopts existing progress *silently* — so upgrading users don't get a
    /// burst of confetti for milestones they passed long ago.
    private func checkAchievements() {
        let currently = Set(AchievementCatalog.all.filter { $0.isUnlocked(stats) }.map(\.id))
        let newlyUnlocked = currently.subtracting(unlockedAchievementIDs)
        unlockedAchievementIDs.formUnion(currently)
        AchievementStore.save(unlockedAchievementIDs)

        guard UserDefaults.standard.bool(forKey: "achievementsInitialized") else {
            UserDefaults.standard.set(true, forKey: "achievementsInitialized")
            return   // seed silently on first run
        }
        guard !newlyUnlocked.isEmpty else { return }
        achievementQueue.append(contentsOf: AchievementCatalog.all.filter { newlyUnlocked.contains($0.id) })
    }

    /// Dismiss the achievement toast currently on screen and advance to the next, if any.
    func dismissTopAchievement() {
        if !achievementQueue.isEmpty { achievementQueue.removeFirst() }
    }

    // MARK: - Entry points

    // MARK: - Manual countries

    /// Add a country by hand (for trips whose photos are gone), then refresh stats.
    func addManualCountry(code: String) {
        let code = code.uppercased()
        guard !manualCountries.contains(where: { $0.code == code }) else { return }
        Task {
            let coord = await offlineGeocoder.representativeCoordinate(for: code)
            manualCountries.append(ManualCountry(
                code: code,
                name: CountryCatalog.name(for: code),
                flag: CountryCatalog.flag(for: code),
                latitude: coord?.latitude, longitude: coord?.longitude
            ))
            await refreshStatsWithManual()
        }
    }

    func removeManualCountry(code: String) {
        manualCountries.removeAll { $0.code == code }
        Task { await refreshStatsWithManual() }
    }

    /// True when a country code came from a manual entry (no photos).
    func isManualCountry(_ code: String) -> Bool {
        manualCountries.contains { $0.code == code }
    }

    // MARK: - Excluded photos

    /// True when a photo is currently excluded from all stats.
    func isPhotoExcluded(_ id: String) -> Bool {
        excludedPhotoIDs.contains(id)
    }

    /// Exclude one or more photos: they're dropped from every stat, trip, city, country
    /// and memory. Persisted and reversible.
    func excludePhotos(ids: [String]) {
        guard !ids.isEmpty else { return }
        excludedPhotoIDs.formUnion(ids)
        ExcludedPhotosStore.save(excludedPhotoIDs)
        Task { await refreshStatsWithManual() }
    }

    /// Restore previously excluded photos so they count again everywhere.
    func includePhotos(ids: [String]) {
        guard !ids.isEmpty else { return }
        excludedPhotoIDs.subtract(ids)
        ExcludedPhotosStore.save(excludedPhotoIDs)
        Task { await refreshStatsWithManual() }
    }

    /// Toggle a single photo's exclusion — convenient for the full-screen viewer.
    func togglePhotoExcluded(_ id: String) {
        if excludedPhotoIDs.contains(id) { includePhotos(ids: [id]) }
        else { excludePhotos(ids: [id]) }
    }

    /// Give a trip a custom name (or clear it with an empty string) and recompute so the
    /// new title shows everywhere — lists, detail, and share cards.
    func renameTrip(_ name: String, tripID: String) {
        TripNameStore.setName(name, for: tripID)
        Task { await refreshStatsWithManual() }
    }

    // MARK: - HealthKit Insights

    /// A signature of the trip's photo set, so cached insights are invalidated when it changes.
    static func insightsSignature(for trip: Trip) -> String {
        "v4-\(trip.photoIDs.count)-\(Int(trip.startDate.timeIntervalSince1970))-\(Int(trip.endDate.timeIntervalSince1970))"
    }

    /// Fresh cached insights for a trip, or nil if none / stale.
    func cachedInsights(for trip: Trip) -> TripInsights? {
        TripInsightsStore.insights(for: trip.id, signature: Self.insightsSignature(for: trip))
    }

    /// The trip's display "vibe": the workout-derived activity when it's known (from cached
    /// insights), otherwise the location-inferred type. Matches the trip share card's theme.
    func vibe(for trip: Trip) -> TripType {
        // Touch the revision so SwiftUI re-evaluates callers when insights are recomputed.
        _ = insightsRevision
        return TripShareTheme.decide(trip: trip, insights: cachedInsights(for: trip)).tripTypeOverride ?? trip.tripType
    }

    /// Turn on the Insights module and present the Health permission sheet.
    /// Returns whether the authorization request completed (not whether reads were granted —
    /// HealthKit hides that; callers detect denial as "no data").
    func enableInsights() async -> Bool {
        insightsEnabled = true
        let granted = await healthKit.requestAuthorization()
        // Fold the newly-available Health signals into the lifetime personality.
        await recomputePersonality()
        return granted
    }

    /// Compute (or reuse cached) insights for a trip. HealthKit queries run inside the
    /// service actor, off the main actor; the pure engine assembles the result.
    func computeInsights(for trip: Trip) async -> TripInsights {
        let signature = Self.insightsSignature(for: trip)
        if let cached = cachedInsights(for: trip) { return cached }

        let now = Date()
        guard HealthKitService.isAvailable, insightsEnabled else {
            return .empty(tripID: trip.id, signature: signature, authorized: false, at: now)
        }

        // The trip's photos (dates + coordinates) for HR matching and workout grouping.
        let idSet = Set(trip.photoIDs)
        let photos = ((try? await store.allPhotos()) ?? []).filter { idSet.contains($0.id) }

        // Query the full calendar span of the trip (pads to whole days for morning workouts etc.).
        let cal = Calendar.current
        let windowStart = cal.startOfDay(for: trip.startDate)
        let windowEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: trip.endDate)) ?? trip.endDate

        let heartRate = await healthKit.heartRateSamples(start: windowStart, end: windowEnd)
        let flights = await healthKit.flightsClimbed(start: windowStart, end: windowEnd)
        let energy = await healthKit.activeEnergyKcal(start: windowStart, end: windowEnd)
        let steps = await healthKit.steps(start: windowStart, end: windowEnd)
        let workouts = await healthKit.workouts(start: windowStart, end: windowEnd)

        // Restrict the Excitement Meter to photos the user likely captured themselves.
        let authored = await PhotoAuthorship().likelyAuthored(assetIDs: Array(idSet))

        let insights = insightsEngine.build(
            trip: trip, signature: signature, authorized: true, photos: photos,
            heartRate: heartRate, flightsClimbed: flights, activeEnergyKcal: energy,
            steps: steps, workouts: workouts, authoredPhotoIDs: authored, now: now)
        TripInsightsStore.save(insights)
        insightsRevision &+= 1
        return insights
    }

    /// A trip's Health "direction" for the lifetime personality tilt. Cheap by design —
    /// three statistics queries + a route-less workout fetch, all on the HealthKit actor
    /// (off the main thread). No photos, heart rate, routes, or authorship. Returns nil when
    /// Health has nothing for the trip's dates.
    private func healthDirection(for trip: Trip) async -> TravelCategoryScores? {
        let cal = Calendar.current
        let windowStart = cal.startOfDay(for: trip.startDate)
        let windowEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: trip.endDate)) ?? trip.endDate

        let flights = await healthKit.flightsClimbed(start: windowStart, end: windowEnd)
        let steps = await healthKit.steps(start: windowStart, end: windowEnd)
        let workouts = await healthKit.workouts(start: windowStart, end: windowEnd, includeRoutes: false)

        let days = max(1, (cal.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0) + 1)
        let avgSteps = steps.map { Double($0) / Double(days) }
        let activityKeys = workouts.map { TravelInsightsEngine.activity(for: $0.activityRawValue).key }

        let direction = TravelPersonalityEngine.healthDirection(
            flightsClimbed: flights, averageStepsPerDay: avgSteps, workoutActivityKeys: activityKeys)
        return direction.total > 0 ? direction : nil
    }

    private func refreshStatsWithManual() async {
        let photos = (try? await store.allPhotos()) ?? []
        stats = statsEngine.compute(from: photos, homeCountryCode: homeCountryCode,
                                    homeCoordinate: homeCoordinate, manualCountries: manualCountries, excludedPhotoIDs: excludedPhotoIDs)
        publishWidgetStats()
    }

    func startOnboarding() {
        if hasSeenOnboarding {
            Task { await checkPermissionAndProceed() }
        }
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
        Task { await requestPermissionAndProceed() }
    }

    func retryPermission() {
        Task { await requestPermissionAndProceed() }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Scene phase handling

    /// Call from the app's `.onChange(of: scenePhase)` handler.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Cancel the foreground task — BGProcessingTask will resume it later.
            foregroundScanTask?.cancel()
            foregroundScanTask = nil
        case .active:
            // If a scan was interrupted by backgrounding, resume it now.
            if case .scanning = scanProgress { startForegroundScan() }
            if case .resolvingCountries = scanProgress { startForegroundScan() }
            if case .geocoding = scanProgress { startForegroundScan() }
        default:
            break
        }
    }

    // MARK: - Background task entry point (called by BGProcessingTask handler)

    /// Runs a full scan pipeline. Safe to call from a background BGProcessingTask.
    /// Respects Swift Task cancellation — the BGTask expiration handler cancels the Task.
    func runBackgroundScan() async {
        await performScan()
    }

    /// Build the Year in Travel recap for the given year (defaults to the current year).
    /// Year-scoped: filters photos to the year and runs the same engines as the dashboard.
    func makeYearRecap(year: Int = Calendar.current.component(.year, from: Date())) async -> RecapModel {
        let all = (try? await store.allPhotos()) ?? []
        let yearPhotos = all.filter {
            $0.isGeocoded && Calendar.current.component(.year, from: $0.date) == year
        }
        guard !yearPhotos.isEmpty else { return .empty(year: year) }

        // Manual countries are intentionally excluded from a year recap (they have no date).
        let yearStats = statsEngine.compute(from: yearPhotos, homeCountryCode: homeCountryCode,
                                            homeCoordinate: homeCoordinate,
                                            excludedPhotoIDs: excludedPhotoIDs)

        var wonderByPhoto: [String: String] = [:]
        for wonder in yearStats.wonders {
            for id in wonder.photoIDs { wonderByPhoto[id] = wonder.wonder.id }
        }
        let pointInput = yearPhotos.map { (id: $0.id, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
        let coast = await offlineCoastline.distancesKm(pointInput)
        let cityDist = await offlinePlaces.distancesKm(pointInput)
        let home = homeCoordinate

        let profile = TravelPersonalityEngine().makeProfile(
            photos: yearPhotos,
            wonderIDByPhoto: wonderByPhoto,
            coastalDistanceByPhoto: coast,
            cityDistanceByPhoto: cityDist,
            trips: yearStats.trips,
            home: home
        )
        let distance = Self.totalDistanceKm(trips: yearStats.trips, home: home)

        // Countries visited for the first time *ever* this year: their earliest photo
        // across the whole library falls in this year.
        var earliestByCountry: [String: Date] = [:]
        for photo in all where photo.isGeocoded {
            guard let code = photo.countryCode else { continue }
            if let existing = earliestByCountry[code] {
                if photo.date < existing { earliestByCountry[code] = photo.date }
            } else {
                earliestByCountry[code] = photo.date
            }
        }
        let newCountries: [RecapModel.CountryBadge] = yearStats.countries
            .filter { country in
                country.id != homeCountryCode &&
                earliestByCountry[country.id].map { Calendar.current.component(.year, from: $0) == year } == true
            }
            .sorted { $0.firstVisit < $1.firstVisit }
            // English names — the recap cards stay English.
            .map { .init(id: $0.id,
                         name: Locale(identifier: "en_US").localizedString(forRegionCode: $0.id) ?? $0.name,
                         flag: $0.flag) }

        // Highest point reached this year (only surfaced above 1000 m).
        var highestAltitude: Double?
        var highestAltitudePlace: String?
        var highestPeakPhotoID: String?
        if let peak = yearPhotos.compactMap({ p in p.altitude.map { ($0, p) } }).max(by: { $0.0 < $1.0 }),
           peak.0 >= 1000 {
            highestAltitude = peak.0
            highestAltitudePlace = peak.1.country.map { "\(peak.1.flagEmoji) \($0)" }

            // Look for an actual mountain photo within 1 km of the highest point.
            let peakLoc = CLLocation(latitude: peak.1.coordinate.latitude, longitude: peak.1.coordinate.longitude)
            let nearbyIDs = yearPhotos
                .filter {
                    CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                        .distance(from: peakLoc) <= 1000
                }
                .prefix(40)
                .map(\.id)
            highestPeakPhotoID = await photoCurator.bestPhoto(candidateIDs: Array(nearbyIDs), subject: .mountain)
        }

        // For each seen wonder, find a photo that actually depicts it (not a nearby selfie).
        var wonderPhotos: [String: String] = [:]
        for wonderStat in yearStats.wonders where wonderStat.seen {
            let subject: PhotoCurator.Subject
            switch TravelPersonalityEngine.wonderKind(forID: wonderStat.wonder.id) {
            case .mountain: subject = .mountain
            case .natural:  subject = .nature
            case .coastal:  subject = .coastal
            case .cultural: subject = .landmark
            }
            let candidates = Array(wonderStat.photoIDs.prefix(12))
            if let id = await photoCurator.bestPhoto(candidateIDs: candidates, subject: subject) {
                wonderPhotos[wonderStat.wonder.id] = id
            }
        }

        // Vision-curated best shots from across *all* the year's trips (every non-home
        // country), so the collage reflects the whole year, not just one destination.
        // Ranked on-device by aesthetics + personality match, minus people/pet/screenshots.
        // Candidates are round-robined across countries and capped so the number of Vision
        // passes stays bounded regardless of library size.
        let candidateIDs = Self.balancedCandidateIDs(
            countries: yearStats.countries.filter { $0.id != homeCountryCode },
            perCountry: 25,
            total: 120
        )
        let highlightPhotoIDs = await photoCurator.bestPhotos(
            candidateIDs: candidateIDs,
            category: profile.dominantCategory
        )

        return RecapModel.make(year: year, stats: yearStats, profile: profile,
                               photoCount: yearPhotos.count, distanceKm: distance,
                               homeCountryCode: homeCountryCode, newCountries: newCountries,
                               highestAltitude: highestAltitude, highestAltitudePlace: highestAltitudePlace,
                               highestPeakPhotoID: highestPeakPhotoID,
                               highlightPhotoIDs: highlightPhotoIDs,
                               wonderPhotos: wonderPhotos)
    }

    /// Merges photo IDs from every country into one candidate list for curation, taking up
    /// to `perCountry` from each (most-photographed countries first) and round-robining them
    /// so no single destination dominates, then capping at `total`. Keeps the number of
    /// Vision scoring passes bounded no matter how large the library is.
    private static func balancedCandidateIDs(countries: [CountryStat],
                                             perCountry: Int,
                                             total: Int) -> [String] {
        let pools = countries
            .sorted { $0.photoCount > $1.photoCount }
            .map { Array($0.photoIDs.prefix(perCountry)) }
        var result: [String] = []
        var index = 0
        while result.count < total {
            var added = false
            for pool in pools where index < pool.count {
                result.append(pool[index])
                added = true
                if result.count >= total { break }
            }
            if !added { break }   // every pool exhausted
            index += 1
        }
        return result
    }

    /// Approximate total distance: round trips from home if set, else hop-to-hop between trips.
    private static func totalDistanceKm(trips: [Trip], home: GeoPhoto.Coordinate?) -> Double {
        func loc(_ c: GeoPhoto.Coordinate) -> CLLocation { CLLocation(latitude: c.latitude, longitude: c.longitude) }
        if let home {
            let h = loc(home)
            return trips.reduce(0) { $0 + h.distance(from: loc($1.coordinate)) / 1000 * 2 }
        }
        let ordered = trips.sorted { $0.startDate < $1.startDate }
        var total = 0.0
        for i in 1..<max(ordered.count, 1) where ordered.count > 1 {
            total += loc(ordered[i - 1].coordinate).distance(from: loc(ordered[i].coordinate)) / 1000
        }
        return total
    }

    /// Wipe the cache and rebuild from scratch. Use when photos' locations changed
    /// after indexing (e.g. you set the location of a downloaded image in Photos),
    /// which a normal incremental scan won't pick up since the asset id is unchanged.
    func reindex() {
        foregroundScanTask?.cancel()
        foregroundScanTask = nil
        Task {
            try? await store.deleteAll()
            UserDefaults.standard.removeObject(forKey: changeTokenKey)
            TripInsightsStore.clearAll()
            stats = .empty
            startForegroundScan()
        }
    }

    // MARK: - Permission

    private func checkPermissionAndProceed() async {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            showDashboardAndScan()
        case .denied, .restricted:
            navState = .permissionDenied
        case .notDetermined:
            navState = .onboarding
        @unknown default:
            navState = .onboarding
        }
    }

    private func requestPermissionAndProceed() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showDashboardAndScan()
        case .denied, .restricted:
            navState = .permissionDenied
        default:
            navState = .permissionDenied
        }
    }

    // MARK: - Foreground scan

    private func showDashboardAndScan() {
        // Load stored stats immediately so the dashboard isn't empty
        Task {
            if let stored = try? await store.allPhotos(), !stored.isEmpty {
                stats = statsEngine.compute(from: stored, homeCountryCode: homeCountryCode, homeCoordinate: homeCoordinate, manualCountries: manualCountries, excludedPhotoIDs: excludedPhotoIDs)
                memories = MemoriesEngine().memories(from: stored, homeCoordinate: homeCoordinate,
                                                     homeCountryCode: homeCountryCode,
                                                     excludedPhotoIDs: excludedPhotoIDs)
                publishWidgetStats()
            }
        }
        // Ask for notification permission so we can celebrate new countries while traveling.
        Task { await NotificationService.requestAuthorization() }
        navState = .dashboard
        startForegroundScan()
    }

    private func startForegroundScan() {
        guard foregroundScanTask == nil else { return }
        foregroundScanTask = Task {
            await performScan()
            foregroundScanTask = nil
        }
    }

    // MARK: - Core scan pipeline (shared by foreground and background)

    private func performScan() async {
        scanGeneration &+= 1
        let generation = scanGeneration
        let store = self.store
        do {
            scanProgress = .scanning(progress: 0, found: 0)

            // Phase 1: enumerate the library only if it changed since last time.
            // New photos are inserted as rows; existing rows (and their geocoding) are untouched.
            let currentToken = await scanService.currentChangeToken()
            let lastToken = UserDefaults.standard.string(forKey: changeTokenKey)
            let storedCount = (try? await store.totalCount()) ?? 0

            if storedCount == 0 || currentToken == nil || currentToken != lastToken {
                let scanned = try await scanService.fetchGeotaggedPhotos { [weak self] progress, found in
                    Task { @MainActor in
                        guard let self, self.scanGeneration == generation else { return }
                        self.scanProgress = .scanning(progress: progress, found: found)
                    }
                }
                try await store.insertNewPhotos(scanned)
                UserDefaults.standard.set(currentToken, forKey: changeTokenKey)
            }

            try Task.checkCancellation()

            let statsEngine = self.statsEngine   // Sendable; captured so we can compute off-main

            // Did any bundled dataset change since this install last resolved? Checked once
            // up front; drives both the country re-resolution (Phase 2a) and the city reset
            // (Phase 3a). The new version is persisted only after both complete, so a
            // cancelled scan safely re-runs the migration next time.
            let datasetChanged =
                UserDefaults.standard.integer(forKey: datasetVersionKey) != Self.datasetVersion

            // Phase 2a: if a dataset changed, silently re-resolve countries for all
            // already-geocoded photos so stale codes from an older dataset are corrected.
            if datasetChanged {
                let resolved = ((try? await store.allPhotos()) ?? []).filter { $0.isGeocoded }
                try await resolveCountries(resolved, generation: generation,
                                           statsEngine: statsEngine, homeCode: homeCountryCode, notify: false)
            }

            // Seed the set of countries already known so new-country detection starts clean.
            let stored = (try? await store.allPhotos()) ?? []
            stats = statsEngine.compute(from: stored, homeCountryCode: homeCountryCode, homeCoordinate: homeCoordinate, manualCountries: manualCountries, excludedPhotoIDs: excludedPhotoIDs)
            scanSeenCountryCodes = Set(stored.compactMap { $0.isGeocoded ? $0.countryCode : nil })

            // Phase 2b: resolve countries OFFLINE for new photos (instant, no network).
            let pending = (try? await store.photosNeedingCountry()) ?? []
            try await resolveCountries(pending, generation: generation,
                                       statsEngine: statsEngine, homeCode: homeCountryCode, notify: true)

            // Phase 3a: if a dataset changed, reset every photo's city so the offline resolver
            // re-runs for all of them below (replacing any stale names, e.g. from the old
            // online CLGeocoder pass).
            if datasetChanged {
                try await store.resetCityResolution()
            }

            // Phase 3: enrich with city names offline from the bundled cities1000 dataset.
            try await resolveCities(generation: generation, statsEngine: statsEngine, homeCode: homeCountryCode)

            // Both dataset migrations are complete — record the version so they don't re-run.
            if datasetChanged {
                UserDefaults.standard.set(Self.datasetVersion, forKey: datasetVersionKey)
            }

            await completeScan()

        } catch is CancellationError {
            // Cancelled because the app moved to background — every completed geocode
            // is already persisted row-by-row, so there is nothing to flush.
        } catch {
            scanProgress = .failed(error.localizedDescription)
        }
    }

    /// Offline country resolution for a set of photos, in chunks so the UI updates
    /// as we go. `notify` fires new-country notifications (only for genuinely new
    /// photos — suppressed during a dataset re-resolution of existing photos).
    private func resolveCountries(_ pending: [GeoPhoto],
                                  generation: Int,
                                  statsEngine: StatisticsEngine,
                                  homeCode: String?,
                                  notify: Bool) async throws {
        let store = self.store
        let offline = self.offlineGeocoder
        guard !pending.isEmpty else { return }

        let total = pending.count
        scanProgress = .resolvingCountries(progress: 0, total: total)

        var processed = 0
        for chunk in pending.chunked(into: 500) {
            try Task.checkCancellation()

            let input = chunk.map { (id: $0.id, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
            let matches = await offline.resolve(input)

            // Build persistence rows + ordered list for new-country detection.
            var rows: [(id: String, country: String?, countryCode: String?)] = []
            var detected: [GeoPhoto] = []
            for (index, result) in matches.enumerated() {
                let (id, match) = result
                let code = match?.code
                let name = code.flatMap { Locale.current.localizedString(forRegionCode: $0) } ?? match?.fallbackName
                rows.append((id: id, country: name, countryCode: code))

                var photo = chunk[index]
                photo.country = name
                photo.countryCode = code
                photo.isGeocoded = true
                detected.append(photo)
            }

            try await store.applyCountries(rows)

            processed += chunk.count
            let snapshot = statsEngine.compute(from: (try? await store.allPhotos()) ?? [], homeCountryCode: homeCode, homeCoordinate: homeCoordinate, manualCountries: manualCountries, excludedPhotoIDs: excludedPhotoIDs)
            let progress = Double(processed) / Double(total)
            await MainActor.run {
                guard self.scanGeneration == generation else { return }
                self.scanProgress = .resolvingCountries(progress: progress, total: total)
                self.stats = snapshot
                if notify { for photo in detected { self.handlePossibleNewCountry(photo) } }
            }
        }

        // Core features are done — publish to widgets immediately.
        publishWidgetStats()
    }

    /// Phase 3 — offline city enrichment from the bundled `cities1000` dataset.
    /// No network, no rate limit: every photo is matched to its nearest city in memory,
    /// so even very large libraries resolve near-instantly.
    private func resolveCities(generation: Int, statsEngine: StatisticsEngine, homeCode: String?) async throws {
        let store = self.store
        let pending = (try? await store.photosNeedingCity()) ?? []
        guard !pending.isEmpty else { return }

        let total = pending.count
        scanProgress = .geocoding(progress: 0, total: total)

        var done = 0
        for chunk in pending.chunked(into: 1000) {
            try Task.checkCancellation()
            let input = chunk.map { (id: $0.id, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
            let results = await offlineCityGeocoder.resolve(input)
            for result in results {
                try? await store.applyCity(id: result.id, city: result.city, hasLocality: result.hasLocality)
            }
            done += chunk.count
            let snapshot = statsEngine.compute(from: (try? await store.allPhotos()) ?? [], homeCountryCode: homeCode, homeCoordinate: homeCoordinate, manualCountries: manualCountries, excludedPhotoIDs: excludedPhotoIDs)
            let progress = Double(done) / Double(total)
            await MainActor.run {
                guard self.scanGeneration == generation else { return }
                self.scanProgress = .geocoding(progress: progress, total: total)
                self.stats = snapshot
            }
        }

        try Task.checkCancellation()
        let finalPhotos = (try? await store.allPhotos()) ?? []
        stats = statsEngine.compute(from: finalPhotos, homeCountryCode: homeCode, homeCoordinate: homeCoordinate, manualCountries: manualCountries, excludedPhotoIDs: excludedPhotoIDs)
        memories = MemoriesEngine().memories(from: finalPhotos, homeCoordinate: homeCoordinate,
                                             homeCountryCode: homeCode,
                                             excludedPhotoIDs: excludedPhotoIDs)
    }

    // MARK: - Travel nudges

    private let lastNudgeDateKey = "lastNudgeDate"
    private let notifiedTripIDsKey = "notifiedTripIDs"
    private let notifiedRecapYearsKey = "notifiedRecapYears"

    /// Decide, after a scan, whether to send a (single) tasteful nudge. Conservative:
    /// at most one reactive nudge per 7 days, each thing announced only once.
    private func runNudges() async {
        guard travelNudgesEnabled else { return }
        await maybeNudgeTripReady()
        await maybeScheduleYearRecap()
    }

    /// "Your trip is ready" once you're home from a notable, recent trip.
    private func maybeNudgeTripReady() async {
        // Global 7-day cap on reactive nudges.
        if let last = UserDefaults.standard.object(forKey: lastNudgeDateKey) as? Date,
           Date().timeIntervalSince(last) < 7 * 86_400 { return }

        var notified = Set(UserDefaults.standard.stringArray(forKey: notifiedTripIDsKey) ?? [])
        let now = Date()
        // A trip that ended a couple days ago (likely home), still fresh, and worth sharing.
        let candidate = stats.trips.first { trip in
            let daysSinceEnd = now.timeIntervalSince(trip.endDate) / 86_400
            return daysSinceEnd >= 2 && daysSinceEnd <= 14
                && trip.photoCount >= 12
                && !notified.contains(trip.id)
        }
        guard let trip = candidate else { return }

        notified.insert(trip.id)
        UserDefaults.standard.set(Array(notified), forKey: notifiedTripIDsKey)
        UserDefaults.standard.set(now, forKey: lastNudgeDateKey)
        await NotificationService.notifyTripReady(tripID: trip.id, flag: trip.flag, country: trip.displayName)
    }

    /// Around year-end, schedule the "Year in Travel is ready" nudge for Jan 2
    /// (once per year, only if travelled). Covers December openers (schedules ahead)
    /// and early-January openers who missed December (delivered soon).
    private func maybeScheduleYearRecap() async {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let day = cal.component(.day, from: now)
        let currentYear = cal.component(.year, from: now)

        // The year the recap is about: this year in December, last year in early January.
        let recapYear: Int?
        if month == 12 { recapYear = currentYear }
        else if month == 1 && day <= 7 { recapYear = currentYear - 1 }
        else { recapYear = nil }
        guard let year = recapYear else { return }

        var years = Set(UserDefaults.standard.stringArray(forKey: notifiedRecapYearsKey) ?? [])
        guard !years.contains(String(year)) else { return }
        guard stats.trips.contains(where: { cal.component(.year, from: $0.startDate) == year }) else { return }

        years.insert(String(year))
        UserDefaults.standard.set(Array(years), forKey: notifiedRecapYearsKey)
        await NotificationService.scheduleYearRecap(year: year)
    }

    /// Fire a "new country" notification when a photo taken *today* is the first
    /// we've ever seen in its country. Processing in ascending date order means a
    /// country visited earlier already seeded `scanSeenCountryCodes`, so only a
    /// genuinely new-and-current trip triggers a notification (no initial-import spam).
    private func handlePossibleNewCountry(_ photo: GeoPhoto) {
        guard photo.isGeocoded,
              let code = photo.countryCode, !code.isEmpty,
              let name = photo.country else { return }

        let alreadySeen = scanSeenCountryCodes.contains(code)
        scanSeenCountryCodes.insert(code)

        guard travelNudgesEnabled,                           // master switch
              !alreadySeen,                                  // first sighting in this scan
              Calendar.current.isDateInToday(photo.date),    // taken today
              !notifiedCountryCodes.contains(code)           // not already notified
        else { return }

        var notified = notifiedCountryCodes
        notified.insert(code)
        notifiedCountryCodes = notified

        let flag = photo.flagEmoji
        Task { await NotificationService.notifyNewCountry(code: code, name: name, flag: flag) }
    }

    /// Publish the current stats to the shared App Group container and refresh widgets.
    private func publishWidgetStats() {
        WidgetSharedStore.save(stats.widgetSnapshot(hasLifetime: hasLifetime))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Recompute the travel personality profile off the main actor and cache it.
    /// Skips work when the library signature is unchanged since the last computation.
    private func recomputePersonality() async {
        let photos = (try? await store.allPhotos()) ?? []
        guard !photos.isEmpty else { return }

        let geocodedCount = photos.lazy.filter { $0.isGeocoded }.count
        let home = homeCoordinate
        // Bump the trailing version to force a recompute when scoring logic changes.
        // `insightsEnabled` is part of the signature so toggling Health opt-in recomputes.
        let signature = "v9-\(geocodedCount)-\(stats.trips.count)-\(homeCountryCode ?? "")-\(homeName ?? "")-hk\(insightsEnabled ? 1 : 0)"
        let signatureKey = "personalitySignature"
        if personalityProfile != nil,
           UserDefaults.standard.string(forKey: signatureKey) == signature {
            return
        }

        // Build photoID → wonder id from the current wonder stats.
        var wonderByPhoto: [String: String] = [:]
        for wonder in stats.wonders {
            for id in wonder.photoIDs { wonderByPhoto[id] = wonder.wonder.id }
        }
        // Per-photo offline signals: distance to coast and to the nearest city.
        let pointInput = photos.map { (id: $0.id, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
        let coastByPhoto = await offlineCoastline.distancesKm(pointInput)
        let cityByPhoto = await offlinePlaces.distancesKm(pointInput)

        // Explorer rarity: how remote your away-from-home photos are (distance to the
        // nearest town). Uses the 90th percentile so it reflects your most remote spots.
        let awayRemoteness: [Double] = photos.compactMap { photo in
            if let home {
                let d = photo.coordinate.clLocation.distance(from: home.clLocation) / 1000
                if d <= 50 { return nil }   // exclude everyday photos near home
            }
            return cityByPhoto[photo.id]
        }
        if !awayRemoteness.isEmpty {
            let sorted = awayRemoteness.sorted()
            let p90 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.9))]
            explorerRarity = max(0, min(100, Int((p90 / 60.0 * 100).rounded())))
        } else {
            explorerRarity = 0
        }
        UserDefaults.standard.set(explorerRarity, forKey: "explorerRarity")

        let trips = stats.trips

        // When the user opted into Insights, fold each trip's Health signals (climbs, steps,
        // workouts) into its personality flavour. This uses a lightweight, off-main path —
        // only three cheap aggregates + workout types per trip, no photos / heart rate /
        // routes / authorship — so it never blocks the UI. Degrades to photo-only with no data.
        var healthDirectionByTrip: [String: TravelCategoryScores] = [:]
        if insightsEnabled, HealthKitService.isAvailable {
            for trip in trips {
                if let direction = await healthDirection(for: trip) {
                    healthDirectionByTrip[trip.id] = direction
                }
            }
        }

        let profile = await Task.detached(priority: .utility) {
            TravelPersonalityEngine().makeProfile(photos: photos,
                                                  wonderIDByPhoto: wonderByPhoto,
                                                  coastalDistanceByPhoto: coastByPhoto,
                                                  cityDistanceByPhoto: cityByPhoto,
                                                  trips: trips,
                                                  home: home,
                                                  healthDirectionByTrip: healthDirectionByTrip)
        }.value

        personalityProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: personalityCacheKey)
        }
        UserDefaults.standard.set(signature, forKey: "personalitySignature")
    }

    private func completeScan() async {
        publishWidgetStats()
        await runNudges()
        await recomputePersonality()
        withAnimation { scanProgress = .complete }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        withAnimation(.easeOut(duration: 0.4)) { scanProgress = .idle }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
