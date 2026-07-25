import SwiftUI

/// The full achievements grid, opened from the Me tab. Earned milestones show their
/// emoji, title and how they were earned; unearned ones stay secret as mystery tiles.
struct AchievementsView: View {
    @Environment(AppViewModel.self) private var appVM

    private var stats: TravelStats { appVM.stats }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var unlockedCount: Int { appVM.unlockedAchievementIDs.count }
    private var total: Int { AchievementCatalog.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AchievementCatalog.all) { achievement in
                        AchievementTile(achievement: achievement,
                                        unlocked: appVM.unlockedAchievementIDs.contains(achievement.id))
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        let fraction = total == 0 ? 0 : Double(unlockedCount) / Double(total)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🏆").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(unlockedCount) of \(total) unlocked")
                        .font(.headline)
                    Text("Keep exploring to reveal more")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(Color.accentColor)
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
        }
        .padding(AppCard.padding)
        .card()
    }
}

private struct AchievementTile: View {
    let achievement: Achievement
    let unlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(unlocked ? achievement.emoji : "🔒")
                .font(.system(size: 34))
                .grayscale(unlocked ? 0 : 1)
                .opacity(unlocked ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 4) {
                Text(unlocked ? achievement.title : "???")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(unlocked ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(unlocked ? achievement.detail : "Keep exploring to unlock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .padding(AppCard.padding)
        .background(
            RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous)
                .fill(unlocked ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous)
                .strokeBorder(unlocked ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        AchievementsView().environment(AppViewModel.preview)
    }
}
