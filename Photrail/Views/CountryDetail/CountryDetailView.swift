import SwiftUI

struct CountryDetailView: View {
    let country: CountryStat
    var trips: [Trip] = []
    var wonders: [WonderStat] = []
    @State private var showAllTrips = false
    @State private var showAllCities = false
    @State private var selectedWonder: WonderStat?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM

    /// Your home country — trips are journeys *away* from home, so it never has any.
    private var isHomeCountry: Bool { country.id == appVM.homeCountryCode }

    /// Wonders & landmarks the user has photographed in this country.
    private var seenWonders: [WonderStat] {
        wonders
            .filter { $0.wonder.countryCode == country.id && $0.seen }
            .sorted { ($0.wonder.category == .sevenWonders ? 0 : 1, $0.wonder.name)
                    < ($1.wonder.category == .sevenWonders ? 0 : 1, $1.wonder.name) }
    }

    /// Items shown in trips/cities before "Show more" is tapped.
    private let tripPreviewCount = 5
    private let cityPreviewCount = 5

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Hero header
                    DetailHeader(glyph: country.flag, title: country.localizedName, subtitle: dateRange)

                    // Location
                    if country.representativeCoordinate.latitude != 0 || country.representativeCoordinate.longitude != 0 {
                        LocationMiniMap(latitude: country.representativeCoordinate.latitude,
                                        longitude: country.representativeCoordinate.longitude,
                                        glyph: country.flag,
                                        spanMeters: 1_400_000)
                            .padding(.horizontal, 20)
                    }

                    // Stats row
                    statsRow
                        .padding(.horizontal, 20)

                    // Trips
                    if !trips.isEmpty {
                        tripsSection
                    } else if isHomeCountry {
                        homeCountryNote
                            .padding(.horizontal, 20)
                    }

                    // Wonders & landmarks seen in this country
                    if !seenWonders.isEmpty {
                        wondersSection
                    }

                    // Cities list
                    if !country.cities.isEmpty {
                        citiesSection
                    }

                    // Photo grid
                    PhotoGridSection(photoIDs: country.photoIDs, limit: 60)
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedWonder) { wonder in
                WonderDetailView(stat: wonder, trip: tripFor(wonder))
            }
        }
    }

    private func tripFor(_ stat: WonderStat) -> Trip? {
        trips
            .filter { trip in trip.wonders.contains { $0.id == stat.wonder.id } }
            .max { $0.startDate < $1.startDate }
    }

    // MARK: - Sections

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(icon: "photo.stack.fill", value: "\(country.photoCount)",
                     label: "Photos", iconColor: .blue)
            StatCard(icon: "mappin.and.ellipse", value: "\(country.cityCount)",
                     label: "Cities", iconColor: .pink)
        }
    }

    /// Shown instead of a trips list for the home country.
    private var homeCountryNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "house.fill")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your home")
                    .font(.subheadline.weight(.semibold))
                Text("Trips are journeys away from home, so your home country isn't counted as one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .card()
    }

    private var displayedTrips: [Trip] {
        showAllTrips ? trips : Array(trips.prefix(tripPreviewCount))
    }

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: trips.count == 1 ? "1 Trip" : "\(trips.count) Trips")
                .padding(.horizontal, 20)

            ForEach(displayedTrips) { trip in
                NavigationLink {
                    TripDetailView(trip: trip)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.dateRangeText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            if !trip.cities.isEmpty {
                                Text(trip.cities.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text("\(L.photos(trip.photoCount)) · \(trip.durationText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if trip.id != displayedTrips.last?.id {
                    Divider().padding(.leading, 20)
                }
            }

            if trips.count > tripPreviewCount {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { showAllTrips.toggle() }
                } label: {
                    Text(showAllTrips ? "Show less" : "Show all \(trips.count) trips")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
    }

    private var wondersTitle: LocalizedStringKey {
        let hasWonder = seenWonders.contains { $0.wonder.category == .sevenWonders }
        let hasLandmark = seenWonders.contains { $0.wonder.category == .landmark }
        if hasWonder && hasLandmark { return "Wonders & Landmarks" }
        if hasWonder { return seenWonders.count == 1 ? "Wonder" : "Wonders" }
        return seenWonders.count == 1 ? "Landmark" : "Landmarks"
    }

    private var wondersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: wondersTitle)
                .padding(.horizontal, 20)

            ForEach(seenWonders) { stat in
                Button { selectedWonder = stat } label: {
                    HStack(spacing: 14) {
                        Text(stat.wonder.emoji)
                            .font(.system(size: 30))
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.wonder.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(stat.wonder.category == .sevenWonders ? "New 7 Wonder" : "Landmark")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(stat.photoCount)")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if stat.id != seenWonders.last?.id { Divider().padding(.leading, 78) }
            }
        }
    }

    private var displayedCities: [CityStat] {
        showAllCities ? country.cities : Array(country.cities.prefix(cityPreviewCount))
    }

    private var citiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Cities")
                .padding(.horizontal, 20)

            ForEach(displayedCities) { city in
                CityRow(city: city)
                    .padding(.horizontal, 20)
                if city.id != displayedCities.last?.id {
                    Divider().padding(.leading, 20)
                }
            }

            if country.cities.count > cityPreviewCount {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { showAllCities.toggle() }
                } label: {
                    Text(showAllCities ? "Show less" : "Show all \(country.cities.count) cities")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
    }

    private var dateRange: String {
        if country.firstVisit == .distantPast { return "Added manually" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: country.firstVisit)) – \(formatter.string(from: country.lastVisit))"
    }
}

private struct CityRow: View {
    let city: CityStat

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.subheadline.weight(.medium))
                Text(visitDateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(city.photoCount)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Image(systemName: "photo.stack")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private var visitDateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        if Calendar.current.isDate(city.firstVisit, equalTo: city.lastVisit, toGranularity: .month) {
            return fmt.string(from: city.firstVisit)
        }
        return "\(fmt.string(from: city.firstVisit)) – \(fmt.string(from: city.lastVisit))"
    }
}

#Preview {
    CountryDetailView(country: .mock)
        .environment(AppViewModel.preview)
}
