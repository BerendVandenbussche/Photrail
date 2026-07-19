import SwiftUI

/// Sheet for choosing the user's home: a country, then optionally a city.
struct HomeLocationView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    private var countries: [CountryStat] {
        appVM.stats.countries.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let home = appVM.homeDisplayName {
                        HStack {
                            Image(systemName: "house.fill").foregroundStyle(.tint)
                            Text(home)
                            Spacer()
                            Button("Clear") {
                                appVM.homeCountryCode = nil
                                appVM.homeCityID = nil
                            }
                            .font(.subheadline)
                        }
                    } else {
                        Text("No home set").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Home")
                } footer: {
                    Text("Pick a country, then optionally a city. Used for the furthest‑trip calculation and to exclude everyday photos near home from your travel personality.")
                }

                Section("Choose your home country") {
                    if countries.isEmpty {
                        Text("No countries yet — scan your photos first.").foregroundStyle(.secondary)
                    }
                    ForEach(countries) { country in
                        NavigationLink(value: country) {
                            HStack {
                                Text(country.flag)
                                Text(country.localizedName)
                                Spacer()
                                if appVM.homeCountryCode == country.id {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CountryStat.self) { country in
                HomeCityPicker(country: country) { dismiss() }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

private struct HomeCityPicker: View {
    @Environment(AppViewModel.self) private var appVM
    let country: CountryStat
    var onDone: () -> Void

    @State private var search = ""

    private var cities: [CityStat] {
        appVM.stats.allCities
            .filter { $0.countryCode == country.id }
            .sorted { $0.photoCount > $1.photoCount }
    }

    private var filteredCities: [CityStat] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return cities }
        return cities.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// The city‑name resolution pass is still running, so more cities may appear soon.
    private var isResolvingCities: Bool {
        if case .geocoding = appVM.scanProgress { return true }
        return false
    }

    var body: some View {
        List {
            Section {
                Button {
                    appVM.homeCountryCode = country.id
                    appVM.homeCityID = nil
                    onDone()
                } label: {
                    HStack {
                        Text("Whole country").foregroundStyle(.primary)
                        Spacer()
                        if appVM.homeCountryCode == country.id && appVM.homeCityID == nil {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
            }

            Section {
                if filteredCities.isEmpty {
                    if !search.isEmpty {
                        Text("No cities match “\(search)”.").foregroundStyle(.secondary)
                    } else {
                        Text("No cities here yet.").foregroundStyle(.secondary)
                    }
                }
                ForEach(filteredCities) { city in
                    Button {
                        appVM.homeCountryCode = country.id
                        appVM.homeCityID = city.id
                        onDone()
                    } label: {
                        HStack {
                            Text(city.name).foregroundStyle(.primary)
                            Spacer()
                            if appVM.homeCityID == city.id {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Cities")
                    if isResolvingCities {
                        Spacer()
                        ProgressView().controlSize(.mini)
                    }
                }
            } footer: {
                if isResolvingCities {
                    Text("Still finding your cities… A city only appears here once it's been resolved, which takes a little longer than the rest of the scan. Check back in a moment if yours isn't listed yet.")
                } else {
                    Text("A city only appears here once it's been resolved. City names are resolved after the main scan, so if yours is missing, give it a moment or reindex from the Me tab.")
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Search cities")
        .navigationTitle("\(country.flag) \(country.localizedName)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
