import SwiftUI

struct WondersSection: View {
    let wonders: [WonderStat]
    var onSeeAll: () -> Void

    // The dashboard carousel features the official New 7 Wonders; the full list
    // (via "see all") also includes other famous landmarks.
    private var sevenWonders: [WonderStat] {
        wonders.filter { $0.wonder.category == .sevenWonders }
    }
    private var seenCount: Int { sevenWonders.filter { $0.seen }.count }
    private var total: Int { sevenWonders.count }

    // Seen wonders first, so the carousel leads with the user's achievements.
    private var ordered: [WonderStat] {
        sevenWonders.sorted { ($0.seen ? 0 : 1, $0.wonder.name) < ($1.seen ? 0 : 1, $1.wonder.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onSeeAll) {
                HStack {
                    SectionHeader(title: "World Wonders", systemImage: "star.circle.fill")
                    Spacer()
                    Text("\(seenCount) of \(total)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 20)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ordered) { stat in
                        Button(action: onSeeAll) {
                            WonderCard(stat: stat)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct WonderCard: View {
    let stat: WonderStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.wonder.emoji)
                    .font(.system(size: 28))
                    .grayscale(stat.seen ? 0 : 1)
                    .opacity(stat.seen ? 1 : 0.5)
                Spacer()
                Image(systemName: stat.seen ? "checkmark.seal.fill" : "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(stat.seen ? .green : .secondary)
            }
            Text(stat.wonder.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .foregroundStyle(stat.seen ? .primary : .secondary)

            Text("\(stat.wonder.flagEmoji) \(stat.seen ? "Seen" : "Not yet")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 140, height: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(stat.seen ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(stat.seen ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
