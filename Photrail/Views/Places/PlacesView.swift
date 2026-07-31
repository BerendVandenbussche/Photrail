import SwiftUI

/// The Places tab — a browsable catalog of everywhere you've been:
/// countries, trips, continents and wonders, plus an activity overview.
struct PlacesView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var segment: Segment = .trips
    @State private var selectedCountry: CountryStat?
    @State private var selectedContinent: ContinentStat?
    @State private var selectedWonder: WonderStat?
    @State private var showTripEditor = false
    @State private var editingTrip: ManualTrip?

    private var stats: TravelStats { appVM.stats }

    private enum Segment: String, CaseIterable, Identifiable {
        case trips = "Trips"
        case continents = "Continents"
        case countries = "Countries"
        case wonders = "Wonders"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if stats.totalGeotaggedPhotos == 0 && appVM.manualTrips.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing here yet", systemImage: "globe.europe.africa")
                    } description: {
                        Text("Your places will appear as your photos are scanned — or add a trip you took by hand.")
                    } actions: {
                        Button("Add a trip") { addTrip() }
                    }
                } else {
                    content
                }
            }
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addTrip() } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Add a trip"))
                }
            }
            .sheet(isPresented: $showTripEditor) {
                ManualTripEditorView(existing: editingTrip)
            }
            .sheet(item: $selectedCountry) { country in
                CountryDetailView(country: country,
                                  trips: stats.trips.filter { $0.countryCodes.contains(country.id) },
                                  wonders: stats.wonders)
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
                WorldExploredHero(percentage: stats.worldPercentage,
                                  countryCount: stats.countryCount)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Section {
                    segmentBody
                } header: {
                    Picker("", selection: $segment) {
                        ForEach(Segment.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
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
        case .wonders:
            if appVM.hasLifetime {
                wondersList
            } else {
                LockedFeaturePrompt(icon: "star.circle.fill",
                                    title: "World Wonders",
                                    message: "Track the New 7 Wonders and famous landmarks with Lifetime.")
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
        }
    }

    // MARK: - Countries

    private var countriesList: some View {
        let countries = stats.countries.sorted { $0.photoCount > $1.photoCount }
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(countries) { country in
                let manual = appVM.isManualCountry(country.id)
                Button { selectedCountry = country } label: {
                    CountryGridCard(country: country,
                                    manual: manual,
                                    coverage: manual ? nil : appVM.coverage(for: country))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Manual trip helpers

    private func addTrip() {
        editingTrip = nil
        showTripEditor = true
    }

    private func editTrip(_ trip: Trip) {
        editingTrip = appVM.manualTrip(for: trip)
        showTripEditor = true
    }

    // MARK: - Trips (grouped by year, newest first)

    private var tripsByYear: [(year: Int, trips: [Trip])] {
        let grouped = Dictionary(grouping: stats.trips) {
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
                                TripRow(trip: trip)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if trip.isManual {
                                    Button { editTrip(trip) } label: {
                                        Label("Edit trip", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        if let id = trip.manualTripID { appVM.removeManualTrip(id: id) }
                                    } label: {
                                        Label("Delete trip", systemImage: "trash")
                                    }
                                }
                            }
                            if trip.id != group.trips.last?.id { Divider().padding(.leading, 78) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Continents

    private var continentsList: some View {
        let items = stats.continents.sorted { $0.photoCount > $1.photoCount }
        return LazyVStack(spacing: 12) {
            ForEach(items) { stat in
                Button { selectedContinent = stat } label: {
                    ContinentCard(stat: stat)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    /// The most recent trip on which this wonder was photographed, if any.
    private func tripFor(_ stat: WonderStat) -> Trip? {
        stats.trips
            .filter { trip in trip.wonders.contains { $0.id == stat.wonder.id } }
            .max { $0.startDate < $1.startDate }
    }

    // MARK: - Wonders (seen first)

    /// Seen-first ordering within a category.
    private func sortedWonders(_ category: WonderCategory) -> [WonderStat] {
        stats.wonders
            .filter { $0.wonder.category == category }
            .sorted { ($0.seen ? 0 : 1, $0.wonder.name) < ($1.seen ? 0 : 1, $1.wonder.name) }
    }

    private var wondersList: some View {
        let sevenWonders = sortedWonders(.sevenWonders)
        let landmarks = sortedWonders(.landmark)
        let sevenSeen = sevenWonders.filter(\.seen).count
        let sevenTotal = sevenWonders.count
        return VStack(spacing: 16) {
            WonderHunterHero(seen: sevenSeen, total: sevenTotal,
                             percentage: sevenTotal == 0 ? 0 : Int((Double(sevenSeen) / Double(sevenTotal) * 100).rounded()))

            wonderGrid(title: "World Wonders", systemImage: "star.circle.fill", items: sevenWonders)
            wonderGrid(title: "Landmarks", systemImage: "building.columns", items: landmarks)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func wonderGrid(title: LocalizedStringKey, systemImage: String, items: [WonderStat]) -> some View {
        if !items.isEmpty {
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: title, systemImage: systemImage)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { stat in
                        Button { if stat.seen { selectedWonder = stat } } label: {
                            WonderGridCard(stat: stat)
                        }
                        .buttonStyle(.plain)
                        .disabled(!stat.seen)
                    }
                }
            }
        }
    }
}

// MARK: - Hero

/// The dark gradient hero at the top of Places: "X% of the world explored".
private struct WorldExploredHero: View {
    let percentage: Double
    let countryCount: Int

    private var fraction: CGFloat {
        CGFloat(min(1, max(0, Double(countryCount) / Double(CountryStat.totalCountriesInWorld))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", percentage))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("%")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text("of the world explored")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule().fill(
                        LinearGradient(colors: [Color(red: 0.55, green: 0.45, blue: 1.0),
                                                Color(red: 0.4, green: 0.3, blue: 0.95)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(8, geo.size.width * fraction))
                }
            }
            .frame(height: 8)

            Text("\(countryCount) of \(CountryStat.totalCountriesInWorld) countries")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color(red: 0.16, green: 0.13, blue: 0.34),
                                    Color(red: 0.35, green: 0.24, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous)
        )
    }
}

// MARK: - Rows

/// A country tile in the Places grid: flag badge, name, counts and a "spread" bar.
private struct CountryGridCard: View {
    let country: CountryStat
    let manual: Bool
    let coverage: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(country.flag)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(country.localizedName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(manual
                     ? "Added manually"
                     : "\(L.photos(country.photoCount)) · \(L.trips(country.tripCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Geographic-spread bar — how much of the country's extent your photos cover.
            if let coverage {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                        Capsule().fill(Color.accentColor)
                            .frame(width: max(6, geo.size.width * CGFloat(coverage)))
                    }
                }
                .frame(height: 6)
            } else {
                Color.clear.frame(height: 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card()
        .contentShape(Rectangle())
    }
}

private struct TripRow: View {
    let trip: Trip
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        let vibe = appVM.vibe(for: trip)
        HStack(spacing: 14) {
            FlagCluster(flags: trip.countries.map(\.flag), size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.displayName)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                Text("\(vibe.emoji) \(vibe.title) · \(trip.dateRangeText)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if trip.isManual {
                Image(systemName: "hand.draw")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .accessibilityLabel(Text("Added by hand"))
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// A continent row: globe emoji, name with a progress bar, and "X of Y / NN% seen".
private struct ContinentCard: View {
    let stat: ContinentStat

    private var total: Int { ContinentMapper.totalCountries(in: stat.continent) }
    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(min(1, Double(stat.countryCount) / Double(total)))
    }
    private var pct: Int { Int((Double(fraction) * 100).rounded()) }

    var body: some View {
        HStack(spacing: 14) {
            Text(stat.continent.emoji)
                .font(.system(size: 32))
                .grayscale(stat.visited ? 0 : 1)
                .opacity(stat.visited ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 8) {
                Text(stat.continent.displayName)
                    .font(.headline).foregroundStyle(.primary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                        Capsule().fill(Color.accentColor)
                            .frame(width: max(fraction > 0 ? 6 : 0, geo.size.width * fraction))
                    }
                }
                .frame(height: 6)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stat.countryCount) of \(total)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(pct)% seen")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .card()
        .contentShape(Rectangle())
    }
}

/// The wonders progress hero: a circular ring, a rank title and overall percentage.
private struct WonderHunterHero: View {
    let seen: Int
    let total: Int
    let percentage: Int

    private var fraction: CGFloat { total > 0 ? CGFloat(min(1, Double(seen) / Double(total))) : 0 }

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.6, green: 0.5, blue: 1.0),
                                                Color(red: 0.75, green: 0.7, blue: 1.0)],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(seen)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("of \(total)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 3) {
                Text("New 7 Wonders + more")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.7))
                Text(rank)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(percentage)% of the world's icons visited")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color(red: 0.16, green: 0.13, blue: 0.34),
                                    Color(red: 0.35, green: 0.24, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous)
        )
    }

    /// A playful rank based on how many icons you've visited.
    private var rank: LocalizedStringKey {
        switch percentage {
        case 0:       return "Just Getting Started"
        case 1..<25:  return "Wanderer"
        case 25..<50: return "Wonder Hunter"
        case 50..<75: return "Globe Collector"
        case 75..<100: return "Wonder Master"
        default:      return "Legend"
        }
    }
}

/// A wonder tile in the grid: emoji, name and a green "Seen · year" or a muted "Not yet".
private struct WonderGridCard: View {
    let stat: WonderStat

    private var year: String? {
        guard let date = stat.firstSeen ?? stat.lastSeen else { return nil }
        return String(Calendar.current.component(.year, from: date))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(stat.wonder.emoji)
                .font(.system(size: 30))
                .grayscale(stat.seen ? 0 : 1)
                .opacity(stat.seen ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 3) {
                Text(stat.wonder.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(stat.seen ? .primary : .secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                if stat.seen {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").font(.caption2.weight(.bold))
                        if let year {
                            Text("Seen · \(year)").font(.caption.weight(.semibold))
                        } else {
                            Text("Seen").font(.caption.weight(.semibold))
                        }
                    }
                    .foregroundStyle(.green)
                } else {
                    Text("Not yet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
        .contentShape(Rectangle())
    }
}

#Preview {
    PlacesView().environment(AppViewModel.preview)
}
