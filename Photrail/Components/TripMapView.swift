import SwiftUI
import MapKit

/// A map of a single trip: a numbered pin per city, joined by a line in the order
/// the cities were first visited. The line is indicative, not an exact route.
struct TripMapView: View {
    let stops: [Trip.TripStop]

    private var coordinates: [CLLocationCoordinate2D] {
        stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(initialPosition: .region(region), interactionModes: [.pan, .zoom]) {
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
                    NumberedPin(number: index + 1)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    /// Region that frames every stop with a little breathing room.
    private var region: MKCoordinateRegion {
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

/// A numbered map pin showing the visit order.
private struct NumberedPin: View {
    let number: Int
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
