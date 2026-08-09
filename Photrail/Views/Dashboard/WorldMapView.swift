import SwiftUI
import MapKit

/// Interactive map showing visited locations as clustered annotations.
struct WorldMapView: View {
    let countries: [CountryStat]
    var cornerRadius: CGFloat = 20
    /// When set, tapping a pin opens that country instead of just selecting it on the map.
    var onSelect: ((CountryStat) -> Void)? = nil

    // Optional layers. All default to the countries-only look, so existing callers
    // (e.g. the dashboard mini-peek) are unaffected.
    var wonders: [WonderStat] = []
    /// Prebuilt "visited area" polygons, clipped to country borders. Built by the caller
    /// (it needs the border data) so this view stays a pure renderer.
    var visitedRegions: [VisitedRegionBuilder.Region] = []
    var showCountries: Bool = true
    var showWonders: Bool = false
    var onSelectWonder: ((WonderStat) -> Void)? = nil

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCountry: CountryStat? = nil
    @Namespace private var mapScope

    /// Regions big enough to carry a flag badge. Below roughly half a degree the shape is
    /// a sliver and the badge would cover it entirely.
    private var labelledRegions: [VisitedRegionBuilder.Region] {
        visitedRegions.filter { $0.extentDegrees >= 0.5 }
    }

    /// Wonders actually seen, the only ones worth plotting.
    private var seenWonders: [WonderStat] { showWonders ? wonders.filter(\.seen) : [] }

    // One representative annotation per country, placed using a coordinate derived
    // directly from photos so pins appear during the offline country pass (before cities).
    private var annotations: [CountryAnnotation] {
        countries.map { country in
            CountryAnnotation(
                id: country.id,
                name: country.localizedName,
                flag: country.flag,
                photoCount: country.photoCount,
                coordinate: CLLocationCoordinate2D(
                    latitude: country.representativeCoordinate.latitude,
                    longitude: country.representativeCoordinate.longitude
                )
            )
        }
    }

    /// Open a country — from its pin or from a region's flag badge. When the caller handles
    /// selection (the Map tab opens the country page) we hand it over; otherwise we select
    /// and zoom in place, which is what the standalone map does.
    private func selectCountry(code: String, at coordinate: CLLocationCoordinate2D) {
        guard let country = countries.first(where: { $0.id == code }) else { return }
        if let onSelect {
            onSelect(country)
            return
        }
        withAnimation(.spring()) {
            if selectedCountry?.id == code {
                selectedCountry = nil
            } else {
                selectedCountry = country
                position = .camera(MapCamera(centerCoordinate: coordinate, distance: 800_000))
            }
        }
    }

    var body: some View {
        Map(position: $position, scope: mapScope) {
            // Bottom layer: the territory covered, as filled regions. Drawn first so the
            // pins above stay tappable.
            ForEach(visitedRegions) { region in
                let tint = CountryPalette.color(for: region.countryCode)
                // A region can be several shapes (mainland + islands); they share a colour.
                ForEach(Array(region.polygons.enumerated()), id: \.offset) { _, ring in
                    MapPolygon(coordinates: ring)
                        .foregroundStyle(tint.opacity(0.25))
                        .stroke(tint.opacity(0.75), lineWidth: 1.5)
                }
            }

            // Flag badge naming each region, in its own colour. Slivers too small to hold a
            // label are skipped so the map doesn't get noisy.
            ForEach(labelledRegions) { region in
                Annotation("", coordinate: region.labelCoordinate) {
                    RegionFlag(
                        flag: CountryCatalog.flag(for: region.countryCode),
                        tint: CountryPalette.color(for: region.countryCode)
                    )
                    .onTapGesture {
                        selectCountry(code: region.countryCode, at: region.labelCoordinate)
                    }
                }
                .annotationTitles(.hidden)
            }

            if showCountries {
                ForEach(annotations) { annotation in
                    Annotation(annotation.name, coordinate: annotation.coordinate) {
                        CountryPin(annotation: annotation, isSelected: selectedCountry?.id == annotation.id)
                            .onTapGesture {
                                selectCountry(code: annotation.id, at: annotation.coordinate)
                            }
                    }
                }
            }

            // Top layer: wonders seen, styled distinctly from country flags.
            ForEach(seenWonders) { stat in
                Annotation(stat.wonder.name, coordinate: CLLocationCoordinate2D(
                    latitude: stat.wonder.latitude, longitude: stat.wonder.longitude
                )) {
                    WonderPin(emoji: stat.wonder.emoji, isOfficial: stat.wonder.category == .sevenWonders)
                        .onTapGesture { onSelectWonder?(stat) }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass(scope: mapScope)
            MapScaleView(scope: mapScope)
        }
        .mapScope(mapScope)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            // Frame the content if any layer has something to show; otherwise fall back to
            // a whole-world view rather than an undefined `.automatic` region.
            let hasContent = (showCountries && !annotations.isEmpty)
                || !seenWonders.isEmpty || !visitedRegions.isEmpty
            if hasContent {
                position = .automatic
            } else {
                position = .camera(MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                    distance: 25_000_000
                ))
            }
        }
    }
}

// MARK: - Annotation model

struct CountryAnnotation: Identifiable {
    let id: String
    var name: String
    var flag: String
    var photoCount: Int
    var coordinate: CLLocationCoordinate2D
}

// MARK: - Pin view

private struct CountryPin: View {
    let annotation: CountryAnnotation
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor : .white)
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                Text(annotation.flag)
                    .font(.system(size: isSelected ? 22 : 16))
            }
            // Callout
            if isSelected {
                Text(annotation.name)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Region flag

/// The flag badge sitting on a visited region. Tinted to match its region and smaller than
/// `CountryPin`, so it reads as a label on the area rather than another tappable pin.
private struct RegionFlag: View {
    let flag: String
    let tint: Color

    var body: some View {
        Text(flag)
            .font(.system(size: 14))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.regularMaterial)
                    .overlay(Capsule().stroke(tint.opacity(0.8), lineWidth: 1.5))
            )
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}

// MARK: - Wonder pin

/// A wonder/landmark marker. Deliberately distinct from `CountryPin`: tinted rather than
/// white, with a star badge for the official New 7 Wonders.
private struct WonderPin: View {
    let emoji: String
    let isOfficial: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .overlay { Text(emoji).font(.system(size: 15)) }
            if isOfficial {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                    .padding(2)
                    .background(Circle().fill(.white))
                    .offset(x: 3, y: -3)
            }
        }
    }
}

#Preview {
    WorldMapView(countries: TravelStats.mock.countries)
        .frame(height: 280)
        .padding()
}
