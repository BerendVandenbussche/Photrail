import SwiftUI

extension PlannedTrip {
    /// "Today", "Tomorrow" or "in 12 days".
    func countdownText(now: Date = Date()) -> String {
        let days = daysUntilStart(now: now)
        switch days {
        case ...0: return String(localized: "Today")
        case 1:    return String(localized: "Tomorrow")
        default:   return String(localized: "in \(days) days")
        }
    }

    /// "12 – 19 Mar" style range in the app's locale.
    var dateRangeText: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate, to: endDate)
    }
}

/// Today-tab countdown to the next planned trip. Taps through to the plan.
struct UpcomingTripCard: View {
    let plan: PlannedTrip

    var body: some View {
        header
        .padding(16)
        .card()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 14) {
            FlagCluster(flags: plan.countryCodes.map(CountryCatalog.flag(for:)), size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text("Next trip")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
                    .textCase(.uppercase)
                Text(plan.displayName).font(.headline).lineLimit(1)
                Text(plan.dateRangeText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(plan.countdownText())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.tint)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// A plan in the Places trip list.
struct PlannedTripRow: View {
    let plan: PlannedTrip

    var body: some View {
        HStack(spacing: 14) {
            // Dashed ring: planned, not travelled yet.
            FlagCluster(flags: plan.countryCodes.map(CountryCatalog.flag(for:)), size: 44)
                .overlay(Circle().strokeBorder(Color.accentColor.opacity(0.6),
                                               style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(plan.dateRangeText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(plan.countdownText()).font(.caption.weight(.semibold)).foregroundStyle(.tint)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
