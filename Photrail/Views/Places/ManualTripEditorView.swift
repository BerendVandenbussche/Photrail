import SwiftUI
import MapKit

/// Create or edit a hand-entered trip: a name, a date range, and the countries visited —
/// each with its own Apple-Maps-geocoded places. Replaces the old single-country picker;
/// the saved trip feeds the country/continent/world stats and shows in the Trips list.
struct ManualTripEditorView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    /// The trip being edited (nil = creating a new one).
    let existing: ManualTrip?

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var countries: [ManualTrip.Country]
    @State private var showCountryPicker = false
    @State private var showDeleteConfirm = false

    init(existing: ManualTrip? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _startDate = State(initialValue: existing?.startDate ?? Date())
        _endDate = State(initialValue: existing?.endDate ?? Date())
        _countries = State(initialValue: existing?.countries ?? [])
    }

    private var canSave: Bool { !countries.isEmpty && endDate >= startDate }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Name (optional)", text: $name)
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section {
                    ForEach($countries) { $country in
                        NavigationLink {
                            CountryPlacesView(country: $country)
                        } label: {
                            HStack(spacing: 12) {
                                Text(country.flag).font(.system(size: 26))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(CountryCatalog.name(for: country.code))
                                    Text(placesSummary(country))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { countries.remove(atOffsets: $0) }

                    Button {
                        showCountryPicker = true
                    } label: {
                        Label("Add country", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Countries")
                } footer: {
                    Text("Add the countries you visited on this trip. Tap a country to add cities and places.")
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("Delete trip", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? Text("Add Trip") : Text("Edit Trip"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerSheet(excluding: Set(countries.map(\.code))) { option in
                    countries.append(ManualTrip.Country(
                        code: option.code, name: option.name, flag: option.flag,
                        latitude: nil, longitude: nil, places: []
                    ))
                }
            }
            .confirmationDialog("Delete this trip?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete trip", role: .destructive) {
                    if let existing { appVM.removeManualTrip(id: existing.id) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the trip and its countries from your stats. This can't be undone.")
            }
        }
    }

    private func placesSummary(_ country: ManualTrip.Country) -> String {
        country.places.isEmpty
            ? String(localized: "No places added")
            : country.places.map(\.name).joined(separator: ", ")
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip = ManualTrip(
            id: existing?.id ?? UUID().uuidString,
            name: trimmed.isEmpty ? nil : trimmed,
            startDate: startDate, endDate: endDate,
            countries: countries
        )
        appVM.saveManualTrip(trip)
        dismiss()
    }
}

// MARK: - Country picker

/// A searchable country list; tapping one calls `onPick` and dismisses. Codes already on the
/// trip are hidden.
private struct CountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let excluding: Set<String>
    let onPick: (CountryCatalog.Option) -> Void
    @State private var search = ""

    private var filtered: [CountryCatalog.Option] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return CountryCatalog.all.filter {
            !excluding.contains($0.code) && (q.isEmpty || $0.name.lowercased().contains(q))
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { option in
                Button {
                    onPick(option)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(option.flag).font(.system(size: 26))
                        Text(option.name).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(.tint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: "Search countries")
            .navigationTitle("Add Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Places within a country

/// Lists and edits the places recorded for one country of a manual trip.
private struct CountryPlacesView: View {
    @Environment(AppViewModel.self) private var appVM
    @Binding var country: ManualTrip.Country
    @State private var showPlaceSearch = false
    /// A point inside the country, used to bias/validate the place search.
    @State private var center: CLLocationCoordinate2D?

    var body: some View {
        List {
            Section {
                if country.places.isEmpty {
                    Text("No places yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(country.places) { place in
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(.tint)
                        Text(place.name)
                    }
                }
                .onDelete { country.places.remove(atOffsets: $0) }
            } footer: {
                Text("Places are looked up with Apple Maps. They appear as cities on your map and stats.")
            }

            Button {
                showPlaceSearch = true
            } label: {
                Label("Add place", systemImage: "plus.circle.fill")
            }
        }
        .navigationTitle(CountryCatalog.name(for: country.code))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let lat = country.latitude, let lon = country.longitude {
                center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            } else if let coord = await appVM.representativeCoordinate(for: country.code) {
                center = CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
            }
        }
        .sheet(isPresented: $showPlaceSearch) {
            PlaceSearchSheet(countryCode: country.code, center: center) { name, lat, lon in
                guard !country.places.contains(where: { $0.name == name }) else { return }
                country.places.append(ManualTrip.Place(
                    id: UUID().uuidString, name: name, latitude: lat, longitude: lon
                ))
            }
        }
    }
}

// MARK: - Place search (Apple Maps)

/// Apple Maps autocomplete for a place; on selection resolves the coordinate and hands the
/// name + lat/lon back to the caller.
private struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// The ISO code of the country the place must belong to.
    let countryCode: String
    /// A point inside that country, to bias autocomplete (nil = no bias).
    let center: CLLocationCoordinate2D?
    let onPick: (_ name: String, _ latitude: Double, _ longitude: Double) -> Void

    @State private var completer = LocalSearchCompleter()
    @State private var resolving = false
    @State private var mismatch: String?

    var body: some View {
        @Bindable var completer = completer
        return NavigationStack {
            Group {
                if completer.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView {
                        Label("Search for a place", systemImage: "mappin.and.ellipse")
                    } description: {
                        Text("Find a city, town or landmark in \(CountryCatalog.name(for: countryCode)) with Apple Maps.")
                    }
                } else if completer.isSearching && completer.results.isEmpty {
                    // Not "no results" — Apple Maps simply hasn't answered yet, which on a slow
                    // connection is several seconds of telling the user their search failed.
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Searching…").foregroundStyle(.secondary)
                    }
                } else if completer.results.isEmpty {
                    ContentUnavailableView.search(text: completer.query)
                } else {
                    List(completer.results, id: \.self) { result in
                        Button {
                            resolve(result)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 22)).foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(resolving)
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $completer.query, prompt: "Search a city or place")
            .overlay { if resolving { ProgressView() } }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                if let center {
                    completer.setRegion(latitude: center.latitude, longitude: center.longitude)
                }
            }
            .alert("That place isn't in this country",
                   isPresented: Binding(get: { mismatch != nil }, set: { if !$0 { mismatch = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                if let mismatch { Text("\(mismatch) is in a different country. Add it under that country instead.") }
            }
        }
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        resolving = true
        Task {
            let place = await completer.resolve(completion)
            resolving = false
            guard let place else { return }
            // Keep the picked place inside the selected country.
            if let resolved = place.countryCode, resolved.uppercased() != countryCode.uppercased() {
                mismatch = completion.title
                return
            }
            // Prefer the completion's short title over the resolver's "Name, Country" display.
            onPick(completion.title, place.latitude, place.longitude)
            dismiss()
        }
    }
}
