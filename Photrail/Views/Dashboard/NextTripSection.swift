import SwiftUI

/// "Where next?" — the one place in the app that points forward instead of back.
///
/// The destination itself is chosen by `DestinationRanker` from measured data; the sentence
/// under it is written by `TripPitchWriterFactory.make()`, which is Apple's on-device model
/// where that exists and a localized template everywhere else. The footnote says which, and
/// only ever claims Apple Intelligence when it was actually Apple Intelligence.
struct NextTripSection: View {
    let suggestion: TripSuggestion
    let locked: Bool
    var onUnlock: () -> Void
    var onAnother: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Where next?", systemImage: "sparkles")
                .padding(.horizontal, 20)

            if locked {
                Button(action: onUnlock) { lockedCard }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
            } else {
                card
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Unlocked

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let pitch = suggestion.pitch, !pitch.isEmpty {
                Text(pitch)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // A redacted placeholder rather than a spinner: the card is already showing a
                // real destination, and only the sentence is still being written.
                Text(verbatim: "————————————————— ——————————")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .redacted(reason: .placeholder)
                    .accessibilityLabel(Text("Writing your suggestion"))
            }

            HStack {
                // Two separate literals rather than a ternary inside `Text`, so both keys are
                // extracted into the string catalog.
                Group {
                    if suggestion.generatedByModel {
                        Label("Written on your device by Apple Intelligence",
                              systemImage: "apple.intelligence")
                    } else {
                        Label("Suggested on your device", systemImage: "iphone")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                Spacer()

                if suggestion.hasAlternatives {
                    Button(action: onAnother) {
                        Text("Show me another")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }
        }
        .padding(AppCard.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(suggestion.destination.emoji)
                .font(.system(size: 34))

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.destination.name)
                    .font(.headline)
                // For a wonder this is the country it's in; for a country it would just repeat
                // the title, so it becomes the places worth starting from instead.
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // `verbatim` because a bare number with a trailing percent sign is not a phrase to
            // translate, and would otherwise become a "%lld%" catalog key.
            Text(verbatim: matchText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .accessibilityLabel(Text("\(matchText) match"))
        }
    }

    private var matchText: String {
        (suggestion.match).formatted(.percent.precision(.fractionLength(0)))
    }

    private var subtitle: String? {
        let destination = suggestion.destination
        if destination.isWonder {
            return CountryCatalog.name(for: destination.countryCode)
        }
        guard !destination.highlights.isEmpty else { return nil }
        return destination.highlights.formatted(.list(type: .and))
    }

    // MARK: - Locked

    /// Names nothing. The point of the paywall is that the answer is what's behind it, so the
    /// card advertises the shape of the feature rather than spoiling its output.
    private var lockedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 26))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text("Your next trip, picked for you")
                    .font(.headline)
                Text("Matched to how you travel, worked out entirely on your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.tint)
        }
        .padding(AppCard.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
