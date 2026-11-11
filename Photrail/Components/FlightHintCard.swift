import SwiftUI

/// On a past trip without flights: how Photrail thinks you flew, from photos taken at airports
/// (and from the plane). Shows the route in place names; tapping it opens the flights one by
/// one on a map (`FlightHintDetailSheet`). Nothing is saved until Add.
struct FlightHintCard: View {
    let hint: FlightHint
    /// Airports near home to choose from when the home airport is only a guess.
    let homeChoices: [AirportDirectory.Airport]
    let onPickHome: (String) -> Void
    let onShowDetails: () -> Void
    let onAdd: () -> Void
    let onEdit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onShowDetails) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "airplane")
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Did you fly like this?").font(.headline)
                            Text(verbatim: hint.placesText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Shows the flights on a map"))

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Hide suggestion"))
            }

            if hint.homeIsGuess, homeChoices.count > 1 {
                HomeAirportMenu(hint: hint, choices: homeChoices, onPick: onPickHome)
                    .padding(.leading, 36)
            }

            HStack(spacing: 10) {
                Button(action: onAdd) {
                    Text("Add these flights").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)
            }

            Text("A guess from your photos at airports.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppCard.padding)
        .card()
    }
}

/// "From Brussels ▾": picks the home airport when it's only a guess.
private struct HomeAirportMenu: View {
    let hint: FlightHint
    let choices: [AirportDirectory.Airport]
    let onPick: (String) -> Void

    var body: some View {
        if let code = hint.homeAirport {
            Menu {
                ForEach(choices) { airport in
                    Button { onPick(airport.iata) } label: {
                        Text(verbatim: "\(airport.placeName) (\(airport.iata))")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("From \(AirportDirectory.airport(code)?.placeName ?? code)")
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(.medium))
            }
        }
    }
}

/// The suggested flights one by one, with the route on a map: where each one leaves from and
/// lands, which airports a photo shows and which are guessed. Add and Edit as on the card.
struct FlightHintDetailSheet: View {
    let hint: FlightHint
    let homeChoices: [AirportDirectory.Airport]
    let onPickHome: (String) -> Void
    let onAdd: () -> Void
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FlightRouteMap(flights: hint.flights)
                        .frame(height: 260)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(hint.legs, id: \.flight.id) { leg in
                        FlightHintLegRow(leg: leg)
                    }
                } footer: {
                    if hint.legs.contains(where: { !$0.fromSeen || !$0.toSeen }) {
                        Text("Guessed airports don't appear in any of your photos. Check them before you add the flights.")
                    }
                }

                if hint.homeIsGuess, homeChoices.count > 1 {
                    Section {
                        HomeAirportMenu(hint: hint, choices: homeChoices, onPick: onPickHome)
                    }
                }

                Section {
                    Button {
                        dismiss()
                        onAdd()
                    } label: {
                        Text("Add these flights").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    Button("Edit", action: onEdit)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Suggested flights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

/// One suggested flight: the date, then where it leaves from and lands, each with its city,
/// airport name and whether a photo shows it.
private struct FlightHintLegRow: View {
    let leg: FlightHint.Leg

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let date = leg.flight.date {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            airport(leg.flight.from, seen: leg.fromSeen, icon: "airplane.departure")
            airport(leg.flight.to, seen: leg.toSeen, icon: "airplane.arrival")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func airport(_ code: String, seen: Bool, icon: String) -> some View {
        let airport = AirportDirectory.airport(code)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "\(airport?.flag ?? "") \(airport?.placeName ?? code)")
                    .font(.body.weight(.semibold))
                Text(verbatim: airport.map { "\($0.name) · \(code)" } ?? code)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if seen {
                Label("In your photos", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label("Guessed", systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
