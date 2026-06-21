import SwiftUI

struct OnboardingView: View {
    @Environment(AppViewModel.self) var appVM
    @State private var currentPage = 0
    @State private var animateHero = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "map.fill",
            iconColor: .blue,
            title: "Your travels,\nbeautifully mapped.",
            body: "Photrail automatically discovers where you've been by reading location data already embedded in your photos."
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            iconColor: .green,
            title: "Private by\ndesign.",
            body: "Everything runs entirely on your device. No accounts. No cloud. No tracking. Your photos never leave your phone."
        ),
        OnboardingPage(
            icon: "photo.stack.fill",
            iconColor: .orange,
            title: "Works with photos\nyou already have.",
            body: "No need to tag or organise anything. Photrail reads EXIF GPS data silently in the background."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page indicator
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: i == currentPage ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.top, 20)

            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { i in
                    OnboardingPageView(page: pages[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // CTA
            VStack(spacing: 14) {
                if currentPage == pages.count - 1 {
                    Button {
                        withAnimation(.spring()) {
                            appVM.completeOnboarding()
                        }
                    } label: {
                        Label("Allow Photo Access", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }

                    Text("You can change this in Settings at any time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Button {
                        withAnimation { currentPage += 1 }
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }

                    Button("Skip") {
                        withAnimation { currentPage = pages.count - 1 }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Page

private struct OnboardingPage {
    var icon: String
    var iconColor: Color
    var title: String
    var body: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(page.iconColor)
                    .symbolEffect(.bounce, value: appeared)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.1), value: appeared)

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.15), value: appeared)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

#Preview {
    OnboardingView()
        .environment(AppViewModel())
}
