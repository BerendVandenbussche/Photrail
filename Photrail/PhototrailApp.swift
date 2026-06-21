import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications

@main
struct PhotrailApp: App {
    // Stored (not @State) so they exist before body is evaluated,
    // allowing us to capture appVM in the BGTask handler during init().
    private let modelContainer: ModelContainer
    private let appVM: AppViewModel
    private let notificationDelegate = NotificationDelegate()

    init() {
        let container = Self.makeContainer()
        self.modelContainer = container
        let vm = AppViewModel(store: PhotoStore(modelContainer: container))
        self.appVM = vm

        UNUserNotificationCenter.current().delegate = notificationDelegate

        BackgroundTaskService.registerHandlers { [vm] in
            await vm.runBackgroundScan()
        }
    }

    /// Build the SwiftData container. The store is a derived cache (rebuildable by
    /// re-scanning the photo library), so if a schema migration fails we wipe and
    /// recreate it rather than crashing.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([StoredPhoto.self])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Remove the on-disk store (and its WAL/SHM sidecars), then retry.
            let storeURL = config.url
            let fm = FileManager.default
            for suffix in ["", "-wal", "-shm"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                try? fm.removeItem(at: url)
            }
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Failed to create SwiftData ModelContainer after reset: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appVM)
                .modelContainer(modelContainer)
                .onChange(of: appVM.isScanNeeded) { _, needed in
                    if needed {
                        BackgroundTaskService.scheduleBackgroundScan()
                    } else {
                        BackgroundTaskService.cancelPendingScans()
                    }
                }
        }
    }
}
