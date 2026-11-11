import SwiftUI

/// On a past trip without flights: how Photrail thinks you flew, from photos taken at airports
/// (and from the plane). Airports no photo shows carry a "?". Nothing is saved until Add.
struct FlightHintCard: View {
    let hint: FlightHint
    /// Airports near home to choose from when the home airport is only a guess.
    let homeChoices: [AirportDirectory.Airport]
    let onPickHome: (String) -> Void
    let onAdd: () -> Void
    let onEdit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "airplane")
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Did you fly like this?").font(.headline)
                    Text(verbatim: hint.routeText)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
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

            if hint.homeIsGuess, let code = hint.homeAirport, homeChoices.count > 1 {
                Menu {
                    ForEach(homeChoices) { airport in
                        Button { onPickHome(airport.iata) } label: {
                            Text(verbatim: "\(airport.iata) · \(airport.placeName)")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("From \(code)")
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .font(.subheadline.weight(.medium))
                }
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
