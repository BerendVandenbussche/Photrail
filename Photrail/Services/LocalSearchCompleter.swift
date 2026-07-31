import Foundation
import MapKit

/// Thin wrapper around `MKLocalSearchCompleter` for city autocomplete, plus a helper to
/// resolve a chosen completion into a coordinate + ISO country code via `MKLocalSearch`.
/// Fully powered by Apple Maps — no photo data required, so the user can pick any city.
@MainActor
@Observable
final class LocalSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var query: String = "" {
        didSet {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                results = []
            } else {
                completer.queryFragment = trimmed
            }
        }
    }
    private(set) var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        // Address results cover cities/towns; filtering out points of interest keeps the
        // list to places rather than businesses.
        completer.resultTypes = [.address]
    }

    /// Bias autocomplete toward a region (e.g. the country being edited) so nearby places
    /// rank first. Pass a wide span to cover a whole country.
    func setRegion(latitude: Double, longitude: Double, spanDegrees: Double = 12) {
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees)
        )
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let updated = completer.results
        Task { @MainActor in self.results = updated }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
    }

    /// A resolved place the user can set as home.
    struct Place: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
        let countryCode: String?
    }

    /// Resolve a completion into a concrete place (coordinate + country code).
    func resolve(_ completion: MKLocalSearchCompletion) async -> Place? {
        let request = MKLocalSearch.Request(completion: completion)
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else {
            return nil
        }
        let placemark = item.placemark
        let name = item.name ?? completion.title
        let display = [name, placemark.country].compactMap { $0 }.joined(separator: ", ")
        return Place(name: display.isEmpty ? name : display,
                     latitude: placemark.coordinate.latitude,
                     longitude: placemark.coordinate.longitude,
                     countryCode: placemark.isoCountryCode)
    }
}
