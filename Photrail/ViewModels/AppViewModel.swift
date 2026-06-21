import Foundation
import Photos
import SwiftUI

/// Root state machine for the app.
/// Every screen observes this single source of truth.
@MainActor
@Observable
final class AppViewModel {
    enum State {
        case onboarding
        case requestingPermission
        case scanning(progress: Double, found: Int)
        case geocoding(progress: Double, total: Int)
        case ready(TravelStats)
        case permissionDenied
        case error(String)
    }

    var state: State = .onboarding
    var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenOnboarding") }
    }

    private let scanService = PhotoScanService()
    private let geocodingService = GeocodingService()
    private let cacheService = CacheService()
    private let statsEngine = StatisticsEngine()

    func startOnboarding() {
        if hasSeenOnboarding {
            Task { await checkPermissionAndScan() }
        }
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
        Task { await requestPermissionAndScan() }
    }

    func retryPermission() {
        Task { await requestPermissionAndScan() }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Private

    private func checkPermissionAndScan() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            await runScan()
        case .denied, .restricted:
            state = .permissionDenied
        case .notDetermined:
            state = .onboarding
        @unknown default:
            state = .onboarding
        }
    }

    private func requestPermissionAndScan() async {
        state = .requestingPermission
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized, .limited:
            await runScan()
        case .denied, .restricted:
            state = .permissionDenied
        case .notDetermined:
            state = .onboarding
        @unknown default:
            state = .permissionDenied
        }
    }

    private func runScan() async {
        do {
            state = .scanning(progress: 0, found: 0)

            // Phase 1: Extract GPS coordinates
            var rawPhotos = try await scanService.scanIfNeeded()

            // Phase 2: Geocode any photos that haven't been geocoded yet
            let needsGeocoding = rawPhotos.filter { !$0.isGeocoded }
            if !needsGeocoding.isEmpty {
                state = .geocoding(progress: 0, total: needsGeocoding.count)
                let geocoded = await geocodingService.geocodeBatch(needsGeocoding) { done in
                    Task { @MainActor [weak self] in
                        self?.state = .geocoding(progress: Double(done) / Double(needsGeocoding.count),
                                                  total: needsGeocoding.count)
                    }
                }
                // Merge geocoded results back
                let geocodedByID = Dictionary(uniqueKeysWithValues: geocoded.map { ($0.id, $0) })
                rawPhotos = rawPhotos.map { geocodedByID[$0.id] ?? $0 }
                try? await cacheService.savePhotos(rawPhotos)
            }

            let stats = statsEngine.compute(from: rawPhotos)
            state = .ready(stats)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
