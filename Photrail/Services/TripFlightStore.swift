import Foundation

/// The flights a photo trip inherited from the plan it came from, keyed by trip id.
///
/// Like `TripNameStore`: trips are rebuilt from photos on every scan, so anything the user
/// added lives beside them, keyed by the trip's stable id. Kept apart from the trip itself on
/// purpose. The flights are shown in their own section and never feed the itinerary, whose map
/// and stops come from the photos alone.
enum TripFlightStore {
    private static let key = "tripFlights"

    private static func all() -> [String: [PlannedTrip.Flight]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [PlannedTrip.Flight]].self, from: data)
        else { return [:] }
        return decoded
    }

    static func flights(for tripID: String) -> [PlannedTrip.Flight] {
        all()[tripID] ?? []
    }

    /// An empty list removes the entry.
    static func setFlights(_ flights: [PlannedTrip.Flight], for tripID: String) {
        var dict = all()
        dict[tripID] = flights.isEmpty ? nil : flights
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
