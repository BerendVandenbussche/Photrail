import Foundation
import BackgroundTasks

/// Manages scheduling and execution of the background photo scan.
///
/// BGProcessingTask is the right primitive here — it allows long-running work
/// (geocoding can take many minutes) and can require network access.
/// The system decides the exact time it fires, typically overnight while charging.
struct BackgroundTaskService {
    static let scanTaskID = "com.berend.photrail.scan"

    // MARK: - Registration (call once at app launch, before the first runloop cycle)

    static func registerHandlers(scanHandler: @escaping () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: scanTaskID, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            handleScanTask(processingTask, scanHandler: scanHandler)
        }
    }

    // MARK: - Scheduling

    /// Schedule a background scan. Call when the app moves to the background
    /// and a scan is in progress or the library may have changed.
    static func scheduleBackgroundScan() {
        let request = BGProcessingTaskRequest(identifier: scanTaskID)
        // Geocoding requires network (CLGeocoder uses Apple's servers)
        request.requiresNetworkConnectivity = true
        // Don't require charging — geocoding is light on battery
        request.requiresExternalPower = false
        // Ask to run within the next few minutes if possible
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch let error as BGTaskScheduler.Error where error.code == .notPermitted {
            print("[BGTask] Not permitted. Check BGTaskSchedulerPermittedIdentifiers in Info.plist.")
        } catch let error as BGTaskScheduler.Error where error.code == .tooManyPendingTaskRequests {
            // Already scheduled — safe to ignore
        } catch {
            print("[BGTask] Failed to schedule: \(error)")
        }
    }

    static func cancelPendingScans() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: scanTaskID)
    }

    // MARK: - Execution

    private static func handleScanTask(_ task: BGProcessingTask,
                                       scanHandler: @escaping () async -> Void) {
        // Re-schedule for next time before doing any work
        scheduleBackgroundScan()

        let workTask = Task {
            await scanHandler()
            task.setTaskCompleted(success: true)
        }

        // iOS calls this when time is almost up. Cancel the Swift task so it
        // stops cleanly; the SwiftData store has already persisted progress row-by-row.
        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
