import SwiftUI

struct CountryDetailView: View {
    let country: CountryStat
    let trips: [Trip]
    @State private var vm: CountryDetailViewModel
    @Environment(\.dismiss) private var dismiss

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

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: trips.count == 1 ? "1 Trip" : "\(trips.count) Trips")
                .padding(.horizontal, 20)

            ForEach(trips) { trip in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trip.dateRangeText)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(trip.photoCount) photos · \(trip.durationText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !trip.cities.isEmpty {
                        Text(trip.cities.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                if trip.id != trips.last?.id {
                    Divider().padding(.leading, 20)
                }
            }
        }
    }

    private var citiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Cities")
                .padding(.horizontal, 20)

            ForEach(vm.country.cities) { city in
                CityRow(city: city)
                    .padding(.horizontal, 20)
                if city.id != vm.country.cities.last?.id {
                    Divider().padding(.leading, 20)
                }
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
                        PhotoThumbnail(assetID: id, size: (UIScreen.main.bounds.width - 4) / 3,
                                       cornerRadius: 0)
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
