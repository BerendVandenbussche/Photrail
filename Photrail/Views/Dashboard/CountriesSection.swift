import SwiftUI

/// Horizontal scroll of country cards; tapping opens CountryDetailView.
struct CountriesSection: View {
    let countries: [CountryStat]
    var onSelect: (CountryStat) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(countries) { country in
                    Button { onSelect(country) } label: {
                        CountryCard(country: country)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}

private struct CountryCard: View {
    let country: CountryStat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(country.flag)
                .font(.system(size: 40))

            VStack(alignment: .leading, spacing: 2) {
                Text(country.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(country.photoCount) photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("\(country.cityCount) cities", systemImage: "mappin.and.ellipse")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 140, height: 150)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    CountriesSection(countries: TravelStats.mock.countries) { _ in }
}
