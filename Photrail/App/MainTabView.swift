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
        .onAppear { applyPendingIntent() }             // cold launch from an intent
        .onChange(of: router.pendingTab) { _, _ in applyPendingIntent() }
        .onChange(of: router.openYearRecap) { _, _ in applyPendingIntent() }
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
    }
}
