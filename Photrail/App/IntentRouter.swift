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
    /// A trip a Spotlight result / Siri asked to open, by `Trip.id`.
    ///
    /// Unlike the flags above this is *not* cleared on the first attempt: a cold launch applies
    /// pending intents before the scan has produced any trips, so it has to survive until
    /// `stats.trips` can actually resolve it.
    var pendingTripID: String?
}
