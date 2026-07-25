import SwiftUI
import MapKit

struct OnboardingView: View {
    @Environment(AppViewModel.self) var appVM
    @State private var currentPage = 0
    @State private var animateHero = false
    /// After the intro pages, the user picks a home location before we request photo access.
    @State private var showHomeStep = false

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
        Group {
            if showHomeStep {
                OnboardingHomeStep(
                    onBack: { withAnimation(.spring(response: 0.4)) { showHomeStep = false } },
                    onContinue: { withAnimation(.spring()) { appVM.completeOnboarding() } }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                introFlow
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    private var introFlow: some View {
        VStack(spacing: 0) {
            // Brand lockup
            LogoLockup(size: 28)
                .padding(.top, 24)
                .padding(.bottom, 8)

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
                        withAnimation(.spring(response: 0.4)) { showHomeStep = true }
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
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

// MARK: - Home step

/// Onboarding step where the user sets their home city. Many engines (furthest trip,
/// travel personality, "on this day", trip detection) rely on home being set, so we ask
/// for it up front rather than leaving it buried in Settings.
private struct OnboardingHomeStep: View {
    @Environment(AppViewModel.self) private var appVM
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var completer = LocalSearchCompleter()
    @State private var resolving = false

    /// True while the user is typing a search — used to yield the screen to results.
    private var isSearching: Bool {
        !completer.query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether a home has been chosen. When set, we disable the search entirely and let
    /// the user remove it to search again.
    private var hasHome: Bool { appVM.homeDisplayName != nil }

    var body: some View {
        NavigationStack {
            list
                // Only searchable while no home is set; picking one collapses the field.
                .modifier(ConditionalSearchable(active: !hasHome, query: $completer.query))
                .overlay { if resolving { ProgressView() } }
                .navigationTitle("Set your home")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { onBack() } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Back")
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    // Hide the CTA while searching so results aren't obscured behind it.
                    if !isSearching { ctaBar }
                }
        }
    }

    private var list: some View {
        List {
            if !isSearching {
                Section {
                    hero.listRowSeparator(.hidden).listRowInsets(EdgeInsets())
                }
            }

            if let home = appVM.homeDisplayName {
                Section {
                    HStack {
                        Image(systemName: "house.fill").foregroundStyle(.tint)
                        Text(home)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    Button(role: .destructive) {
                        appVM.clearHome()
                    } label: {
                        Label("Remove home", systemImage: "trash")
                    }
                } header: {
                    Text("Your home")
                }
            } else if !completer.results.isEmpty {
                Section("Results") {
                    ForEach(completer.results, id: \.self) { result in
                        Button {
                            Task { await select(result) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title).foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(resolving)
                    }
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "house.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .padding(.top, 8)
            Text("Where's home?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Set your home city so Photrail can measure how far you travel and keep everyday photos out of your travel stats.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var ctaBar: some View {
        VStack(spacing: 10) {
            Button {
                onContinue()
            } label: {
                Label("Allow Photo Access", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            Text(appVM.homeDisplayName == nil
                 ? "You can set your home later in Settings."
                 : "You can change this later in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(.bar)
    }

    private func select(_ completion: MKLocalSearchCompletion) async {
        resolving = true
        defer { resolving = false }
        guard let place = await completer.resolve(completion) else { return }
        appVM.setHome(name: place.name,
                      latitude: place.latitude,
                      longitude: place.longitude,
                      countryCode: place.countryCode)
        completer.query = ""   // collapse the results now that home is set
    }
}

/// Applies `.searchable` only when `active` — used so the home search disappears once a
/// home is chosen, and returns when it's removed.
private struct ConditionalSearchable: ViewModifier {
    let active: Bool
    @Binding var query: String

    func body(content: Content) -> some View {
        if active {
            content.searchable(text: $query,
                               placement: .navigationBarDrawer(displayMode: .always),
                               prompt: "Search for your city")
        } else {
            content
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
        .environment(AppViewModel.preview)
}
