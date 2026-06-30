import SwiftUI
import MapKit

/// Interactive map showing visited locations as clustered annotations.
struct WorldMapView: View {
    let countries: [CountryStat]
    var cornerRadius: CGFloat = 20
    /// When set, tapping a pin opens that country instead of just selecting it on the map.
    var onSelect: ((CountryStat) -> Void)? = nil

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCountry: CountryStat? = nil
    @Namespace private var mapScope

    // One representative annotation per country, placed using a coordinate derived
    // directly from photos so pins appear during the offline country pass (before cities).
    private var annotations: [CountryAnnotation] {
        countries.map { country in
            CountryAnnotation(
                id: country.id,
                name: country.name,
                flag: country.flag,
                photoCount: country.photoCount,
                coordinate: CLLocationCoordinate2D(
                    latitude: country.representativeCoordinate.latitude,
                    longitude: country.representativeCoordinate.longitude
                )
            )
        }
    }

    var body: some View {
        Map(position: $position, scope: mapScope) {
            ForEach(annotations) { annotation in
                Annotation(annotation.name, coordinate: annotation.coordinate) {
                    CountryPin(annotation: annotation, isSelected: selectedCountry?.id == annotation.id)
                        .onTapGesture {
                            if let onSelect {
                                if let country = countries.first(where: { $0.id == annotation.id }) {
                                    onSelect(country)
                                }
                                return
                            }
                            withAnimation(.spring()) {
                                if selectedCountry?.id == annotation.id {
                                    selectedCountry = nil
                                } else {
                                    selectedCountry = countries.first { $0.id == annotation.id }
                                    position = .camera(MapCamera(
                                        centerCoordinate: annotation.coordinate,
                                        distance: 800_000
                                    ))
                                }
                            }
                        }
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
            if !annotations.isEmpty {
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

#Preview {
    WorldMapView(countries: TravelStats.mock.countries)
        .frame(height: 280)
        .padding()
}
