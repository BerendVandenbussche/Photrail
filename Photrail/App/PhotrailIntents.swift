import AppIntents

/// Siri / Shortcuts / Spotlight entry points. Available since iOS 16, so they work
/// on the app's iOS 18 minimum with no version bump. Newer-iOS-only capabilities can
/// be layered on later behind `@available` checks without raising the deployment target.

struct ShowTravelMapIntent: AppIntent {
    static let title: LocalizedStringResource = "Show my travel map"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.pendingTab = .map
        return .result()
    }
}

struct ShowPlacesIntent: AppIntent {
    static let title: LocalizedStringResource = "Show my places"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.pendingTab = .places
        return .result()
    }
}

struct OpenYearInTravelIntent: AppIntent {
    static let title: LocalizedStringResource = "Open my Year in Travel"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.pendingTab = .today
        IntentRouter.shared.openYearRecap = true
        return .result()
    }
}

/// Opens a specific trip. Powers Spotlight result taps as well as Siri and Shortcuts —
/// `TripEntity` is `IndexedEntity`, so a tapped search result runs this intent.
struct OpenTripIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a trip"
    static let openAppWhenRun = true

    @Parameter(title: "Trip")
    var trip: TripEntity

    init() {}
    init(trip: TripEntity) { self.trip = trip }

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$trip)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.pendingTripID = trip.id
        return .result()
    }
}

/// Exposes the intents to Siri / Spotlight with spoken phrases.
struct PhotrailShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ShowTravelMapIntent(),
                    phrases: ["Show my travel map in \(.applicationName)",
                              "Open my map in \(.applicationName)"],
                    shortTitle: "Travel Map",
                    systemImageName: "map")
        AppShortcut(intent: OpenYearInTravelIntent(),
                    phrases: ["Open my Year in Travel in \(.applicationName)",
                              "Show my \(.applicationName) recap"],
                    shortTitle: "Year in Travel",
                    systemImageName: "sparkles")
        AppShortcut(intent: ShowPlacesIntent(),
                    phrases: ["Show my places in \(.applicationName)"],
                    shortTitle: "Places",
                    systemImageName: "globe.europe.africa.fill")
        AppShortcut(intent: OpenTripIntent(),
                    phrases: ["Open my \(\.$trip) trip in \(.applicationName)",
                              "Show my \(\.$trip) trip in \(.applicationName)"],
                    shortTitle: "Open Trip",
                    systemImageName: "airplane")
    }
}
