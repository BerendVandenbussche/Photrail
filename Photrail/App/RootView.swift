import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch appVM.navState {
            case .onboarding:
                OnboardingView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .mapReveal:
                MapRevealView()
                    .transition(.opacity)

            case .dashboard:
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))

            case .permissionDenied:
                PermissionDeniedView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: appVM.navState.id)
        .overlay(alignment: .top) {
            if appVM.navState.id == "dashboard" { AchievementToastHost() }
        }
        .onAppear {
            appVM.startOnboarding()
            // Backstop for exports whose share sheet never reported completion (app killed
            // mid-share). Each one is several megabytes.
            ShareVideoFile.purge()
        }
        .onChange(of: scenePhase) { _, phase in
            appVM.handleScenePhase(phase)
        }
    }
}

extension AppViewModel.NavState {
    var id: String {
        switch self {
        case .onboarding:      return "onboarding"
        case .mapReveal:       return "mapReveal"
        case .dashboard:       return "dashboard"
        case .permissionDenied: return "denied"
        }
    }
}

#Preview {
    RootView()
}
