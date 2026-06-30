import SwiftUI

struct CountryDetailView: View {
    let country: CountryStat
    let trips: [Trip]
    @State private var vm: CountryDetailViewModel
    @State private var showAllTrips = false
    @State private var showAllCities = false
    @State private var selectedPhoto: IdentifiedPhoto?
    @Environment(\.dismiss) private var dismiss

    /// Items shown in trips/cities before "Show more" is tapped.
    private let tripPreviewCount = 5
    private let cityPreviewCount = 5

    /// Identifiable wrapper so a tapped photo can drive a fullScreenCover.
    private struct IdentifiedPhoto: Identifiable { let id: String }

    init(country: CountryStat, trips: [Trip] = []) {
        self.country = country
        self.trips = trips
        _vm = State(initialValue: CountryDetailViewModel(country: country))
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Hero header
                    headerSection

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
                    }

                    // Cities list
                    if !vm.country.cities.isEmpty {
                        citiesSection
                    }

                    // Photo grid
                    photoGridSection
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                FullScreenPhotoView(assetID: photo.id)
            }
        }
        .onAppear {
            vm.loadThumbnails(for: Array(vm.country.photoIDs.prefix(60)))
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(country.flag)
                .font(.system(size: 72))
            Text(country.name)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(dateRange)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(icon: "photo.stack.fill", value: "\(country.photoCount)",
                     label: "Photos", iconColor: .blue)
            StatCard(icon: "mappin.and.ellipse", value: "\(country.cityCount)",
                     label: "Cities", iconColor: .pink)
        }
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
                        Text("\(trip.photoCount) photos · \(trip.durationText)")
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

    private var displayedCities: [CityStat] {
        showAllCities ? vm.country.cities : Array(vm.country.cities.prefix(cityPreviewCount))
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

            if vm.country.cities.count > cityPreviewCount {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { showAllCities.toggle() }
                } label: {
                    Text(showAllCities ? "Show less" : "Show all \(vm.country.cities.count) cities")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
    }

    private var photoGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Photos")
                .padding(.horizontal, 20)

            if vm.country.photoIDs.isEmpty {
                Text("No photos available")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(vm.country.photoIDs.prefix(60), id: \.self) { id in
                        Button { selectedPhoto = IdentifiedPhoto(id: id) } label: {
                            PhotoThumbnail(assetID: id, size: (UIScreen.main.bounds.width - 4) / 3,
                                           cornerRadius: 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dateRange: String {
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
}
