import SwiftUI

struct DashboardView: View {
    let stats: TravelStats

    @State private var vm: DashboardViewModel
    @State private var selectedCountry: CountryStat?
    @State private var showShareCard = false
    @State private var scrollOffset: CGFloat = 0

    init(stats: TravelStats) {
        self.stats = stats
        _vm = State(initialValue: DashboardViewModel(stats: stats))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    // Hero map
                    WorldMapView(countries: vm.stats.countries)
                        .frame(height: 260)
                        .padding(.horizontal, 20)

                    // Stats grid
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Your Impact", systemImage: "chart.bar.fill")
                            .padding(.horizontal, 20)
                        StatsCardsSection(stats: vm.stats)
                            .padding(.horizontal, 20)
                    }

                    // Most photographed callout
                    if let top = vm.stats.mostPhotographedCountry {
                        MostVisitedBanner(country: top)
                            .padding(.horizontal, 20)
                    }

                    // Countries horizontal scroll
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Countries", systemImage: "flag.fill")
                            .padding(.horizontal, 20)
                        CountriesSection(countries: vm.sortedCountries) { country in
                            selectedCountry = country
                        }
                    }

                    // Timeline
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Activity", systemImage: "chart.bar")
                            .padding(.horizontal, 20)
                        TimelineSection(entries: vm.stats.timelineEntries)
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
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
                }
            }
            .sheet(item: $selectedCountry) { country in
                CountryDetailView(country: country)
            }
            .sheet(isPresented: $showShareCard) {
                ShareCardView(stats: vm.stats)
            }
        }
    }
}

// MARK: - Most visited banner

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

#Preview {
    DashboardView(stats: .mock)
}
