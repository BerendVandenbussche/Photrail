import SwiftUI

/// Bar chart timeline of monthly photo activity.
struct TimelineSection: View {
    let entries: [TimelineEntry]

    private var maxCount: Int { entries.map(\.photoCount).max() ?? 1 }
    private var recentEntries: [TimelineEntry] { Array(entries.suffix(12)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if recentEntries.isEmpty {
                Text("No timeline data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(recentEntries) { entry in
                        TimelineBar(entry: entry, maxCount: maxCount)
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TimelineBar: View {
    let entry: TimelineEntry
    let maxCount: Int
    @State private var appeared = false

    private var ratio: Double { Double(entry.photoCount) / Double(maxCount) }

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.gradient)
                .frame(height: appeared ? max(4, 80 * ratio) : 4)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double.random(in: 0...0.2)),
                           value: appeared)

            Text(entry.monthLabel.prefix(3))
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .onAppear { appeared = true }
    }
}

#Preview {
    TimelineSection(entries: TravelStats.mock.timelineEntries)
        .padding()
}
