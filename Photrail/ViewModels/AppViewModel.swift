import Foundation
import Photos
import SwiftUI
import SwiftData

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

    var navState: NavState = .onboarding
    var scanProgress: ScanProgress = .idle
    var stats: TravelStats = .empty

    /// True whenever a scan is running or queued — used to schedule/cancel BGProcessingTask.
    var isScanNeeded: Bool {
        switch scanProgress {
        case .scanning, .geocoding: return true
        default: return false
        }
    }

    var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenOnboarding") }
    }

    private let scanService = PhotoScanService()
    private let geocodingService = GeocodingService()
    private let store: PhotoStore
    private let statsEngine = StatisticsEngine()

    private let changeTokenKey = "lastChangeToken"

    // Tracks the active foreground scan task so we can cancel it on background
    private var foregroundScanTask: Task<Void, Never>?
    // Incremented on every new scan; progress closures from a cancelled scan bail when mismatched
    private var scanGeneration = 0

    init(store: PhotoStore) {
        self.store = store
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
                stats = statsEngine.compute(from: stored)
            }
        }
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

            // Show whatever is already stored while geocoding continues
            stats = statsEngine.compute(from: (try? await store.allPhotos()) ?? [])

            // Phase 2: reverse geocode every row still missing location data.
            // Each result is written to its own row immediately, so progress is
            // durable — closing or killing the app resumes exactly where it left off.
            let needsGeocoding = (try? await store.photosNeedingGeocoding()) ?? []
            if needsGeocoding.isEmpty {
                await completeScan()
                return
            }

            let total = needsGeocoding.count
            let statsEngine = self.statsEngine   // Sendable; captured so we can compute off-main
            scanProgress = .geocoding(progress: 0, total: total)

            await geocodingService.geocodeBatch(needsGeocoding) { [weak self] done, photo in
                // Persist this result before continuing to the next lookup.
                try? await store.applyGeocode(id: photo.id,
                                              country: photo.country,
                                              countryCode: photo.countryCode,
                                              city: photo.city)
                // Recompute stats periodically (and on the final photo) off the main actor.
                var refreshed: TravelStats?
                if done % 25 == 0 || done == total {
                    refreshed = statsEngine.compute(from: (try? await store.allPhotos()) ?? [])
                }
                let snapshot = refreshed
                await MainActor.run {
                    guard let self, self.scanGeneration == generation else { return }
                    self.scanProgress = .geocoding(progress: Double(done) / Double(total), total: total)
                    if let snapshot { self.stats = snapshot }
                }
            }

            try Task.checkCancellation()

            stats = statsEngine.compute(from: (try? await store.allPhotos()) ?? [])
            await completeScan()

        } catch is CancellationError {
            // Cancelled because the app moved to background — every completed geocode
            // is already persisted row-by-row, so there is nothing to flush.
        } catch {
            scanProgress = .failed(error.localizedDescription)
        }
    }

    private func completeScan() async {
        withAnimation { scanProgress = .complete }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        withAnimation(.easeOut(duration: 0.4)) { scanProgress = .idle }
    }
}
