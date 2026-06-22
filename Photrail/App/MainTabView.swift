import SwiftUI

/// The post-onboarding tab bar: Home (dashboard) + Me (profile).
/// Uses the system tab bar, which renders as the translucent "glass" material.
struct MainTabView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        @Bindable var appVM = appVM
        TabView(selection: $appVM.selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "map.fill") }
                .tag(AppViewModel.AppTab.home)

            ProfileView()
                .tabItem { Label("Me", systemImage: "person.fill") }
                .tag(AppViewModel.AppTab.me)
        }
    }
}
