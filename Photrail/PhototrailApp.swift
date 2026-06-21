import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct PhotrailApp: App {
    // Stored (not @State) so they exist before body is evaluated,
    // allowing us to capture appVM in the BGTask handler during init().
    private let modelContainer: ModelContainer
    private let appVM: AppViewModel

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: StoredPhoto.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
        self.modelContainer = container
        let vm = AppViewModel(store: PhotoStore(modelContainer: container))
        self.appVM = vm

        BackgroundTaskService.registerHandlers { [vm] in
            await vm.runBackgroundScan()
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
