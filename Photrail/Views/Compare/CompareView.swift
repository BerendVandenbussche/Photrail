import SwiftUI

/// What you see after opening a friend's compare link: their countries against yours.
struct CompareView: View {
    let payload: ComparePayload
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var showShareBack = false

    private var mine: Set<String> { Set(appVM.stats.countries.map { $0.id.uppercased() }) }
    private var theirs: Set<String> { payload.countryCodes }
    private var together: Set<String> { mine.intersection(theirs) }
    private var onlyMine: Set<String> { mine.subtracting(theirs) }
    private var onlyTheirs: Set<String> { theirs.subtracting(mine) }

    /// "Berend", or "Your friend" when they left the name out.
    private var friendName: String { payload.name ?? String(localized: "Your friend") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    numbers
                    continents
                    group(title: "Been there together", codes: together)
                    group(title: "Only \(friendName)", codes: onlyTheirs)
                    group(title: "Only you", codes: onlyMine)

                    Button { showShareBack = true } label: {
                        Label("Share yours back", systemImage: "qrcode")
                            .font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, AppCard.inset)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareBack) { CompareShareView() }
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            avatar(payload.emoji, label: friendName)
            Text("vs")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
            avatar(appVM.profileEmoji, label: String(localized: "You"))
        }
    }

    private func avatar(_ emoji: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(verbatim: emoji)
                .font(.system(size: 40))
                .frame(width: 76, height: 76)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(verbatim: label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: 120)
    }

    private var numbers: some View {
        HStack(spacing: 10) {
            numberTile(theirs.count, label: friendName)
            numberTile(together.count, label: String(localized: "Together"), highlighted: true)
            numberTile(mine.count, label: String(localized: "You"))
        }
        .padding(.horizontal, AppCard.inset)
    }

    private func numberTile(_ value: Int, label: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            Text(verbatim: label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("countries")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card()
    }

    /// Per continent: how many countries each of you has been to there.
    private var continents: some View {
        let rows = Continent.allCases.compactMap { continent -> (Continent, Int, Int)? in
            let them = theirs.filter { ContinentMapper.continent(for: $0) == continent }.count
            let me = mine.filter { ContinentMapper.continent(for: $0) == continent }.count
            return them + me == 0 ? nil : (continent, them, me)
        }
        return Group {
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("Continents").font(.headline)
                        Spacer()
                        Text(verbatim: payload.emoji).frame(width: 44)
                        Text(verbatim: appVM.profileEmoji).frame(width: 44)
                    }
                    .padding(.bottom, 8)
                    ForEach(rows, id: \.0) { continent, them, me in
                        HStack {
                            Text(verbatim: "\(continent.emoji) \(continent.displayName)")
                                .font(.subheadline)
                            Spacer()
                            Text("\(them)").font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(them > me ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                                .frame(width: 44)
                            Text("\(me)").font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(me > them ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                                .frame(width: 44)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(AppCard.padding)
                .card()
                .padding(.horizontal, AppCard.inset)
            }
        }
    }

    @ViewBuilder
    private func group(title: LocalizedStringKey, codes: Set<String>) -> some View {
        if !codes.isEmpty {
            let sorted = codes.map { (code: $0, name: CountryCatalog.name(for: $0)) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Text("\(codes.count)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)],
                          alignment: .leading, spacing: 8) {
                    ForEach(sorted, id: \.code) { country in
                        Text(verbatim: "\(CountryCatalog.flag(for: country.code)) \(country.name)")
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            }
            .padding(AppCard.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .padding(.horizontal, AppCard.inset)
        }
    }
}
