import SwiftUI

/// Lets the user add countries by hand (for trips whose photos are gone) so the
/// stats stay accurate. Countries already detected from photos are shown as locked.
struct ManualCountryPickerView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    /// Codes detected from photos (not manual) — locked in the picker.
    private var photoCodes: Set<String> {
        Set(appVM.stats.countries.map(\.id)).subtracting(appVM.manualCountries.map(\.code))
    }
    private var manualCodes: Set<String> { Set(appVM.manualCountries.map(\.code)) }

    private var filtered: [CountryCatalog.Option] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return CountryCatalog.all }
        return CountryCatalog.all.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { option in row(option) }
                .listStyle(.plain)
                .searchable(text: $search, prompt: "Search countries")
                .navigationTitle("Add Countries")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                }
        }
    }

    @ViewBuilder
    private func row(_ option: CountryCatalog.Option) -> some View {
        let fromPhotos = photoCodes.contains(option.code)
        let manual = manualCodes.contains(option.code)
        Button {
            if manual { appVM.removeManualCountry(code: option.code) }
            else if !fromPhotos { appVM.addManualCountry(code: option.code) }
        } label: {
            HStack(spacing: 12) {
                Text(option.flag).font(.system(size: 26))
                Text(option.name).foregroundStyle(fromPhotos ? .secondary : .primary)
                Spacer()
                if fromPhotos {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else if manual {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(fromPhotos)
    }
}

#Preview {
    ManualCountryPickerView().environment(AppViewModel.preview)
}
