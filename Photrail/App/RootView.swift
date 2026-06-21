import SwiftUI

/// Root view: drives the full state machine from AppViewModel.
/// Transitions between onboarding, scanning, and the main dashboard.
struct RootView: View {
    @State private var appVM = AppViewModel()

    var body: some View {
        Group {
            switch appVM.state {
            case .onboarding, .requestingPermission:
                OnboardingView()
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))

            case .scanning(let progress, let found):
                ScanProgressView(progress: progress, found: found, label: "Scanning your library…")
                    .transition(.opacity)

            case .geocoding(let progress, let total):
                ScanProgressView(
                    progress: progress,
                    found: Int(Double(total) * progress),
                    label: "Identifying locations…"
                )
                .transition(.opacity)

            case .ready(let stats):
                DashboardView(stats: stats)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))

            case .permissionDenied:
                PermissionDeniedView()
                    .transition(.opacity)

            case .error(let message):
                ErrorView(message: message) {
                    Task { await appVM.retryPermission() }
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: appVM.state.id)
        .environment(appVM)
        .onAppear {
            appVM.startOnboarding()
        }
    }
}

// MARK: - Error view

private struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Something went wrong")
                .font(.title2.weight(.bold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

// Make AppViewModel.State conform to Equatable for the animation value
extension AppViewModel.State {
    var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .requestingPermission: return "requesting"
        case .scanning: return "scanning"
        case .geocoding: return "geocoding"
        case .ready: return "ready"
        case .permissionDenied: return "denied"
        case .error: return "error"
        }
    }
}

#Preview {
    RootView()
}
