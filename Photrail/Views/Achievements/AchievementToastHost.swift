import SwiftUI

/// App-wide overlay that announces newly-unlocked achievements one at a time. Attached once
/// at the root; reads the queue from `AppViewModel`. Shares its look with the shareable video
/// card via `AchievementTheme`.
struct AchievementToastHost: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ZStack {
            if let achievement = appVM.achievementQueue.first {
                AchievementToast(achievement: achievement) {
                    appVM.dismissTopAchievement()
                }
                .id(achievement.id)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appVM.achievementQueue.first?.id)
    }
}

private struct AchievementToast: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 14) {
                Text(achievement.emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Achievement unlocked")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(achievement.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(achievement.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(AchievementTheme.gradient,
                        in: RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .task {
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            onDismiss()
        }
    }
}
