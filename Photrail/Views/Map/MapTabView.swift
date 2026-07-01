import SwiftUI

/// The Map tab — a full-screen interactive world map. Tapping a pin opens the country.
struct MapTabView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedCountry: CountryStat?

    private var stats: TravelStats { appVM.stats }

    var body: some View {
        NavigationStack {
            WorldMapView(countries: stats.countries, cornerRadius: 0) { selectedCountry = $0 }
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(item: $selectedCountry) { country in
                    CountryDetailView(country: country,
                                      trips: stats.trips.filter { $0.countryCode == country.id })
                }
        }
    }
}

#Preview {
    MapTabView().environment(AppViewModel.preview)
}
