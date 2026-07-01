import SwiftUI

/// The post-onboarding tab bar: Today · Map · Places · Me.
/// Uses the system tab bar, which renders as the translucent "glass" material.
struct MainTabView: View {
    @Environment(AppViewModel.self) private var appVM

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
    }
}
