import SwiftUI

/// A small, reusable inline lock shown where a Lifetime-only feature would normally appear.
/// Tapping anywhere presents the Lifetime paywall. Use for gated sections (personality,
/// wonders, insights, recaps) so free users see a tempting teaser rather than nothing.
struct LockedFeaturePrompt: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    @Environment(AppViewModel.self) private var appVM
    @State private var showPaywall = false

    private static let gradientTop = Color(red: 0.31, green: 0.27, blue: 0.9)
    private static let gradientBottom = Color(red: 0.55, green: 0.3, blue: 0.85)

    var body: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Self.gradientTop, Self.gradientBottom],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Self.gradientBottom)
                        .padding(3)
                        .background(Circle().fill(.white))
                        .offset(x: 15, y: 15)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(message).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("Unlock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Self.gradientBottom))
            }
            .padding(AppCard.padding)
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) { LifetimePaywallView() }
    }
}

#Preview {
    LockedFeaturePrompt(icon: "wand.and.stars",
                        title: "Travel Personality",
                        message: "Unlock Lifetime to reveal the traveller you are.")
        .environment(AppViewModel.preview)
        .padding()
}
