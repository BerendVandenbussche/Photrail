import SwiftUI

struct WondersListView: View {
    let wonders: [WonderStat]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWonder: WonderStat?

    /// Wonders for a category, seen first (most recent first), then unseen alphabetically.
    private func items(in category: WonderCategory) -> [WonderStat] {
        wonders
            .filter { $0.wonder.category == category }
            .sorted {
                if $0.seen != $1.seen { return $0.seen && !$1.seen }
                if $0.seen {
                    return ($0.lastSeen ?? .distantPast) > ($1.lastSeen ?? .distantPast)
                }
                return $0.wonder.name < $1.wonder.name
            }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(WonderCategory.allCases, id: \.self) { category in
                    let entries = items(in: category)
                    if !entries.isEmpty {
                        Section {
                            ForEach(entries) { stat in
                                if stat.seen {
                                    Button { selectedWonder = stat } label: {
                                        WonderRow(stat: stat)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    WonderRow(stat: stat)
                                }
                            }
                        } header: {
                            HStack {
                                Text(category.rawValue)
                                Spacer()
                                Text("\(entries.filter { $0.seen }.count) of \(entries.count)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Wonders & Landmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedWonder) { wonder in
                WonderDetailView(stat: wonder)
            }
        }
    }
}

private struct WonderRow: View {
    let stat: WonderStat

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(stat.seen ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 46, height: 46)
                Text(stat.wonder.emoji)
                    .font(.system(size: 24))
                    .grayscale(stat.seen ? 0 : 1)
                    .opacity(stat.seen ? 1 : 0.5)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.wonder.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(stat.seen ? .primary : .secondary)
                Text("\(stat.wonder.flagEmoji) \(subtitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if stat.seen {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        guard stat.seen else { return "Not yet visited" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        let count = "\(stat.photoCount) \(stat.photoCount == 1 ? "photo" : "photos")"
        if let last = stat.lastSeen {
            return "\(count) · \(fmt.string(from: last))"
        }
        return count
    }
}

#Preview {
    WondersListView(wonders: TravelStats.mock.wonders)
}
