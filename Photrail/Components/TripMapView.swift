import SwiftUI
import MapKit

/// A map of a single trip: a numbered pin per city, joined by a line in the order
/// the cities were first visited. The line is indicative, not an exact route.
///
/// Tapping a pin flies the camera to that city and slides up a card with its photos; closing
/// the card flies back out to the whole trip.
struct TripMapView: View {
    let stops: [Trip.TripStop]
    /// Flights from the trip's plan. Drawn, but left out of the framing: the map opens on the
    /// itinerary and the user zooms out to see the flights.
    var flights: [PlannedTrip.Flight] = []
    /// Shows each city's flag on its card.
    var multiCountry = false

    @State private var position: MapCameraPosition
    @State private var selectedID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(stops: [Trip.TripStop], flights: [PlannedTrip.Flight] = [], multiCountry: Bool = false) {
        self.stops = stops
        self.flights = flights
        self.multiCountry = multiCountry
        _position = State(initialValue: .region(Self.region(for: stops)))
    }

    private var coordinates: [CLLocationCoordinate2D] {
        stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var selected: (index: Int, stop: Trip.TripStop)? {
        guard let selectedID, let index = stops.firstIndex(where: { $0.id == selectedID }) else { return nil }
        return (index, stops[index])
    }

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            FlightPathsContent(flights: flights)
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Color.accentColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round,
                                               lineJoin: .round, dash: [2, 7]))
            }
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                Annotation(stop.name,
                           coordinate: CLLocationCoordinate2D(latitude: stop.latitude,
                                                              longitude: stop.longitude)) {
                    NumberedPin(number: index + 1, selected: stop.id == selectedID)
                        .onTapGesture { select(stop) }
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .overlay(alignment: .bottom) {
            if let selected {
                StopCard(stop: selected.stop, number: selected.index + 1,
                         multiCountry: multiCountry, onClose: deselect)
                    .padding(10)
                    .id(selected.stop.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.smooth, value: selectedID)
    }

    private func select(_ stop: Trip.TripStop) {
        guard stop.id != selectedID else { return }
        Haptics.selection()
        selectedID = stop.id
        let camera = MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: stop.latitude,
                                                                        longitude: stop.longitude),
                               distance: 30_000)
        withAnimation(reduceMotion ? nil : Animation.smooth(duration: 0.9)) {
            position = .camera(camera)
        }
    }

    private func deselect() {
        selectedID = nil
        withAnimation(reduceMotion ? nil : Animation.smooth(duration: 0.9)) {
            position = .region(Self.region(for: stops))
        }
    }

    /// Region that frames every stop with a little breathing room.
    private static func region(for stops: [Trip.TripStop]) -> MKCoordinateRegion {
        guard !stops.isEmpty else {
            return MKCoordinateRegion(center: .init(latitude: 0, longitude: 0),
                                      span: .init(latitudeDelta: 60, longitudeDelta: 60))
        }
        let lats = stops.map(\.latitude)
        let lons = stops.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        if stops.count == 1 {
            return MKCoordinateRegion(center: center,
                                      latitudinalMeters: 12_000, longitudinalMeters: 12_000)
        }
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.05),
                                    longitudeDelta: max((maxLon - minLon) * 1.5, 0.05))
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// A numbered map pin showing the visit order. Grows a little when selected.
private struct NumberedPin: View {
    let number: Int
    var selected = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(selected ? 0.4 : 0.3), radius: selected ? 6 : 3, y: 1)
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .scaleEffect(selected ? 1.3 : 1)
        .animation(Motion.snappy, value: selected)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }
}

/// The card for a tapped city: its name and date, and a strip of its photos that opens the
/// full-screen viewer.
private struct StopCard: View {
    let stop: Trip.TripStop
    let number: Int
    let multiCountry: Bool
    let onClose: () -> Void

    @State private var openedPhoto: OpenedPhoto?
    @Namespace private var zoom
    private struct OpenedPhoto: Identifiable { let id: String }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.accentColor))
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: multiCountry ? "\(stop.flag) \(stop.name)" : stop.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(verbatim: "\(stop.firstVisit.formatted(date: .abbreviated, time: .omitted)) · \(L.photos(stop.photoCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Circle().fill(.quaternary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }

            if !stop.photoIDs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(stop.photoIDs.prefix(30), id: \.self) { id in
                            Button { openedPhoto = OpenedPhoto(id: id) } label: {
                                PhotoThumbnail(assetID: id, size: 64, cornerRadius: 8)
                                    .zoomSource(id: id, in: zoom)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .frame(height: 64)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppCard.chipRadius, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .fullScreenCover(item: $openedPhoto) {
            FullScreenPhotoView(assetIDs: Array(stop.photoIDs.prefix(30)), startID: $0.id,
                                zoomNamespace: zoom)
        }
    }
}
