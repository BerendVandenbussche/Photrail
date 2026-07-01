import SwiftUI

/// The "Me" tab: avatar, travel personality, lifetime snapshot, home, and management.
struct ProfileView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var showEmojiPicker = false
    @State private var showHomePicker = false
    @State private var showReindexConfirm = false
    @State private var yearRecap: RecapModel?
    @State private var pendingYear: Int?
    @State private var selectedCategory: TravelCategory?

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

    private func tripCount(for year: Int) -> Int {
        stats.trips.filter { Calendar.current.component(.year, from: $0.startDate) == year }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    avatarHeader

                    snapshot

                    if let profile, profile.isMeaningful {
                        PersonalitySection(profile: profile) { category in
                            selectedCategory = category
                        }
                    } else {
                        personalityPlaceholder
                    }

                    if !availableYears.isEmpty { recapsSection }

                    settingsCard

                    Spacer(minLength: 30)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEmojiPicker) { EmojiPickerView() }
            .sheet(isPresented: $showHomePicker) { HomeLocationView() }
            .sheet(item: $yearRecap) { recap in RecapView(recap: recap) }
            .sheet(item: $selectedCategory) { category in
                if let profile { PersonalityDetailView(category: category, profile: profile) }
            }
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

            Text(profile?.dominantCategory?.title ?? "Traveler")
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
                        Text(label).font(.caption).foregroundStyle(.secondary)
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
                        pendingYear = year
                        Task {
                            yearRecap = await appVM.makeYearRecap(year: year)
                            pendingYear = nil
                        }
                    } label: {
                        YearRow(year: year, tripCount: tripCount(for: year), loading: pendingYear == year)
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
        VStack(spacing: 0) {
            Button { showHomePicker = true } label: {
                row(icon: "house.fill", title: "Home",
                    detail: appVM.homeDisplayName ?? "Not set")
            }
            Divider().padding(.leading, 52)
            Button { showReindexConfirm = true } label: {
                row(icon: "arrow.clockwise", title: "Reindex photo library", detail: nil)
            }
        }
        .card()
        .padding(.horizontal, 20)
    }

    private func row(icon: String, title: String, detail: String?) -> some View {
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
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView().environment(AppViewModel.preview)
}
