import SwiftUI

struct ContinentsSection: View {
    let continents: [ContinentStat]
    var onSelect: (ContinentStat) -> Void

    private var visitedCount: Int {
        continents.filter { $0.continent != .antarctica && $0.visited }.count
    }
    private var total: Int { Continent.visitable.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with summary count
            HStack {
                SectionHeader(title: "Continents", systemImage: "globe")
                Spacer()
                Text("\(visitedCount) of \(total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 20)
            }
            .padding(.horizontal, 20)

            // Continent cards horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(continents) { stat in
                        Button { onSelect(stat) } label: {
                            ContinentCard(stat: stat)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct ContinentCard: View {
    let stat: ContinentStat

    private var isBonus: Bool { stat.continent == .antarctica }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.continent.emoji)
                    .font(.system(size: 28))
                Spacer()
                if isBonus {
                    Text("BONUS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.orange))
                } else if stat.visited {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.footnote)
                }
            }
            Text(stat.continent.rawValue)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if stat.visited {
                Text("\(stat.countryCount) \(stat.countryCount == 1 ? "country" : "countries")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not yet visited")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(width: 130)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(stat.visited ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    stat.visited ? Color.accentColor.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
