import SwiftUI

/// App-wide overlay that celebrates newly-unlocked achievements one at a time with a
/// confetti toast. Attached once at the root; reads the queue from `AppViewModel`.
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

    private let gradient = LinearGradient(
        colors: [Color(red: 0.31, green: 0.27, blue: 0.9),
                 Color(red: 0.55, green: 0.3, blue: 0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

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
            .background(gradient, in: RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous))
            .overlay(ConfettiView().allowsHitTesting(false))
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

// MARK: - Confetti

private struct ConfettiView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<50, id: \.self) { index in
                    ConfettiPiece(index: index, size: geo.size)
                }
            }
        }
    }
}

private struct ConfettiPiece: View {
    let index: Int
    let size: CGSize
    @State private var fall = false

    private let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .cyan, .pink, .white]

    /// Deterministic pseudo-random in 0...1 so pieces don't jump when the body re-renders.
    private func rnd(_ salt: Int) -> Double {
        let x = sin(Double(index &* 928_371 &+ salt &* 12_959)) * 43_758.545
        return x - floor(x)
    }

    var body: some View {
        let startX = rnd(1) * max(size.width, 1)
        let delay = rnd(2) * 0.4
        let duration = 1.2 + rnd(3) * 1.0
        let drift = (rnd(4) - 0.5) * 60
        let spin = 180 + rnd(5) * 360

        Rectangle()
            .fill(colors[index % colors.count])
            .frame(width: 6, height: 9)
            .position(x: startX, y: fall ? size.height + 20 : -20)
            .offset(x: fall ? drift : 0)
            .rotationEffect(.degrees(fall ? spin : 0))
            .opacity(fall ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) { fall = true }
            }
    }
}
