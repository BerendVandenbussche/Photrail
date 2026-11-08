import SwiftUI

/// The post-onboarding tab bar: Today · Map · Places · Me.
/// Uses the system tab bar, which renders as the translucent "glass" material.
struct MainTabView: View {
    @Environment(AppViewModel.self) private var appVM
    private let router = IntentRouter.shared

    var body: some View {
        @Bindable var appVM = appVM
        TabView(selection: $appVM.selectedTab) {
            DashboardView()
                .tabItem { Label("Today", systemImage: "sparkles") }
                .tag(AppViewModel.AppTab.today)

            MapTabView()
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(AppViewModel.AppTab.map)

            PlacesView()
                .tabItem { Label("Places", systemImage: "globe.europe.africa.fill") }
                .tag(AppViewModel.AppTab.places)

            ProfileView()
                .tabItem { Label("Me", systemImage: "person.fill") }
                .tag(AppViewModel.AppTab.me)
        }
        .sheet(item: $appVM.presentedRecap) { recap in RecapView(recap: recap) }
        .sheet(item: $appVM.presentedWhatsNew) { announcement in
            WhatsNewView(announcement: announcement)
        }
        // `TripDetailView` sets its own navigation title, toolbar and pushes a stop detail,
        // so it needs a stack of its own when it isn't reached by a NavigationLink.
        .sheet(item: $appVM.presentedTrip) { trip in
            NavigationStack {
                TripDetailView(trip: trip)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { appVM.presentedTrip = nil }
                        }
                    }
            }
        }
        // `AchievementsView` sets its own navigation title, so it needs a stack of its own when
        // it isn't reached by the NavigationLink in Profile.
        .sheet(isPresented: $appVM.presentedAchievements) {
            NavigationStack {
                AchievementsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { appVM.presentedAchievements = false }
                        }
                    }
            }
        }
        .onAppear { applyPendingIntent() }             // cold launch from an intent
        .onChange(of: router.pendingTab) { _, _ in applyPendingIntent() }
        .onChange(of: router.openYearRecap) { _, _ in applyPendingIntent() }
        .onChange(of: router.pendingTripID) { _, _ in applyPendingIntent() }
        .onChange(of: router.pendingPlannedTripID) { _, _ in applyPendingIntent() }
        .onChange(of: router.pendingTripDuring) { _, _ in applyPendingIntent() }
        .sheet(item: $appVM.planEditor, onDismiss: {
            if let id = appVM.planToShowAfterEditor {
                appVM.planToShowAfterEditor = nil
                appVM.showPlannedTrip(id: id)
            }
        }) { request in
            PlannedTripEditorView(existing: request.existing, countryCode: request.countryCode)
        }
        .sheet(item: $appVM.presentedPlan) { request in
            NavigationStack {
                PlannedTripDetailView(planID: request.id)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { appVM.presentedPlan = nil }
                        }
                    }
            }
        }
        // A cold launch applies the intent before the scan has produced any trips, so retry
        // once the trips actually arrive.
        .onChange(of: appVM.stats.trips.count) { _, _ in applyPendingTrip() }
    }

    /// Apply any navigation an App Intent requested (tab switch / open recap).
    private func applyPendingIntent() {
        if let tab = router.pendingTab {
            appVM.selectedTab = tab
            router.pendingTab = nil
        }
        if router.openYearRecap {
            router.openYearRecap = false
            Task { appVM.presentedRecap = await appVM.makeYearRecap() }
        }
        if let id = router.pendingPlannedTripID {
            router.pendingPlannedTripID = nil
            // Gone when the user deleted it, or it was retired after the trip: nothing to open.
            if appVM.plannedTrips.contains(where: { $0.id == id }) {
                appVM.showPlannedTrip(id: id)
            }
        }
        applyPendingTrip()
    }

    /// Open the trip a Spotlight result / Siri asked for, if we can resolve it yet.
    ///
    /// The id is only cleared once a trip is found — on a cold launch this runs before the scan
    /// has populated `stats.trips`, and dropping the request there would open nothing at all.
    private func applyPendingTrip() {
        if let range = router.pendingTripDuring {
            if let trip = PlannedTrip.matchingTrip(from: range.lowerBound, to: range.upperBound,
                                                   in: appVM.stats.trips) {
                router.pendingTripDuring = nil
                appVM.presentedTrip = trip
            }
        }
        guard let id = router.pendingTripID, let trip = resolveTrip(id: id) else { return }
        router.pendingTripID = nil
        appVM.presentedTrip = trip
    }

    /// Exact id first, then the trip whose date range contains it.
    ///
    /// Ids are `trip-YYYY-MM-DD` derived from the start date, and trips are re-derived on every
    /// scan — importing an older photo moves the boundary and reassigns the id, which would
    /// otherwise leave an indexed result resolving to nothing.
    private func resolveTrip(id: String) -> Trip? {
        let trips = appVM.stats.trips
        if let exact = trips.first(where: { $0.id == id }) { return exact }
        guard let date = TripSearchStore.startDate(fromID: id) else { return nil }
        return trips.first { date >= $0.startDate && date <= $0.endDate }
    }
}
