import SwiftUI

/// App-wide overlay announcing newly-unlocked achievements. Attached once at the root; reads
/// the queue from `AppViewModel`. Shares its look with the shareable video card via
/// `AchievementTheme`.
///
/// Two rules keep this out of the user's way:
///
/// * **Nothing is announced during a scan.** The first scan after onboarding unlocks everything
///   the library already earned, and `stats` is reassigned once per geocoding chunk — so
///   announcing as they arrive means a queue of banners, one after another, over a dashboard the
///   user is trying to look at. Waiting until the scan settles lets them be summarised instead.
/// * **A batch becomes one banner.** More than one at a time collapses into a single "N
///   achievements unlocked" that opens the list, rather than N banners to sit through.
struct AchievementToastHost: View {
    @Environment(AppViewModel.self) private var appVM

    /// Hold announcements until the scan settles, so a batch can be summarised as one.
    private var pending: [Achievement] {
        appVM.scanProgress.isActive ? [] : appVM.achievementQueue
    }

    var body: some View {
        ZStack {
            if pending.count > 1 {
                AchievementBanner(
                    emoji: "🏆",
                    kicker: "Achievements unlocked",
                    title: "\(pending.count) new achievements",
                    detail: "Tap to see what you've earned",
                    onTap: { appVM.openAchievements() },
                    onDismiss: { appVM.dismissAllAchievements() }
                )
                .id("summary-\(pending.count)")
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if let achievement = pending.first {
                AchievementBanner(
                    emoji: achievement.emoji,
                    kicker: "Achievement unlocked",
                    title: achievement.title,
                    detail: achievement.detail,
                    onTap: { appVM.openAchievements() },
                    onDismiss: { appVM.dismissTopAchievement() }
                )
                .id(achievement.id)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pending.count)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pending.first?.id)
    }
}

private struct AchievementBanner: View {
    let emoji: String
    let kicker: LocalizedStringKey
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 3) {
                    Text(kicker)
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(detail)
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
            // Only the card itself takes touches. The enclosing VStack fills the screen (the
            // Spacer pins the card to the top), so making *that* tappable swallowed every scroll
            // and tap on the dashboard underneath for as long as a banner was up.
            .contentShape(.rect)
            .onTapGesture { onTap() }
            .accessibilityAddTraits(.isButton)
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            onDismiss()
        }
    }
}
