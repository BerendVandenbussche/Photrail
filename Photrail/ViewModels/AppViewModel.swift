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
    var stats: TravelStats = .empty
    /// "On this day" memories for today — photos from this calendar day in past years.
    var memories: [Memory] = []

    /// Countries the user added by hand (photos deleted / never on device). Persisted.
    var manualCountries: [ManualCountry] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(manualCountries) {
                UserDefaults.standard.set(data, forKey: "manualCountries")
            }
        }
    }

    /// Selected bottom-tab; mutable so other views (e.g. the "set home" CTA) can switch tabs.
    var selectedTab: AppTab = .today

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

    /// Optional home city (CityStat.id) for a more precise origin in large countries.
    var homeCityID: String? {
        didSet {
            UserDefaults.standard.set(homeCityID, forKey: "homeCityID")
            Task { await recomputePersonality() }
        }
    }

    struct FurthestTrip { let trip: Trip; let distanceKm: Double }

    /// Display name for the configured home (city + country, or just country).
    var homeDisplayName: String? {
        if let cityID = homeCityID, let city = stats.allCities.first(where: { $0.id == cityID }) {
            return "\(city.name), \(city.country)"
        }
        if let code = homeCountryCode, let country = stats.countries.first(where: { $0.id == code }) {
            return country.name
        }
        return nil
    }

    /// Coordinate used as the origin for distance calculations — the home city if set,
    /// otherwise the home country's representative coordinate.
    var homeCoordinate: GeoPhoto.Coordinate? {
        if let cityID = homeCityID, let city = stats.allCities.first(where: { $0.id == cityID }) {
            return city.representativeCoordinate
        }
        if let code = homeCountryCode, let country = stats.countries.first(where: { $0.id == code }) {
            return country.representativeCoordinate
        }
        return nil
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
    private let geocodingService = GeocodingService()
    private let offlineGeocoder = OfflineCountryGeocoder()
    private let offlineCoastline = OfflineCoastline()
    private let offlinePlaces = OfflinePlaces()
    private let photoCurator = PhotoCurator()
    private let store: PhotoStore
    private let statsEngine = StatisticsEngine()

    private let changeTokenKey = "lastChangeToken"
    private let countryDatasetVersionKey = "countryDatasetVersion"
    // Bump this whenever the bundled countries.geojson (or resolution logic) changes,
    // to force a one-time silent re-resolution of all photos' countries on next scan.
    private static let countryDatasetVersion = 2

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
        self.homeCountryCode = UserDefaults.standard.string(forKey: "homeCountryCode")
        self.homeCityID = UserDefaults.standard.string(forKey: "homeCityID")
        self.profileEmoji = UserDefaults.standard.string(forKey: "profileEmoji") ?? "🧭"
        if let data = UserDefaults.standard.data(forKey: personalityCacheKey),
           let cached = try? JSONDecoder().decode(TravelPersonalityProfile.self, from: data) {
            self.personalityProfile = cached
        }
        if let data = UserDefaults.standard.data(forKey: "manualCountries"),
           let decoded = try? JSONDecoder().decode([ManualCountry].self, from: data) {
            self.manualCountries = decoded
        }
        // Skip the onboarding flash on relaunch: if the user already onboarded,
        // start straight on the dashboard. The async permission check still runs
        // and will redirect to .permissionDenied if access was revoked.
        if UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            self.navState = .dashboard
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

    private func refreshStatsWithManual() async {
        let photos = (try? await store.allPhotos()) ?? []
        stats = statsEngine.compute(from: photos, homeCountryCode: homeCountryCode,
                                    homeCoordinate: homeCoordinate, manualCountries: manualCountries)
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
                                            homeCoordinate: homeCoordinate)

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
            .map { .init(id: $0.id, name: $0.name, flag: $0.flag) }

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

        // Vision-curated best shots from the top destination (the country shown on the
        // "Top destination" slide), so the header and photos always match. Ranked on-device
        // by aesthetics + personality match, minus people/pet/screenshots.
        let topDestination = yearStats.countries
            .filter { $0.id != homeCountryCode }
            .max { $0.photoCount < $1.photoCount }
        let candidateIDs = Array((topDestination?.photoIDs ?? []).prefix(80))
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
                stats = statsEngine.compute(from: stored, homeCountryCode: homeCountryCode, homeCoordinate: homeCoordinate, manualCountries: manualCountries)
                memories = MemoriesEngine().memories(from: stored, homeCoordinate: homeCoordinate,
                                                     homeCountryCode: homeCountryCode)
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

            // Phase 2a: if the boundary dataset changed, silently re-resolve countries for
            // all already-geocoded photos so stale codes from an older dataset are corrected.
            // Cities are kept as-is.
            let storedVersion = UserDefaults.standard.integer(forKey: countryDatasetVersionKey)
            if storedVersion != Self.countryDatasetVersion {
                let resolved = ((try? await store.allPhotos()) ?? []).filter { $0.isGeocoded }
                try await resolveCountries(resolved, generation: generation,
                                           statsEngine: statsEngine, homeCode: homeCountryCode, notify: false)
                UserDefaults.standard.set(Self.countryDatasetVersion, forKey: countryDatasetVersionKey)
            }

            // Seed the set of countries already known so new-country detection starts clean.
            let stored = (try? await store.allPhotos()) ?? []
            stats = statsEngine.compute(from: stored, homeCountryCode: homeCountryCode, homeCoordinate: homeCoordinate, manualCountries: manualCountries)
            scanSeenCountryCodes = Set(stored.compactMap { $0.isGeocoded ? $0.countryCode : nil })

            // Phase 2b: resolve countries OFFLINE for new photos (instant, no network).
            let pending = (try? await store.photosNeedingCountry()) ?? []
            try await resolveCountries(pending, generation: generation,
                                       statsEngine: statsEngine, homeCode: homeCountryCode, notify: true)

            // Phase 3: enrich with city names via CLGeocoder (rate-limited, optional).
            try await resolveCities(generation: generation, statsEngine: statsEngine, homeCode: homeCountryCode)

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
            let snapshot = statsEngine.compute(from: (try? await store.allPhotos()) ?? [], homeCountryCode: homeCode, homeCoordinate: homeCoordinate, manualCountries: manualCountries)
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

    /// Phase 3 — optional city enrichment via CLGeocoder (rate-limited).
    private func resolveCities(generation: Int, statsEngine: StatisticsEngine, homeCode: String?) async throws {
        let store = self.store
        let manual = manualCountries   // capture copies; the batch closure runs off the main actor
        let home = homeCoordinate
        let pending = (try? await store.photosNeedingCity()) ?? []
        guard !pending.isEmpty else { return }

        let total = pending.count
        scanProgress = .geocoding(progress: 0, total: total)

        await geocodingService.cityBatch(pending) { [weak self] done, id, result in
            try? await store.applyCity(id: id, city: result.city, hasLocality: result.hasLocality)
            var refreshed: TravelStats?
            if done % 25 == 0 || done == total {
                refreshed = statsEngine.compute(from: (try? await store.allPhotos()) ?? [], homeCountryCode: homeCode, homeCoordinate: home, manualCountries: manual)
            }
            let snapshot = refreshed
            await MainActor.run {
                guard let self, self.scanGeneration == generation else { return }
                self.scanProgress = .geocoding(progress: Double(done) / Double(total), total: total)
                if let snapshot { self.stats = snapshot }
            }
        }

        try Task.checkCancellation()
        let finalPhotos = (try? await store.allPhotos()) ?? []
        stats = statsEngine.compute(from: finalPhotos, homeCountryCode: homeCode, homeCoordinate: homeCoordinate, manualCountries: manualCountries)
        memories = MemoriesEngine().memories(from: finalPhotos, homeCoordinate: homeCoordinate,
                                             homeCountryCode: homeCode)
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

        guard !alreadySeen,                                  // first sighting in this scan
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
        WidgetSharedStore.save(stats.widgetSnapshot())
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
        let signature = "v6-\(geocodedCount)-\(stats.trips.count)-\(homeCountryCode ?? "")-\(homeCityID ?? "")"
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

        let trips = stats.trips
        let profile = await Task.detached(priority: .utility) {
            TravelPersonalityEngine().makeProfile(photos: photos,
                                                  wonderIDByPhoto: wonderByPhoto,
                                                  coastalDistanceByPhoto: coastByPhoto,
                                                  cityDistanceByPhoto: cityByPhoto,
                                                  trips: trips,
                                                  home: home)
        }.value

        personalityProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: personalityCacheKey)
        }
        UserDefaults.standard.set(signature, forKey: "personalitySignature")
    }

    private func completeScan() async {
        publishWidgetStats()
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
