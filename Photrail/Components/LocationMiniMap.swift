import SwiftUI
import MapKit

/// A small, non-interactive map centered on a location with an emoji pin.
/// Decorative — gives a country/wonder detail page a sense of "where".
struct LocationMiniMap: View {
    let latitude: Double
    let longitude: Double
    let glyph: String          // flag or wonder emoji
    var spanMeters: Double = 600_000

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(center: coordinate,
                               latitudinalMeters: spanMeters,
                               longitudinalMeters: spanMeters)
        ), interactionModes: []) {
            Annotation("", coordinate: coordinate) {
                PinGlyph(glyph: glyph)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PinGlyph: View {
    let glyph: String
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            Text(glyph).font(.system(size: 22))
        }
    }
}
