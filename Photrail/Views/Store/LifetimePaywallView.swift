import SwiftUI

/// The Lifetime unlock sheet. Brand-gradient hero, benefit list, a single localized-price
/// purchase button, plus a Restore link (App Review requirement). Purchasing or restoring
/// dismisses on success.
struct LifetimePaywallView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var showRestoreFailed = false
    @State private var showUnavailable = false

    private static let gradientTop = Color(red: 0.31, green: 0.27, blue: 0.9)
    private static let gradientBottom = Color(red: 0.55, green: 0.3, blue: 0.85)

    private struct Benefit: Identifiable {
        let id = UUID()
        let emoji: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    private let benefits: [Benefit] = [
        .init(emoji: "📅", title: "Year in Travel", detail: "Your animated recap of the year, ready to share."),
        .init(emoji: "🧭", title: "Travel Personality", detail: "Discover the traveller you are, and how you've evolved."),
        .init(emoji: "🏛️", title: "World Wonders", detail: "Track the New 7 Wonders and famous landmarks you've seen."),
        .init(emoji: "❤️", title: "Trip Insights", detail: "Heart rate, climbs and workouts from your trips, via Apple Health."),
        .init(emoji: "📲", title: "Widgets", detail: "Home-screen and lock-screen widgets for your travel stats."),
        .init(emoji: "🎨", title: "Every share card", detail: "All templates and backgrounds, watermark-free.")
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.gradientTop, Self.gradientBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                closeButton

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        benefitList
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                footer
            }
        }
        .alert("Nothing to restore", isPresented: $showRestoreFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't find a previous purchase on this Apple Account.")
        }
        .alert("Purchases unavailable", isPresented: $showUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The Lifetime purchase can't be loaded right now. Please check your connection and try again later.")
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline).foregroundStyle(.white.opacity(0.9))
                    .padding(10).background(Circle().fill(.white.opacity(0.18)))
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var header: some View {
        VStack(spacing: 14) {
            LogoBadge(size: 68)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            Text("Unlock Photrail Lifetime")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text("One payment, yours forever. Your map, trips and stats stay free — Lifetime adds the good stuff.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefitList: some View {
        VStack(spacing: 12) {
            ForEach(benefits) { benefit in
                HStack(alignment: .top, spacing: 14) {
                    Text(benefit.emoji).font(.system(size: 26))
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(benefit.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(benefit.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    // Make sure the product is loaded; if it can't be (no StoreKit config /
                    // ASC product / network), tell the user instead of silently doing nothing.
                    if appVM.storeService.product == nil { await appVM.storeService.loadProduct() }
                    guard appVM.storeService.product != nil else { showUnavailable = true; return }
                    if await appVM.purchaseLifetime() { dismiss() }
                }
            } label: {
                Group {
                    if appVM.storeService.working {
                        ProgressView().tint(Self.gradientBottom)
                    } else {
                        Text("Unlock — \(appVM.lifetimePrice)")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(Self.gradientBottom)
            }
            .disabled(appVM.storeService.working)

            HStack(spacing: 16) {
                Button("Restore Purchases") {
                    Task {
                        await appVM.restorePurchases()
                        if appVM.hasLifetime { dismiss() } else { showRestoreFailed = true }
                    }
                }
                Button("Maybe later") { dismiss() }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))

            Text("One-time purchase · Family Sharing enabled")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial.opacity(0.0))
    }
}

#Preview {
    LifetimePaywallView()
        .environment(AppViewModel.preview)
}
