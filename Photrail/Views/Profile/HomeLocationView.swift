import SwiftUI
import MapKit

/// Sheet for choosing the user's home by searching Apple Maps for any city — no longer
/// limited to cities resolved from photos. Picking a result stores its coordinate.
struct HomeLocationView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var completer = LocalSearchCompleter()
    @State private var resolving = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let home = appVM.homeDisplayName {
                        HStack {
                            Image(systemName: "house.fill").foregroundStyle(.tint)
                            Text(home)
                            Spacer()
                            Button("Clear") { appVM.clearHome() }
                                .font(.subheadline)
                        }
                    } else {
                        Text("No home set").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Home")
                } footer: {
                    Text("Search for your home city. Used for the furthest‑trip calculation and to exclude everyday photos near home from your travel personality.")
                }

                if completer.isSearching && completer.results.isEmpty {
                    Section("Results") {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching…").foregroundStyle(.secondary)
                        }
                    }
                } else if !completer.results.isEmpty {
                    Section("Results") {
                        ForEach(completer.results, id: \.self) { result in
                            Button {
                                Task { await select(result) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title).foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(resolving)
                        }
                    }
                }
            }
            .searchable(text: $completer.query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search for a city")
            .overlay {
                if resolving { ProgressView() }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func select(_ suggestion: LocalSearchCompleter.Suggestion) async {
        resolving = true
        defer { resolving = false }
        guard let place = await completer.resolve(suggestion) else { return }
        appVM.setHome(name: place.name,
                      latitude: place.latitude,
                      longitude: place.longitude,
                      countryCode: place.countryCode)
        dismiss()
    }
}
