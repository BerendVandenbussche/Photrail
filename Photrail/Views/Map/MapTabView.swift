import SwiftUI
import CoreLocation

/// The Map tab — a full-screen interactive world map. Tapping a country pin opens the
/// country; a layers button controls which layers are drawn (countries, wonders seen, and
/// the areas visited). Wonders and visited areas are part of Photrail Lifetime.
struct MapTabView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedCountry: CountryStat?
    @State private var selectedWonder: WonderStat?
    @State private var showPaywall = false
    /// Built off the main actor (border clipping is heavy) and cached, so panning the map
    /// never re-runs it.
    @State private var visitedRegions: [VisitedRegionBuilder.Region] = []

    private var stats: TravelStats { appVM.stats }

    // Gated layers never render without Lifetime, even if a stored flag says otherwise
    // (e.g. it was enabled before and entitlement changed).
    private var showWonders: Bool { appVM.hasLifetime && appVM.mapShowWonders }
    private var showVisitedAreas: Bool { appVM.hasLifetime && appVM.mapShowVisitedAreas }

    var body: some View {
        NavigationStack {
            WorldMapView(
                countries: stats.countries,
                cornerRadius: 0,
                onSelect: { selectedCountry = $0 },
                wonders: stats.wonders,
                visitedRegions: showVisitedAreas ? visitedRegions : [],
                showCountries: appVM.mapShowCountries,
                showWonders: showWonders,
                onSelectWonder: { selectedWonder = $0 }
            )
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .topTrailing) { layersButton }
            .task(id: regionInputKey) { await rebuildVisitedRegions() }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedCountry) { country in
                CountryDetailView(country: country,
                                  trips: stats.trips.filter { $0.countryCodes.contains(country.id) },
                                  wonders: stats.wonders)
            }
            .sheet(item: $selectedWonder) { WonderDetailView(stat: $0) }
            .sheet(isPresented: $showPaywall) { LifetimePaywallView() }
        }
    }

    // MARK: - Visited areas

    /// Rebuild only when the layer is switched on or the underlying cities change.
    private var regionInputKey: String {
        "\(showVisitedAreas)-\(stats.allCities.count)"
    }

    private func rebuildVisitedRegions() async {
        guard showVisitedAreas else {
            visitedRegions = []
            return
        }
        let places = stats.allCities
            .filter { $0.photoCount > 0 && !$0.countryCode.isEmpty }
            .sorted { $0.photoCount > $1.photoCount }
            .prefix(400)
            .map {
                VisitedRegionBuilder.Place(
                    coordinate: CLLocationCoordinate2D(
                        latitude: $0.representativeCoordinate.latitude,
                        longitude: $0.representativeCoordinate.longitude),
                    countryCode: $0.countryCode
                )
            }
        guard !places.isEmpty else {
            visitedRegions = []
            return
        }
        let borders = await appVM.borderRings(for: places.map(\.countryCode))
        let built = await Task.detached(priority: .userInitiated) {
            VisitedRegionBuilder.regions(from: Array(places), borderRings: borders)
        }.value
        visitedRegions = built
    }

    // MARK: - Layers control

    private var layersButton: some View {
        @Bindable var appVM = appVM
        return Menu {
            Toggle(isOn: $appVM.mapShowCountries) {
                Label("Countries", systemImage: "flag")
            }

            gatedToggle(titleKey: "Wonders", systemImage: "star",
                        isOn: $appVM.mapShowWonders)
            gatedToggle(titleKey: "Visited areas", systemImage: "circle.dashed",
                        isOn: $appVM.mapShowVisitedAreas)
        } label: {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .accessibilityLabel(Text("Layers"))
        .padding(.trailing, 16)
        .padding(.top, 12)
    }

    /// A layer row that only toggles with Lifetime; without it, the row shows a lock and
    /// opens the paywall instead of switching the layer on.
    @ViewBuilder
    private func gatedToggle(titleKey: LocalizedStringKey, systemImage: String,
                             isOn: Binding<Bool>) -> some View {
        if appVM.hasLifetime {
            Toggle(isOn: isOn) { Label(titleKey, systemImage: systemImage) }
        } else {
            Button { showPaywall = true } label: {
                Label(titleKey, systemImage: "lock.fill")
            }
        }
    }
}

#Preview {
    MapTabView().environment(AppViewModel.preview)
}
