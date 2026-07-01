import SwiftUI

/// The Places tab — a browsable catalog of everywhere you've been:
/// countries, trips, continents and wonders, plus an activity overview.
struct PlacesView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var segment: Segment = .countries
    @State private var selectedCountry: CountryStat?
    @State private var selectedContinent: ContinentStat?
    @State private var selectedWonder: WonderStat?

    private var stats: TravelStats { appVM.stats }

    private enum Segment: String, CaseIterable, Identifiable {
        case countries = "Countries"
        case trips = "Trips"
        case continents = "Continents"
        case wonders = "Wonders"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if stats.totalGeotaggedPhotos == 0 {
                    ContentUnavailableView("Nothing here yet",
                                           systemImage: "globe.europe.africa",
                                           description: Text("Your places will appear as your photos are scanned."))
                } else {
                    content
                }
            }
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedCountry) { country in
                CountryDetailView(country: country,
                                  trips: stats.trips.filter { $0.countryCode == country.id })
            }
            .sheet(item: $selectedContinent) { ContinentDetailView(stat: $0) }
            .sheet(item: $selectedWonder) { wonder in
                WonderDetailView(stat: wonder, trip: tripFor(wonder))
            }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
                StatsCardsSection(stats: stats)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Section {
                    segmentBody
                } header: {
                    Picker("", selection: $segment) {
                        ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.bar)
                }

                if !stats.timelineEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Activity", systemImage: "chart.bar")
                            .padding(.horizontal, 20)
                        TimelineSection(entries: stats.timelineEntries)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 30)
            }
        }
    }

    @ViewBuilder
    private var segmentBody: some View {
        switch segment {
        case .countries:  countriesList
        case .trips:      tripsList
        case .continents: continentsList
        case .wonders:    wondersList
        }
    }

    // MARK: - Countries

    private var countriesList: some View {
        let countries = stats.countries.sorted { $0.photoCount > $1.photoCount }
        return LazyVStack(spacing: 0) {
            ForEach(countries) { country in
                Button { selectedCountry = country } label: {
                    CatalogRow(flag: country.flag, title: country.name,
                               subtitle: "\(country.photoCount) photos · \(country.tripCount) \(country.tripCount == 1 ? "trip" : "trips")")
                }
                .buttonStyle(.plain)
                if country.id != countries.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Trips (grouped by year, newest first)

    private var tripsByYear: [(year: Int, trips: [Trip])] {
        let away = stats.trips.filter { $0.countryCode != appVM.homeCountryCode }
        let grouped = Dictionary(grouping: away) {
            Calendar.current.component(.year, from: $0.startDate)
        }
        return grouped.keys.sorted(by: >).map { year in
            (year, grouped[year]!.sorted { $0.startDate > $1.startDate })
        }
    }

    @ViewBuilder
    private var tripsList: some View {
        if tripsByYear.isEmpty {
            Text("No trips yet")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(tripsByYear, id: \.year) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(group.year))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20).padding(.bottom, 6)
                        ForEach(group.trips) { trip in
                            NavigationLink { TripDetailView(trip: trip) } label: {
                                CatalogRow(flag: trip.flag, title: trip.country,
                                           subtitle: "\(trip.dateRangeText) · \(trip.photoCount) photos")
                            }
                            .buttonStyle(.plain)
                            if trip.id != group.trips.last?.id { Divider().padding(.leading, 66) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Continents

    private var continentsList: some View {
        let items = stats.continents.sorted { $0.photoCount > $1.photoCount }
        return LazyVStack(spacing: 0) {
            ForEach(items) { stat in
                Button { selectedContinent = stat } label: {
                    CatalogRow(flag: stat.continent.emoji, title: stat.continent.rawValue,
                               subtitle: continentSubtitle(stat),
                               dimmed: !stat.visited)
                }
                .buttonStyle(.plain)
                if stat.id != items.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .padding(.horizontal, 20)
    }

    /// "X of Y countries · NN% seen" for a continent.
    private func continentSubtitle(_ stat: ContinentStat) -> String {
        let total = ContinentMapper.totalCountries(in: stat.continent)
        let base = "\(stat.countryCount) \(stat.countryCount == 1 ? "country" : "countries")"
        guard total > 0 else { return "\(base) · \(stat.photoCount) photos" }
        let pct = Int((Double(stat.countryCount) / Double(total) * 100).rounded())
        return "\(base) of \(total) · \(pct)% seen"
    }

    /// The most recent trip on which this wonder was photographed, if any.
    private func tripFor(_ stat: WonderStat) -> Trip? {
        stats.trips
            .filter { trip in trip.wonders.contains { $0.id == stat.wonder.id } }
            .max { $0.startDate < $1.startDate }
    }

    // MARK: - Wonders (seen first)

    private var wondersList: some View {
        let items = stats.wonders.sorted {
            ($0.seen ? 0 : 1, $0.wonder.category == .sevenWonders ? 0 : 1, $0.wonder.name)
                < ($1.seen ? 0 : 1, $1.wonder.category == .sevenWonders ? 0 : 1, $1.wonder.name)
        }
        return LazyVStack(spacing: 0) {
            ForEach(items) { stat in
                Button { if stat.seen { selectedWonder = stat } } label: {
                    WonderCatalogRow(stat: stat)
                }
                .buttonStyle(.plain)
                .disabled(!stat.seen)
                if stat.id != items.last?.id { Divider().padding(.leading, 66) }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Rows

private struct CatalogRow: View {
    let flag: String
    let title: String
    let subtitle: String
    var dimmed: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Text(flag).font(.system(size: 30)).grayscale(dimmed ? 1 : 0).opacity(dimmed ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct WonderCatalogRow: View {
    let stat: WonderStat

    var body: some View {
        HStack(spacing: 14) {
            Text(stat.wonder.emoji)
                .font(.system(size: 30))
                .grayscale(stat.seen ? 0 : 1).opacity(stat.seen ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.wonder.name).font(.subheadline.weight(.semibold))
                    .foregroundStyle(stat.seen ? .primary : .secondary)
                Text(stat.wonder.category == .sevenWonders ? "New 7 Wonder" : "Landmark")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if stat.seen {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18)).foregroundStyle(.tint)
            } else {
                Image(systemName: "circle").font(.system(size: 18)).foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    PlacesView().environment(AppViewModel.preview)
}
