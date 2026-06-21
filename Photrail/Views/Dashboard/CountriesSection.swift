import SwiftUI

/// Horizontal scroll of country cards; tapping opens CountryDetailView.
struct CountriesSection: View {
    let countries: [CountryStat]
    var onSelect: (CountryStat) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(countries) { country in
                    CountryCard(country: country)
                        .onTapGesture { onSelect(country) }
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
    @State private var pressed = false

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
        .scaleEffect(pressed ? 0.96 : 1)
        .animation(.spring(response: 0.2), value: pressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 10) {
        } onPressingChanged: { isPressing in
            pressed = isPressing
        }
    }
}

#Preview {
    CountriesSection(countries: TravelStats.mock.countries) { _ in }
}
