import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedCountry: CountryStat?
    @State private var showShareCard = false
    @State private var yearRecap: RecapModel?
    @State private var buildingRecap = false

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

                        // Year in Travel recap entry
                        Button {
                            buildingRecap = true
                            Task {
                                yearRecap = await appVM.makeYearRecap()
                                buildingRecap = false
                            }
                        } label: {
                            RecapEntryCard(year: Calendar.current.component(.year, from: Date()),
                                           loading: buildingRecap)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        highlightsSection

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
                                  trips: stats.trips.filter { $0.countryCode == country.id })
            }
            .sheet(isPresented: $showShareCard) {
                ShareComposerView(stats: stats, profile: appVM.personalityProfile, trips: stats.trips)
            }
            .sheet(item: $yearRecap) { recap in
                RecapView(recap: recap)
            }
        }
    }

    // MARK: - Feed sections

    /// Compact lifetime snapshot; the whole strip taps into the Places tab.
    private var statStrip: some View {
        Button { appVM.selectedTab = .places } label: {
            HStack(spacing: 0) {
                statItem("\(stats.countryCount)", "Countries")
                statItem("\(stats.cityCount)", "Cities")
                statItem("\(stats.visitedContinentCount)", "Continents")
                statItem("\(stats.trips.count)", "Trips")
            }
            .padding(.vertical, 14)
            .card()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func statItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// "Highlights" — most-photographed + furthest-from-home (or a set-home prompt).
    @ViewBuilder
    private var highlightsSection: some View {
        let top = stats.mostPhotographedCountry
        let furthest = appVM.furthestTrip
        if top != nil || furthest != nil || appVM.homeCountryCode == nil {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Highlights", systemImage: "sparkles")
                    .padding(.horizontal, 20)

                if let top {
                    Button { selectedCountry = top } label: {
                        MostVisitedBanner(country: top)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }

                if let furthest {
                    Button { selectedCountry = stats.countries.first { $0.id == furthest.trip.countryCode } } label: {
                        FurthestTripCard(furthest: furthest)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                } else if appVM.homeCountryCode == nil {
                    Button { appVM.selectedTab = .me } label: {
                        SetHomeCTACard()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var recentTrips: [Trip] {
        stats.trips
            .filter { $0.countryCode != appVM.homeCountryCode }
            .sorted { $0.startDate > $1.startDate }
            .prefix(3)
            .map { $0 }
    }

    @ViewBuilder
    private var recentTripsSection: some View {
        if !recentTrips.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button { appVM.selectedTab = .places } label: {
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

    var body: some View {
        HStack(spacing: 14) {
            Text(trip.flag).font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.country).font(.subheadline.weight(.semibold))
                Text("\(trip.dateRangeText) · \(trip.photoCount) photos")
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
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.8))
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

private struct FurthestTripCard: View {
    let furthest: AppViewModel.FurthestTrip

    var body: some View {
        HStack(spacing: 16) {
            Text(furthest.trip.flag)
                .font(.system(size: 44))
            VStack(alignment: .leading, spacing: 4) {
                Text("Furthest from home")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(furthest.trip.cities.first.map { "\($0), \(furthest.trip.country)" } ?? furthest.trip.country)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                Text("\(Int(furthest.distanceKm).formatted()) km away · \(furthest.trip.dateRangeText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "airplane.departure")
                .foregroundStyle(.tertiary)
        }
        .padding(AppCard.padding)
        .card()
    }
}

private struct SetHomeCTACard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "house.fill")
                .font(.system(size: 30))
                .foregroundStyle(.tint)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("Furthest from home")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Set your home country")
                    .font(.title3.weight(.bold))
                Text("See which trip took you the furthest")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(AppCard.padding)
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct MostVisitedBanner: View {
    let country: CountryStat

    var body: some View {
        HStack(spacing: 16) {
            Text(country.flag)
                .font(.system(size: 44))
            VStack(alignment: .leading, spacing: 4) {
                Text("Most photographed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(country.name)
                    .font(.title2.weight(.bold))
                Text("\(country.photoCount) photos · \(country.cityCount) cities")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(AppCard.padding)
        .card()
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
