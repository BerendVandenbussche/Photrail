import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedCountry: CountryStat?
    @State private var showShareCard = false
    @State private var yearRecap: RecapModel?
    @State private var buildingRecap = false
    @State private var showPaywall = false

    private var stats: TravelStats { appVM.stats }
    private var scanProgress: AppViewModel.ScanProgress { appVM.scanProgress }


    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {

                    // Scan progress banner
                    if scanProgress != .idle {
                        ScanBanner(progress: scanProgress)
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Mini-map peek → opens the Map tab
                    Button { appVM.selectedTab = .map } label: {
                        ZStack(alignment: .bottomTrailing) {
                            WorldMapView(countries: stats.countries)
                                .frame(height: 180)
                                .allowsHitTesting(false)
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Open map").font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.regularMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                            .padding(12)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    if stats.totalGeotaggedPhotos > 0 {

                        // On this day — memories from past years on today's date
                        if !appVM.memories.isEmpty {
                            OnThisDaySection(memories: appVM.memories)
                        }

                        // Compact lifetime snapshot → taps into Places
                        statStrip

                        // Year in Travel recap entry (Lifetime)
                        Button {
                            guard appVM.hasLifetime else { showPaywall = true; return }
                            buildingRecap = true
                            Task {
                                yearRecap = await appVM.makeYearRecap()
                                buildingRecap = false
                            }
                        } label: {
                            RecapEntryCard(year: Calendar.current.component(.year, from: Date()),
                                           loading: buildingRecap,
                                           locked: !appVM.hasLifetime)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        wondersCard

                        highlightsSection

                        nextTripSection

                        recentTripsSection

                    } else if !scanProgress.isActive {
                        // Empty state — scan finished but no geotagged photos found
                        EmptyStateView()
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
                .animation(.spring(response: 0.4), value: stats.countryCount)
                .animation(.spring(response: 0.4), value: scanProgress == .idle)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    LogoLockup(size: 22)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShareCard = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(stats.totalGeotaggedPhotos == 0)
                }
            }
            .sheet(item: $selectedCountry) { country in
                CountryDetailView(country: country,
                                  trips: stats.trips.filter { $0.countryCodes.contains(country.id) },
                                  wonders: stats.wonders)
            }
            .sheet(isPresented: $showShareCard) {
                ShareComposerView(stats: stats, profile: appVM.personalityProfile, trips: stats.trips)
            }
            .sheet(item: $yearRecap) { recap in
                RecapView(recap: recap)
            }
            .sheet(isPresented: $showPaywall) {
                LifetimePaywallView()
            }
        }
    }

    /// Wonders are a Lifetime feature — open the list only when entitled, else the paywall.
    /// Lands on the Places tab's Wonders list rather than a sheet, so "See all" always ends
    /// up somewhere the user can navigate onwards from.
    private func openWonders() {
        if appVM.hasLifetime { appVM.openPlaces(.wonders) } else { showPaywall = true }
    }

    // MARK: - World Wonders progress

    private var officialWonders: [WonderStat] {
        stats.wonders
            .filter { $0.wonder.category == .sevenWonders }
            .sorted { ($0.seen ? 0 : 1, $0.wonder.name) < ($1.seen ? 0 : 1, $1.wonder.name) }
    }

    @ViewBuilder
    private var wondersCard: some View {
        let seen = officialWonders.filter(\.seen).count
        let total = officialWonders.count
        // Only surface the card once at least one wonder has been seen.
        if seen > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Button { openWonders() } label: {
                    HStack {
                        SectionHeader(title: "World Wonders", systemImage: "building.columns")
                        Spacer()
                        if appVM.hasLifetime {
                            Text("See all").font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                        } else {
                            Image(systemName: "lock.fill").font(.caption).foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Button { openWonders() } label: {
                    WondersBucketCard(seen: seen, total: total,
                                      emojis: officialWonders.filter { !$0.seen }.map { $0.wonder.emoji })
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Feed sections

    /// Compact lifetime snapshot; each figure taps into the Places list it counts.
    /// Cities have no list of their own, so they open Countries — the level above them.
    private var statStrip: some View {
        HStack(spacing: 0) {
            statItem("\(stats.countryCount)", "Countries", segment: .countries)
            statItem("\(stats.cityCount)", "Cities", segment: .countries)
            statItem("\(stats.visitedContinentCount)", "Continents", segment: .continents)
            statItem("\(stats.trips.count)", "Trips", segment: .trips)
        }
        .padding(.vertical, 14)
        .card()
        .padding(.horizontal, 20)
    }

    private func statItem(_ value: String, _ label: LocalizedStringKey,
                          segment: PlacesSegment) -> some View {
        Button { appVM.openPlaces(segment) } label: {
            VStack(spacing: 3) {
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "Where next?" — the only forward-looking thing on the page. Absent rather than empty
    /// when there isn't enough travel behind it to reason from; see `refreshTripSuggestion()`.
    ///
    /// Keyed on the destination so cycling to another one restarts the pitch generation, which
    /// is the single driver for it.
    @ViewBuilder
    private var nextTripSection: some View {
        if let suggestion = appVM.tripSuggestion {
            NextTripSection(suggestion: suggestion,
                            locked: !appVM.hasLifetime,
                            onUnlock: { showPaywall = true },
                            onAnother: { appVM.nextTripSuggestion() })
                .task(id: suggestion.destination.id) {
                    await appVM.generateTripPitchIfNeeded()
                }
        }
    }

    /// "Highlights" — most-photographed + furthest-from-home (or a set-home prompt), plus the
    /// most active and most climbed trips once the user has opted into Health.
    ///
    /// A horizontally scrolling row rather than a fixed pair: `containerRelativeFrame(count: 2)`
    /// gives each card exactly the width it had as a 2-up `HStack`, so with Health off the row
    /// fills the screen and does not scroll at all — identical to before. With the third card
    /// present it peeks in from the right edge, which is what advertises the scroll.
    @ViewBuilder
    private var highlightsSection: some View {
        let top = stats.mostPhotographedCountry
        let furthest = appVM.furthestTrip
        let active = appVM.mostActiveTrip
        let climbed = appVM.mostClimbedTrip
        if top != nil || furthest != nil || active != nil || climbed != nil || appVM.homeName == nil {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Highlights", systemImage: "sparkles")
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        if let top {
                            Button { selectedCountry = top } label: {
                                HighlightCard(emoji: top.flag,
                                              label: "Most photographed",
                                              title: top.localizedName,
                                              subtitle: "\(top.photoCount) photos · \(top.cityCount) cities")
                            }
                            .buttonStyle(.plain)
                        }

                        if let furthest {
                            Button { selectedCountry = stats.countries.first { $0.id == furthest.trip.countryCode } } label: {
                                HighlightCard(emoji: "✈️",
                                              label: "Furthest from home",
                                              title: furthest.trip.cities.first.map { "\($0), \(furthest.trip.localizedCountry)" } ?? furthest.trip.localizedCountry,
                                              subtitle: "\(Int(furthest.distanceKm).formatted()) km away")
                            }
                            .buttonStyle(.plain)
                        } else if appVM.homeName == nil {
                            Button { appVM.selectedTab = .me } label: {
                                HighlightCard(emoji: "🏠",
                                              label: "Furthest from home",
                                              title: "Set your home city",
                                              subtitle: "See which trip took you the furthest",
                                              highlighted: true)
                            }
                            .buttonStyle(.plain)
                        }

                        // Only exists once Health insights are on and at least two trips have
                        // step data — no prompt card, no empty slot.
                        if let active {
                            NavigationLink { TripDetailView(trip: active.trip) } label: {
                                HighlightCard(emoji: "👟",
                                              label: "Most active",
                                              title: active.trip.displayName,
                                              subtitle: "\(active.summary)")
                            }
                            .buttonStyle(.plain)
                        }

                        if let climbed {
                            NavigationLink { TripDetailView(trip: climbed.trip) } label: {
                                HighlightCard(emoji: "🧗",
                                              label: "Most climbed",
                                              title: climbed.trip.displayName,
                                              subtitle: "\(climbed.floors.formatted()) floors")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                // Content margins rather than padding on the stack, so cards scroll to the
                // screen edge instead of being clipped inside an inset container, while the
                // first card still lines up with the section header.
                .contentMargins(.horizontal, 20, for: .scrollContent)
            }
        }
    }

    private var recentTrips: [Trip] {
        stats.trips
            .sorted { $0.startDate > $1.startDate }
            .prefix(3)
            .map { $0 }
    }

    @ViewBuilder
    private var recentTripsSection: some View {
        if !recentTrips.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button { appVM.openPlaces(.trips) } label: {
                    HStack {
                        SectionHeader(title: "Recent Trips", systemImage: "suitcase.fill")
                        Spacer()
                        Text("See all").font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.trailing, 20)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                ForEach(recentTrips) { trip in
                    NavigationLink { TripDetailView(trip: trip) } label: {
                        RecentTripRow(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Supporting views

private struct RecentTripRow: View {
    let trip: Trip
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        let vibe = appVM.vibe(for: trip)
        HStack(spacing: 14) {
            FlagCluster(flags: trip.countries.map(\.flag), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(vibe.emoji) \(vibe.title) · \(trip.dateRangeText)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(14)
        .card()
        .contentShape(Rectangle())
    }
}

private struct RecapEntryCard: View {
    let year: Int
    let loading: Bool
    var locked: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                LogoMark(color: .white).frame(width: 26, height: 26)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Your \(String(year)) Year in Travel")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Relive your year and share your snapshot")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            if loading {
                ProgressView().tint(.white)
            } else {
                Image(systemName: locked ? "lock.fill" : "chevron.right")
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color(red: 0.31, green: 0.27, blue: 0.9),
                                    Color(red: 0.55, green: 0.3, blue: 0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous)
        )
    }
}

/// The "bucket list" wonders progress card — dark gradient, big count and a
/// segmented progress bar, one segment per wonder.
private struct WondersBucketCard: View {
    let seen: Int
    let total: Int
    let emojis: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bucket list")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(seen)")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("/ \(total) seen")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(Array(emojis.prefix(4).enumerated()), id: \.offset) { _, emoji in
                        Text(emoji).font(.system(size: 24))
                    }
                }
            }

            HStack(spacing: 5) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Capsule()
                        .fill(index < seen ? Color.white : Color.white.opacity(0.18))
                        .frame(height: 6)
                }
            }
        }
        .padding(AppCard.padding)
        .background(
            LinearGradient(colors: [Color(red: 0.16, green: 0.13, blue: 0.34),
                                    Color(red: 0.35, green: 0.24, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous)
        )
        .contentShape(Rectangle())
    }
}

/// A compact highlight tile: emoji, an uppercase label, a bold value and a subtitle.
/// Two of these sit side-by-side in the Highlights grid.
private struct HighlightCard: View {
    let emoji: String
    let label: LocalizedStringKey
    let title: String
    let subtitle: LocalizedStringKey
    var highlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(emoji)
                .font(.system(size: 34))

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(AppCard.padding)
        .card()
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
            }
        }
        // Exactly the width these tiles had as a fixed 2-up row, measured against the
        // enclosing scroll view. Sized here, after the padding and background, so the whole
        // tile is what gets the width — and so all four call sites stay unchanged.
        .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
        .contentShape(Rectangle())
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No geotagged photos found")
                .font(.title3.weight(.semibold))
            Text("Photos need location data enabled in your camera settings to appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    DashboardView()
        .environment(AppViewModel.preview)
}
