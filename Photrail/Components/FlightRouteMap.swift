import SwiftUI
import MapKit

/// A map of a plan's flights: a great-circle line per leg and a marker at every airport,
/// framed so the whole route is in view.
///
/// MapKit's `.automatic` framing only fits the airports, but a long great-circle leg bows far
/// past them (Montreal → Paris passes south of Greenland), so the region is computed from
/// points along the arcs instead.
struct FlightRouteMap: View {
    let flights: [PlannedTrip.Flight]

    @State private var position: MapCameraPosition = .automatic

    private struct Leg: Identifiable {
        let id: String
        let from: AirportDirectory.Airport
        let to: AirportDirectory.Airport
    }

    private var legs: [Leg] {
        flights.compactMap { flight in
            guard let from = AirportDirectory.airport(flight.from),
                  let to = AirportDirectory.airport(flight.to) else { return nil }
            return Leg(id: flight.id, from: from, to: to)
        }
    }

    /// Every airport once, in route order.
    private var airports: [AirportDirectory.Airport] {
        var seen = Set<String>()
        return legs.flatMap { [$0.from, $0.to] }.filter { seen.insert($0.iata).inserted }
    }

    var body: some View {
        // Pinch to zoom only: in a scrolling form a pannable map would swallow scroll swipes.
        Map(position: $position, interactionModes: [.zoom]) {
            FlightPathsContent(flights: flights)
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .onAppear { position = fittedPosition }
        .onChange(of: flights) { _, _ in withAnimation { position = fittedPosition } }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: airports.map(\.placeName).joined(separator: " → ")))
    }

    // MARK: - Framing

    /// A region around every point of every arc, with a margin, kept continuous over the
    /// date line (longitudes are unwrapped, then the centre is folded back into ±180).
    private var fittedPosition: MapCameraPosition {
        var lons: [Double] = [], lats: [Double] = []
        for leg in legs {
            for point in FlightGeometry.greatCircle(from: leg.from, to: leg.to) {
                var lon = point.longitude
                if let previous = lons.last { lon += ((previous - lon) / 360).rounded() * 360 }
                lons.append(lon)
                lats.append(point.latitude)
            }
        }
        guard let minLon = lons.min(), let maxLon = lons.max(),
              let minLat = lats.min(), let maxLat = lats.max() else { return .automatic }

        var centreLon = (minLon + maxLon) / 2
        centreLon -= (centreLon / 360).rounded() * 360
        let span = MKCoordinateSpan(latitudeDelta: min(170, max(2, (maxLat - minLat) * 1.5)),
                                    longitudeDelta: min(360, max(2, (maxLon - minLon) * 1.3)))
        let centre = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: centreLon)
        return .region(MKCoordinateRegion(center: centre, span: span))
    }
}

/// The flights as map content, for any `Map`: a great-circle line per leg with a small plane
/// halfway along it pointing the way, and a dot and code at every airport. Shared by the
/// plan's map and the trip's itinerary map.
struct FlightPathsContent: MapContent {
    let flights: [PlannedTrip.Flight]

    /// One line per airport pair. A return flight over the same route shares the outbound
    /// line instead of drawing a second one on top of it.
    private struct Route: Identifiable {
        let id: String
        let a: AirportDirectory.Airport
        let b: AirportDirectory.Airport
    }

    /// A plane on a route, pointing the way that flight goes.
    private struct Plane: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        /// Screen angle of the route at that point (0 = pointing east).
        let heading: Angle
    }

    private var routes: [Route] {
        var seen = Set<String>()
        return flights.compactMap { flight in
            guard let from = AirportDirectory.airport(flight.from),
                  let to = AirportDirectory.airport(flight.to),
                  seen.insert(Self.pairKey(flight.from, flight.to)).inserted else { return nil }
            return Route(id: Self.pairKey(flight.from, flight.to), a: from, b: to)
        }
    }

    /// One plane per direction flown. A route flown one way gets its plane halfway; flown both
    /// ways, the two planes sit either side of the middle, nose to nose.
    private var planes: [Plane] {
        let directions = Set(flights.map { "\($0.from)>\($0.to)" })
        return routes.flatMap { route -> [Plane] in
            let arc = FlightGeometry.greatCircle(from: route.a, to: route.b)
            let forward = directions.contains("\(route.a.iata)>\(route.b.iata)")
            let backward = directions.contains("\(route.b.iata)>\(route.a.iata)")
            let both = forward && backward
            var result: [Plane] = []
            if forward {
                let i = both ? arc.count * 3 / 8 : arc.count / 2
                result.append(Plane(id: route.id + ">", coordinate: arc[i], heading: Self.heading(along: arc, at: i)))
            }
            if backward {
                let i = both ? arc.count * 5 / 8 : arc.count / 2
                result.append(Plane(id: route.id + "<", coordinate: arc[i],
                                    heading: .radians(Self.heading(along: arc, at: i).radians + .pi)))
            }
            return result
        }
    }

    private var airports: [AirportDirectory.Airport] {
        var seen = Set<String>()
        return routes.flatMap { [$0.a, $0.b] }.filter { seen.insert($0.iata).inserted }
    }

    var body: some MapContent {
        ForEach(routes) { route in
            MapPolyline(coordinates: [route.a.coordinate, route.b.coordinate], contourStyle: .geodesic)
                .stroke(Color.accentColor.opacity(0.8),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 6]))
        }
        ForEach(planes) { plane in
            Annotation(coordinate: plane.coordinate, anchor: .center) {
                Image(systemName: "airplane")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(plane.heading)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            } label: {
                EmptyView()
            }
        }
        ForEach(airports) { airport in
            Annotation(airport.iata, coordinate: airport.coordinate) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
    }

    /// The same key for A→B and B→A.
    private static func pairKey(_ a: String, _ b: String) -> String {
        a < b ? "\(a)|\(b)" : "\(b)|\(a)"
    }

    /// Screen angle of the arc at point `i`, from its neighbours in map (Mercator) space.
    private static func heading(along arc: [CLLocationCoordinate2D], at i: Int) -> Angle {
        let before = MKMapPoint(arc[max(0, i - 1)]), after = MKMapPoint(arc[min(arc.count - 1, i + 1)])
        var dx = after.x - before.x
        // Over the date line the projected x jumps a whole world width; take the short way.
        if abs(dx) > MKMapSize.world.width / 2 { dx -= MKMapSize.world.width * (dx > 0 ? 1 : -1) }
        return .radians(atan2(after.y - before.y, dx))
    }
}

enum FlightGeometry {
    /// Points along the great circle between two airports (spherical interpolation).
    static func greatCircle(from a: AirportDirectory.Airport, to b: AirportDirectory.Airport,
                            steps: Int = 32) -> [CLLocationCoordinate2D] {
        func vector(_ c: CLLocationCoordinate2D) -> (Double, Double, Double) {
            let (φ, λ) = (c.latitude * .pi / 180, c.longitude * .pi / 180)
            return (cos(φ) * cos(λ), cos(φ) * sin(λ), sin(φ))
        }
        let p = vector(a.coordinate), q = vector(b.coordinate)
        let ω = acos(max(-1, min(1, p.0 * q.0 + p.1 * q.1 + p.2 * q.2)))
        guard ω > 1e-6 else { return [a.coordinate] }
        return (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let (s1, s2) = (sin((1 - t) * ω) / sin(ω), sin(t * ω) / sin(ω))
            let (x, y, z) = (s1 * p.0 + s2 * q.0, s1 * p.1 + s2 * q.1, s1 * p.2 + s2 * q.2)
            return CLLocationCoordinate2D(latitude: atan2(z, sqrt(x * x + y * y)) * 180 / .pi,
                                          longitude: atan2(y, x) * 180 / .pi)
        }
    }
}

/// "🇧🇪 BRU → 🇯🇵 NRT" with the date and cities underneath, for lists of legs.
struct FlightLegLabel: View {
    let flight: PlannedTrip.Flight

    private var detail: String {
        let from = AirportDirectory.airport(flight.from)?.placeName ?? flight.from
        let to = AirportDirectory.airport(flight.to)?.placeName ?? flight.to
        let route = "\(from) → \(to)"
        guard let date = flight.date else { return route }
        return "\(date.formatted(.dateTime.day().month(.abbreviated))) · \(route)"
    }

    var body: some View {
        let from = AirportDirectory.airport(flight.from)
        let to = AirportDirectory.airport(flight.to)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(verbatim: "\(from?.flag ?? "") \(flight.from)")
                Image(systemName: "airplane").font(.caption).foregroundStyle(.tint)
                Text(verbatim: "\(to?.flag ?? "") \(flight.to)")
            }
            .font(.subheadline.weight(.semibold))
            Text(verbatim: detail)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

/// A searchable list of airports; picking one calls `onPick` and goes back. `initialQuery`
/// starts the search, e.g. with the country a suggested flight goes to.
struct AirportSearchList: View {
    let title: LocalizedStringKey
    let onPick: (AirportDirectory.Airport) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query: String

    init(title: LocalizedStringKey, initialQuery: String = "",
         onPick: @escaping (AirportDirectory.Airport) -> Void) {
        self.title = title
        self.onPick = onPick
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        List(AirportDirectory.search(query)) { airport in
            Button {
                onPick(airport)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Text(airport.flag).font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: "\(airport.placeName) (\(airport.iata))").foregroundStyle(.primary)
                        Text(airport.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "City, airport or code")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// What a new flight starts from: a suggestion, or the user's own ("Other flight").
struct NewFlightRequest: Identifiable, Hashable {
    let id = UUID()
    var from: String?
    var to: String?
    var fromSearch: String?
    var toSearch: String?
    var date: Date
}

/// Add or edit one flight leg: a day, a departure and an arrival airport.
struct FlightLegEditor: View {
    let existing: PlannedTrip.Flight?
    let onSave: (PlannedTrip.Flight) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var from: String?
    @State private var to: String?
    @State private var date: Date
    /// Set once the user picks a date; until then it follows the airports (see `guessDate`).
    @State private var dateChosen = false
    private let fromSearch: String
    private let toSearch: String
    /// The trip's countries and days, to date a new flight from its airports.
    private var segments: [FlightSuggestions.Segment] = []

    /// Edit an existing flight.
    init(existing: PlannedTrip.Flight, defaultDate: Date,
         onSave: @escaping (PlannedTrip.Flight) -> Void, onDelete: (() -> Void)? = nil) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _from = State(initialValue: existing.from)
        _to = State(initialValue: existing.to)
        _date = State(initialValue: existing.date ?? defaultDate)
        fromSearch = ""
        toSearch = ""
    }

    /// Add a new flight, starting from a suggestion.
    init(new request: NewFlightRequest, segments: [FlightSuggestions.Segment] = [],
         onSave: @escaping (PlannedTrip.Flight) -> Void) {
        existing = nil
        self.onSave = onSave
        self.segments = segments
        _from = State(initialValue: request.from)
        _to = State(initialValue: request.to)
        _date = State(initialValue: request.date)
        fromSearch = request.fromSearch ?? ""
        toSearch = request.toSearch ?? ""
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Date", selection: Binding(get: { date },
                                                      set: { date = $0; dateChosen = true }),
                           displayedComponents: .date)
                airportRow(label: "From", code: from, search: fromSearch) { from = $0.iata; guessDate() }
                airportRow(label: "To", code: to, search: toSearch) { to = $0.iata; guessDate() }
            }
            if existing != nil, let onDelete {
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Remove flight", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle(existing == nil ? Text("Add Flight") : Text("Edit Flight"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let from, let to else { return }
                    onSave(PlannedTrip.Flight(id: existing?.id ?? UUID().uuidString, from: from, to: to,
                                              date: Calendar.current.startOfDay(for: date)))
                    dismiss()
                }
                .disabled(from == nil || to == nil || from == to)
            }
        }
    }

    /// A new flight into the trip lands on its first day, one home on its last: follow the
    /// airports until the user sets a date.
    private func guessDate() {
        guard existing == nil, !dateChosen, let from, let to,
              let guess = FlightSuggestions.date(from: from, to: to, segments: segments) else { return }
        date = guess
    }

    private func airportRow(label: LocalizedStringKey, code: String?, search: String,
                            pick: @escaping (AirportDirectory.Airport) -> Void) -> some View {
        NavigationLink {
            AirportSearchList(title: label, initialQuery: code == nil ? search : "", onPick: pick)
        } label: {
            HStack {
                Text(label)
                Spacer()
                if let code, let airport = AirportDirectory.airport(code) {
                    Text(verbatim: "\(airport.flag) \(airport.placeName) (\(code))")
                        .foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("Choose an airport").foregroundStyle(.tint)
                }
            }
        }
    }
}

/// Edit the flights of a plan or a past trip: a map of the route, the flights in travel order,
/// and an "Add flight" menu offering the likely ones (getting there, between countries,
/// coming home). Saves all at once, so Cancel really cancels.
struct FlightsEditorSheet: View {
    let segments: [FlightSuggestions.Segment]
    let onSave: ([PlannedTrip.Flight]) -> Void

    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var flights: [PlannedTrip.Flight]
    @State private var newFlight: NewFlightRequest?

    init(flights: [PlannedTrip.Flight], segments: [FlightSuggestions.Segment],
         onSave: @escaping ([PlannedTrip.Flight]) -> Void) {
        self.segments = segments
        self.onSave = onSave
        _flights = State(initialValue: flights)
    }

    private var sorted: [PlannedTrip.Flight] { PlannedTrip.sorted(flights) }

    private var suggestions: [FlightSuggestion] {
        let home = appVM.homeCoordinate.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        return FlightSuggestions.make(segments: segments, home: home)
    }

    /// The trip's first day, for flights that have no date of their own.
    private var tripStart: Date { segments.first?.start ?? Calendar.current.startOfDay(for: Date()) }
    /// The trip's last day, for the way back.
    private var tripEnd: Date { segments.last?.end ?? tripStart }

    /// The way out mirrored, when there is one to mirror and no flight home yet.
    private var returnFlights: [PlannedTrip.Flight]? {
        FlightSuggestions.returnFlights(for: flights, on: tripEnd)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !flights.isEmpty {
                    Section {
                        FlightRouteMap(flights: flights)
                            .frame(height: 220)
                            .listRowInsets(EdgeInsets())
                    }
                }
                let groups = FlightSuggestions.grouped(flights)
                flightSection("Getting there", groups.outbound)
                flightSection("During the trip", groups.during)
                flightSection("Coming home", groups.home)
                Section {
                    addMenu
                } footer: {
                    Text("Add each flight separately, so a transfer is two flights.")
                }
            }
            .navigationTitle("Flights")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $newFlight) { request in
                FlightLegEditor(new: request, segments: segments) { flights.append($0) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(sorted); dismiss() }
                }
            }
        }
    }

    /// One group of flights under its own header; left out when empty.
    @ViewBuilder
    private func flightSection(_ title: LocalizedStringKey, _ group: [PlannedTrip.Flight]) -> some View {
        if !group.isEmpty {
            Section(title) {
                ForEach(group) { flight in
                    NavigationLink {
                        FlightLegEditor(existing: flight, defaultDate: tripStart,
                                        onSave: { updated in
                                            if let i = flights.firstIndex(where: { $0.id == updated.id }) {
                                                flights[i] = updated
                                            }
                                        },
                                        onDelete: { flights.removeAll { $0.id == flight.id } })
                    } label: {
                        FlightLegLabel(flight: flight)
                    }
                }
                .onDelete { offsets in
                    let ids = Set(offsets.map { group[$0].id })
                    flights.removeAll { ids.contains($0.id) }
                }
            }
        }
    }

    private var addMenu: some View {
        Menu {
            if let returnFlights {
                Button {
                    flights.append(contentsOf: returnFlights)
                } label: {
                    Text("Same route back")
                    Text(verbatim: AppViewModel.routeCodes(returnFlights).joined(separator: " → "))
                }
            }
            ForEach(suggestions) { suggestion in
                Button(suggestion.title) {
                    newFlight = NewFlightRequest(from: suggestion.fromAirport, to: suggestion.toAirport,
                                                 fromSearch: suggestion.fromSearch, toSearch: suggestion.toSearch,
                                                 date: suggestion.date)
                }
            }
            Button("Other flight") {
                // Most often a connection: it leaves from where the last flight landed.
                let last = sorted.last
                newFlight = NewFlightRequest(from: last?.to, to: nil, fromSearch: nil, toSearch: nil,
                                             date: last?.date ?? tripStart)
            }
        } label: {
            Label(flights.isEmpty ? "Add a flight" : "Add another flight", systemImage: "airplane")
        }
    }
}
