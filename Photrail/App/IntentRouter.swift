import Foundation

/// A tiny bridge between App Intents (Siri / Shortcuts / Spotlight) and the running
/// UI. Intents set a pending action here; `MainTabView` observes it and navigates.
@MainActor
@Observable
final class IntentRouter {
    static let shared = IntentRouter()
    private init() {}

    /// A tab an intent wants to open.
    var pendingTab: AppViewModel.AppTab?
    /// Set when an intent asks to open the Year in Travel recap.
    var openYearRecap = false
}
