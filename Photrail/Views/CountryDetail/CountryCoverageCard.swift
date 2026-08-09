import SwiftUI
import MapKit

/// How much of a country you've actually seen: its outline with your visited areas filled
/// in, plus the share of its land area those areas cover.
///
/// This is the same region-building used by the world map's "visited areas" layer, scoped
/// to one country — so the shape you see here matches the shape you see there.
struct CountryCoverageCard: View {
    let country: CountryStat

    @Environment(AppViewModel.self) private var appVM
    @State private var borderRings: [[CLLocationCoordinate2D]] = []
    @State private var regions: [VisitedRegionBuilder.Region] = []
    @State private var percentage: Double?
    @State private var loaded = false

    /// Frames the whole country, so the filled part reads as a share of the whole.
    private var cameraPosition: MapCameraPosition {
        let all = borderRings.flatMap { $0 }
        guard !all.isEmpty else {
            return .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(
                    latitude: country.representativeCoordinate.latitude,
                    longitude: country.representativeCoordinate.longitude),
                distance: 2_000_000))
        }
        let lats = all.map(\.latitude), lons = all.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: ((lats.min()! + lats.max()!) / 2),
                                            longitude: ((lons.min()! + lons.max()!) / 2))
        // A little headroom so the outline isn't flush against the card edges.
        let span = MKCoordinateSpan(latitudeDelta: max(1, (lats.max()! - lats.min()!) * 1.25),
                                    longitudeDelta: max(1, (lons.max()! - lons.min()!) * 1.25))
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            map
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let percentage {
                readout(percentage)
            }
        }
        .task(id: country.id) { await load() }
    }

    private var map: some View {
        Map(initialPosition: cameraPosition, interactionModes: []) {
            // The country itself, as a faint outline.
            ForEach(Array(borderRings.enumerated()), id: \.offset) { _, ring in
                MapPolygon(coordinates: ring)
                    .foregroundStyle(Color.secondary.opacity(0.12))
                    .stroke(Color.secondary.opacity(0.45), lineWidth: 1)
            }
            // The parts of it you've been to.
            ForEach(regions) { region in
                ForEach(Array(region.polygons.enumerated()), id: \.offset) { _, ring in
                    MapPolygon(coordinates: ring)
                        .foregroundStyle(Color.accentColor.opacity(0.45))
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
    }

    private func readout(_ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(percentText(value))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                Text("of \(country.localizedName) explored")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(Color.accentColor)
                        // Always leave a sliver visible, so "you've been here" never looks
                        // like "you've been nowhere".
                        .frame(width: max(4, geo.size.width * value))
                }
            }
            .frame(height: 8)

            Text("Based on the areas around the places you took photos.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Shows "<1%" rather than a rounded-down 0% for a country you've genuinely visited.
    private func percentText(_ value: Double) -> String {
        let percent = value * 100
        if percent > 0 && percent < 1 { return "<1%" }
        return "\(Int(percent.rounded()))%"
    }

    private func load() async {
        guard !loaded else { return }
        loaded = true

        let rings = await appVM.borderRings(for: [country.id])[country.id] ?? []
        let places = country.cities
            .filter { $0.photoCount > 0 }
            .map {
                VisitedRegionBuilder.Place(
                    coordinate: CLLocationCoordinate2D(
                        latitude: $0.representativeCoordinate.latitude,
                        longitude: $0.representativeCoordinate.longitude),
                    countryCode: country.id)
            }
        guard !places.isEmpty else {
            borderRings = rings
            return
        }

        let code = country.id
        let result = await Task.detached(priority: .userInitiated) {
            let built = VisitedRegionBuilder.regions(from: places,
                                                     borderRings: rings.isEmpty ? [:] : [code: rings])
            let countryArea = rings.reduce(0) { $0 + VisitedRegionBuilder.areaKm2(of: $1) }
            // Regions within a country are kept apart by the merge pass, so summing them
            // doesn't double-count overlapping shapes.
            let visitedArea = built.reduce(0) { total, region in
                total + region.polygons.reduce(0) { $0 + VisitedRegionBuilder.areaKm2(of: $1) }
            }
            let share = countryArea > 0 ? min(1, visitedArea / countryArea) : nil
            return (built, share)
        }.value

        borderRings = rings
        regions = result.0
        percentage = result.1
    }
}
