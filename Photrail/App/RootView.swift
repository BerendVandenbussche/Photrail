import SwiftUI
import AppIntents
import CoreSpotlight

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
        // Tapping a Spotlight result does *not* run `OpenTripIntent` — indexed entities are
        // handed back as a user activity, and without this the tap just cold-opens the app.
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let id = tripID(from: activity) else { return }
            IntentRouter.shared.pendingTripID = id
        }
    }

    /// Recover the `Trip.id` from a tapped Spotlight result.
    ///
    /// `indexAppEntities` stores a namespaced identifier (entity type + id), not the bare trip
    /// id, so it has to be parsed back out. The raw string is kept as a fallback in case the
    /// activity came from somewhere that wrote the identifier directly.
    private func tripID(from activity: NSUserActivity) -> String? {
        guard let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        return EntityIdentifier(activityIdentifier: raw)?.identifier ?? raw
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
