import SwiftUI

struct ContinentDetailView: View {
    let stat: ContinentStat
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCountry: CountryStat?

    private var countries: [CountryStat] {
        stat.countries.sorted { $0.photoCount > $1.photoCount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    headerSection
                    statsRow
                        .padding(.horizontal, 20)
                    countriesSection
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedCountry) { country in
                CountryDetailView(country: country)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(stat.continent.emoji)
                .font(.system(size: 72))
            Text(stat.continent.rawValue)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(stat.visited ? "Visited" : "Not yet visited")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(icon: "flag.fill", value: "\(stat.countryCount)",
                     label: stat.countryCount == 1 ? "Country" : "Countries", iconColor: .orange)
            StatCard(icon: "photo.stack.fill", value: "\(stat.photoCount)",
                     label: "Photos", iconColor: .blue)
        }
    }

    private var countriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Countries")
                .padding(.horizontal, 20)

            if countries.isEmpty {
                Text("No countries visited on this continent yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            } else {
                ForEach(countries) { country in
                    Button { selectedCountry = country } label: {
                        CountryRow(country: country)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                    if country.id != countries.last?.id {
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
    }
}

private struct CountryRow: View {
    let country: CountryStat

    var body: some View {
        HStack(spacing: 14) {
            Text(country.flag)
                .font(.system(size: 34))
            VStack(alignment: .leading, spacing: 2) {
                Text(country.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(country.photoCount) photos · \(country.cityCount) cities")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    ContinentDetailView(
        stat: ContinentStat(continent: .europe, countries: TravelStats.mock.countries, photoCount: 482)
    )
}
