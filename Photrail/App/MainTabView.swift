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
        .onAppear { applyPendingIntent() }             // cold launch from an intent
        .onChange(of: router.pendingTab) { _, _ in applyPendingIntent() }
        .onChange(of: router.openYearRecap) { _, _ in applyPendingIntent() }
        .onChange(of: router.pendingTripID) { _, _ in applyPendingIntent() }
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
        applyPendingTrip()
    }

    /// Open the trip a Spotlight result / Siri asked for, if we can resolve it yet.
    ///
    /// The id is only cleared once a trip is found — on a cold launch this runs before the scan
    /// has populated `stats.trips`, and dropping the request there would open nothing at all.
    private func applyPendingTrip() {
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
