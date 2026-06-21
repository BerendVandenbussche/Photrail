import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedCountry: CountryStat?
    @State private var selectedContinent: ContinentStat?
    @State private var showShareCard = false

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

                    // Hero map
                    WorldMapView(countries: stats.countries)
                        .frame(height: 260)
                        .padding(.horizontal, 20)

                    // Stats grid
                    if stats.totalGeotaggedPhotos > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Your Impact", systemImage: "chart.bar.fill")
                                .padding(.horizontal, 20)
                            StatsCardsSection(stats: stats)
                                .padding(.horizontal, 20)
                        }

                        // Most photographed callout
                        if let top = stats.mostPhotographedCountry {
                            Button { selectedCountry = top } label: {
                                MostVisitedBanner(country: top)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }

                        // Countries horizontal scroll
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Countries", systemImage: "flag.fill")
                                .padding(.horizontal, 20)
                            CountriesSection(
                                countries: stats.countries.sorted { $0.photoCount > $1.photoCount }
                            ) { country in
                                selectedCountry = country
                            }
                        }

                        // Continents
                        if !stats.continents.isEmpty {
                            ContinentsSection(continents: stats.continents) { continent in
                                selectedContinent = continent
                            }
                        }

                        // Timeline
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Activity", systemImage: "chart.bar")
                                .padding(.horizontal, 20)
                            TimelineSection(entries: stats.timelineEntries)
                                .padding(.horizontal, 20)
                        }
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
            .navigationTitle("Photrail")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
                CountryDetailView(country: country)
            }
            .sheet(item: $selectedContinent) { continent in
                ContinentDetailView(stat: continent)
            }
            .sheet(isPresented: $showShareCard) {
                ShareCardView(stats: stats)
            }
        }
    }
}

// MARK: - Supporting views

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
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
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
