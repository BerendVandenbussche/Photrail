import SwiftUI

/// A small pulsing dot that marks something as happening right now.
struct LiveDot: View {
    var color: Color = .red
    var size: CGFloat = 8
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color.opacity(0.45))
                    .scaleEffect(pulsing ? 2.4 : 1)
                    .opacity(pulsing ? 0 : 1)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// "● LIVE" pill for the header of a trip the user is on right now.
struct LiveTripPill: View {
    var body: some View {
        HStack(spacing: 6) {
            LiveDot(color: .white, size: 7)
            Text("Live").font(.system(size: 11, weight: .heavy)).tracking(1.2)
                .textCase(.uppercase)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Color.red))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("You're on this trip right now"))
    }
}

/// Today-tab card for the trip the user is on right now. Taps through to the trip.
struct CurrentTripCard: View {
    let trip: Trip

    /// "Day 3" counts calendar days since the trip's first photo, today included while the
    /// trip is current (it last saw a photo today or yesterday).
    private var dayNumber: Int {
        let calendar = Calendar.current
        let current = calendar.isDateInToday(trip.endDate) || calendar.isDateInYesterday(trip.endDate)
        let lastDay = current ? Date() : trip.endDate
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: trip.startDate),
                                           to: calendar.startOfDay(for: lastDay)).day ?? 0
        return max(1, days + 1)
    }

    private var detailLine: String {
        var parts = [String(localized: "Day \(dayNumber)")]
        if !trip.cities.isEmpty {
            let shown = trip.cities.prefix(2).joined(separator: ", ")
            parts.append(trip.cities.count > 2 ? "\(shown) +\(trip.cities.count - 2)" : shown)
        }
        parts.append(String(localized: "\(trip.photoCount) photos"))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            FlagCluster(flags: trip.countries.map(\.flag), size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    LiveDot(size: 7)
                    Text("You're traveling")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .textCase(.uppercase)
                }
                Text(trip.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(detailLine)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(16)
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: AppCard.radius, style: .continuous)
                .strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
