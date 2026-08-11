import SwiftUI
import UIKit

/// The "Me" tab: avatar, travel personality, lifetime snapshot, home, and management.
struct ProfileView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var showEmojiPicker = false
    @State private var showHomePicker = false
    @State private var showReindexConfirm = false
    @State private var yearRecap: RecapModel?
    @State private var pendingYear: Int?
    @State private var selectedCategory: TravelCategory?
    @State private var showPaywall = false
    @State private var notificationsDenied = false

    private var stats: TravelStats { appVM.stats }
    private var profile: TravelPersonalityProfile? { appVM.personalityProfile }

    /// Years with any trips, most recent first.
    private var availableYears: [Int] {
        var years = Set<Int>()
        for trip in stats.trips {
            years.insert(Calendar.current.component(.year, from: trip.startDate))
            years.insert(Calendar.current.component(.year, from: trip.endDate))
        }
        return years.sorted(by: >)
    }

    private func refreshNotificationStatus() async {
        notificationsDenied = await NotificationService.authorizationStatus() == .denied
    }

    /// Send the "trip is ready" nudge for the most recent trip, bypassing every eligibility rule.
    private func sendTestNudge() async {
        guard let trip = stats.trips.max(by: { $0.endDate < $1.endDate }) else { return }
        // Provisional, not the real prompt: a test hook must not be the thing that puts a
        // permission alert in front of the user, and this way it exercises the same quiet
        // delivery path onboarding sets up.
        await NotificationService.requestProvisionalAuthorization()
        await NotificationService.notifyTripReady(tripID: trip.id, flag: trip.flag, country: trip.displayName)
        await refreshNotificationStatus()
    }

    private func tripCount(for year: Int) -> Int {
        stats.trips.filter { Calendar.current.component(.year, from: $0.startDate) == year }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    avatarHeader

                    snapshot

                    if appVM.explorerRarity > 0 { rarityCard }

                    if !appVM.hasLifetime {
                        LockedFeaturePrompt(icon: "person.crop.circle.badge.checkmark",
                                            title: "Travel Personality",
                                            message: "Discover the traveller you are with Photrail Lifetime.")
                            .padding(.horizontal, 20)
                    } else if let profile, profile.isMeaningful {
                        PersonalitySection(profile: profile) { category in
                            selectedCategory = category
                        }
                    } else {
                        personalityPlaceholder
                    }

                    if !availableYears.isEmpty { recapsSection }

                    settingsCard

                    Text("City data © GeoNames (CC BY 4.0)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    Spacer(minLength: 30)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !stats.trips.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        if appVM.hasLifetime {
                            NavigationLink { CalendarView(trips: stats.trips) } label: {
                                calendarIcon
                            }
                            .accessibilityLabel("Travel Calendar")
                        } else {
                            Button { showPaywall = true } label: {
                                calendarIcon.overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(3)
                                        .background(Circle().fill(.tint))
                                        .offset(x: 3, y: 3)
                                }
                            }
                            .accessibilityLabel("Travel Calendar")
                        }
                    }
                }
            }
            .sheet(isPresented: $showEmojiPicker) { EmojiPickerView() }
            .sheet(isPresented: $showHomePicker) { HomeLocationView() }
            .sheet(item: $yearRecap) { recap in RecapView(recap: recap) }
            .sheet(item: $selectedCategory) { category in
                if let profile { PersonalityDetailView(category: category, profile: profile) }
            }
            .sheet(isPresented: $showPaywall) { LifetimePaywallView() }
            .confirmationDialog("Reindex photo library?",
                                isPresented: $showReindexConfirm, titleVisibility: .visible) {
                Button("Reindex", role: .destructive) { appVM.reindex() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Rebuilds your travel history from scratch. Use this if you changed the location or date of photos that were already scanned. City names will be looked up again.")
            }
        }
    }

    // MARK: - Sections

    private var calendarIcon: some View {
        Image(systemName: "calendar")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.tint)
            .frame(width: 34, height: 34)
            .background(Circle().fill(Color.accentColor.opacity(0.15)))
    }

    private var avatarHeader: some View {
        VStack(spacing: 12) {
            Button { showEmojiPicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(LinearGradient(colors: [Color(red: 0.31, green: 0.27, blue: 0.9),
                                                      Color(red: 0.55, green: 0.3, blue: 0.85)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 96, height: 96)
                    Text(appVM.profileEmoji).font(.system(size: 48))
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white, Color.accentColor)
                        .background(Circle().fill(.background))
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            Text(profile?.dominantCategory?.title ?? String(localized: "Traveler"))
                .font(.title2.weight(.bold))
            if let pct = dominantPercentageText {
                Text(pct).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var dominantPercentageText: String? {
        guard let dominant = profile?.dominantCategory,
              let pct = profile?.categoryPercentages[dominant] else { return nil }
        return "\(dominant.emoji) \(Int(pct.rounded()))% \(dominant.title)"
    }

    private var rarityCard: some View {
        let score = appVM.explorerRarity
        let tier: LocalizedStringKey = score >= 67 ? "Off the map"
            : score >= 34 ? "Beyond the crowds" : "Tourist trails"
        return HStack(spacing: 14) {
            Text("🧭")
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Explorer rarity").font(.subheadline.weight(.semibold))
                Text(tier).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text("\(score)").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("/100").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .card()
        .padding(.horizontal, 20)
    }

    private var snapshot: some View {
        let items: [(String, String, String)] = [
            ("🌍", "\(stats.countryCount)", "Countries"),
            ("🏙", "\(stats.cityCount)", "Cities"),
            ("🌎", "\(stats.visitedContinentCount)", "Continents"),
            ("✈️", "\(stats.trips.count)", "Trips")
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items, id: \.2) { emoji, value, label in
                HStack(spacing: 10) {
                    Text(emoji).font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
                        Text(LocalizedStringKey(label)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .card()
            }
        }
        .padding(.horizontal, 20)
    }

    private var personalityPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 32)).foregroundStyle(.tertiary)
            Text("Your travel personality")
                .font(.headline)
            Text("Take more geotagged photos and it'll appear here.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }

    private var recapsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recaps")
                .font(.headline)
                .padding(.horizontal, 20)
            VStack(spacing: 0) {
                ForEach(availableYears, id: \.self) { year in
                    Button {
                        guard appVM.hasLifetime else { showPaywall = true; return }
                        pendingYear = year
                        Task {
                            yearRecap = await appVM.makeYearRecap(year: year)
                            pendingYear = nil
                        }
                    } label: {
                        YearRow(year: year, tripCount: tripCount(for: year),
                                loading: pendingYear == year, locked: !appVM.hasLifetime)
                    }
                    .buttonStyle(.plain)
                    if year != availableYears.last { Divider().padding(.leading, 52) }
                }
            }
            .card()
            .padding(.horizontal, 20)
        }
    }

    private var settingsCard: some View {
        @Bindable var appVM = appVM
        return VStack(spacing: 0) {
            if appVM.hasLifetime {
                HStack(spacing: 14) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    Text("Lifetime member").foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(.green)
                }
                .padding(14)
            } else {
                Button { showPaywall = true } label: {
                    row(icon: "star.circle.fill", title: "Unlock Photrail Lifetime",
                        detail: appVM.lifetimePrice)
                }
                .buttonStyle(.plain)
            }
            Divider().padding(.leading, 52)

            Button { Task { await appVM.restorePurchases() } } label: {
                row(icon: "arrow.clockwise.circle", title: "Restore Purchases", detail: nil)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)

            NavigationLink { AchievementsView() } label: {
                row(icon: "trophy.fill", title: "Achievements",
                    detail: "\(appVM.unlockedAchievementIDs.count) of \(AchievementCatalog.count)")
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)

            Button { showHomePicker = true } label: {
                row(icon: "house.fill", title: "Home",
                    detail: appVM.homeDisplayName ?? String(localized: "Not set"))
            }
            Divider().padding(.leading, 52)

            if !appVM.excludedPhotoIDs.isEmpty {
                NavigationLink { ExcludedPhotosView() } label: {
                    row(icon: "eye.slash.fill", title: "Excluded Photos",
                        detail: "\(appVM.excludedPhotoIDs.count)")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    Text("Travel notifications").foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: $appVM.travelNudgesEnabled).labelsHidden()
                }
                // Nudges are rare by design, so "silent" reads as "working" whether permission
                // was granted or declined once during onboarding. Say which it is.
                if notificationsDenied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Notifications are off in iOS Settings", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 38)
                }
            }
            .padding(14)
            .contentShape(.rect)
            // The real triggers need a trip that ended 2–14 days ago, a border crossing today,
            // or New Year — none of which can be waited for while testing. Long-press sends the
            // trip nudge for the most recent trip, exercising delivery and the tap-through.
            .onLongPressGesture(minimumDuration: 1.5) { Task { await sendTestNudge() } }
            .task { await refreshNotificationStatus() }
            Divider().padding(.leading, 52)

            if appVM.hasLifetime {
                HStack(spacing: 14) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    Text("Trip Insights").foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: $appVM.insightsEnabled).labelsHidden()
                }
                .padding(14)
                .onChange(of: appVM.insightsEnabled) { _, on in
                    if on { Task { _ = await appVM.enableInsights() } }
                }
            } else {
                Button { showPaywall = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        Text("Trip Insights").foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Divider().padding(.leading, 52)

            Button { showReindexConfirm = true } label: {
                row(icon: "arrow.clockwise", title: "Reindex photo library", detail: nil)
            }
        }
        .card()
        .padding(.horizontal, 20)
    }

    private func row(icon: String, title: LocalizedStringKey, detail: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(title).foregroundStyle(.primary)
            Spacer()
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

private struct YearRow: View {
    let year: Int
    let tripCount: Int
    var loading: Bool = false
    var locked: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(year)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(tripCount == 1 ? "1 trip" : "\(tripCount) trips")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if loading {
                ProgressView()
            } else {
                Image(systemName: locked ? "lock.fill" : "chevron.right")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView().environment(AppViewModel.preview)
}
