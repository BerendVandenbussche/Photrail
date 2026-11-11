import SwiftUI

/// The info page for one country of a planned trip, opened from the ⓘ on its row: plugs and
/// voltage, languages, currency, time difference, driving side and calling code, each held
/// against home where that helps.
struct CountryInfoView: View {
    let tips: CountryTips

    @Environment(\.dismiss) private var dismiss

    private var info: CountryInfo { tips.info }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        Text(CountryCatalog.flag(for: tips.countryCode)).font(.system(size: 64))
                        Text(CountryCatalog.name(for: tips.countryCode)).font(.title2.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section {
                    row("powerplug", "Plugs", Text(verbatim: "\(info.plugText) · \(info.powerText)"),
                        notes: voltageNotes, extra: AnyView(plugsDetail))
                    let languages = info.languageNames()
                    if !languages.isEmpty {
                        row("character.bubble", "Languages", Text(verbatim: languages.joined(separator: ", ")))
                    }
                    if let currency = info.currencyName() {
                        row("banknote", "Currency",
                            tips.sameCurrency == true ? Text("\(currency), like at home") : Text(verbatim: currency))
                    }
                    if let time = tips.timeDifference {
                        row("clock", "Time", timeText(time))
                    }
                    row("car", "Traffic", drivingText)
                    row("phone", "Calling code", Text(verbatim: info.callingCodeText))
                } header: {
                    Text("Good to know")
                }
            }
            .navigationTitle(Text(verbatim: CountryCatalog.name(for: tips.countryCode)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    // MARK: - Rows

    private struct Note {
        let text: Text
        let warning: Bool
    }

    private func row(_ icon: String, _ title: LocalizedStringKey, _ value: Text,
                     notes: [Note] = [], extra: AnyView? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                value.font(.subheadline)
                if let extra { extra.padding(.vertical, 4) }
                ForEach(notes.indices, id: \.self) { i in
                    notes[i].text
                        .font(.caption)
                        .foregroundStyle(notes[i].warning ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// What the sockets look like, with a check on the ones your plugs from home go into.
    private var sockets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(info.plugs, id: \.self) { type in
                    VStack(spacing: 4) {
                        SocketIcon(type: type, size: 46)
                            .overlay(alignment: .topTrailing) {
                                if tips.socketsForHomePlugs?.contains(type) == true {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.white, .green)
                                        .offset(x: 4, y: -4)
                                }
                            }
                        Text(verbatim: type).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    /// The sockets there, then (with a home country) the user's own plugs and whether each fits.
    private var plugsDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            sockets
            if let home = tips.homeCountryCode, !tips.homePlugs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your plugs from \(CountryCatalog.name(for: home)):")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(tips.homePlugs, id: \.self) { type in
                        homePlugRow(type)
                    }
                }
            }
        }
    }

    private func homePlugRow(_ type: String) -> some View {
        let fits = tips.homePlugFits(type)
        return HStack(spacing: 10) {
            SocketIcon(type: type, size: 34, plug: true)
            VStack(alignment: .leading, spacing: 2) {
                (Text(Self.plugDescription(type)) + Text(verbatim: " (\(type))"))
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Image(systemName: fits ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    fits ? Text("Fits") : Text("Needs an adapter")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(fits ? .green : .orange)
            }
        }
    }

    /// What a plug of this type looks like, in words.
    static func plugDescription(_ type: String) -> LocalizedStringKey {
        switch type {
        case "A": return "Two flat pins"
        case "B": return "Two flat pins and a round earth pin"
        case "C": return "Two thin pins, like most chargers"
        case "D", "H": return "Three round pins in a triangle"
        case "E", "F": return "Thicker round plug with earth"
        case "G": return "Three rectangular pins"
        case "I": return "Two angled flat pins and an earth pin"
        case "J": return "Three round pins, Swiss style"
        case "K", "O": return "Two round pins and an earth pin below"
        case "L": return "Three round pins in a row"
        case "M": return "Three large round pins in a triangle"
        case "N": return "Three round pins, Brazilian style"
        default: return "Plug"
        }
    }

    private var voltageNotes: [Note] {
        var notes: [Note] = []
        switch tips.voltageAdvice {
        case .lower:
            notes.append(Note(text: Text("Lower voltage than at home: check that your chargers handle 100–240 V"),
                              warning: true))
        case .higher:
            notes.append(Note(text: Text("Higher voltage than at home: check that your devices handle it"),
                              warning: true))
        case .same:
            break
        }
        return notes
    }

    private func timeText(_ time: CountryTips.TimeDifference) -> Text {
        switch time {
        case .same:
            return Text("Same time as home")
        case let .hours(low, high):
            let ahead = low >= 0 && high >= 0
            let behind = low <= 0 && high <= 0
            // Show the size of the difference: "7", or "4–7" for countries with several zones.
            let a = Self.hours(min(abs(low), abs(high))), b = Self.hours(max(abs(low), abs(high)))
            let amount = a == b ? a : "\(a)–\(b)"
            if ahead { return Text("\(amount) h ahead of home") }
            if behind { return Text("\(amount) h behind home") }
            return Text(verbatim: "\(Self.hours(low, signed: true)) … \(Self.hours(high, signed: true)) h")
        }
    }

    private static func hours(_ value: Double, signed: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        if signed { formatter.positivePrefix = "+" }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var drivingText: Text {
        switch (info.drivesOnLeft, tips.sameDrivingSide) {
        case (true, true?): return Text("Drives on the left, like at home")
        case (false, true?): return Text("Drives on the right, like at home")
        case (true, false?): return Text("Drives on the left, unlike at home")
        case (false, false?): return Text("Drives on the right, unlike at home")
        case (true, nil): return Text("Drives on the left")
        case (false, nil): return Text("Drives on the right")
        }
    }
}
