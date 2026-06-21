import SwiftUI

/// The 2×2 grid of headline stats on the dashboard.
struct StatsCardsSection: View {
    let stats: TravelStats

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    icon: "globe.europe.africa.fill",
                    value: String(format: "%.1f%%", stats.worldPercentage),
                    label: "World explored",
                    iconColor: .blue
                )
                StatCard(
                    icon: "flag.fill",
                    value: "\(stats.countryCount)",
                    label: "Countries visited",
                    iconColor: .orange
                )
            }
            HStack(spacing: 12) {
                StatCard(
                    icon: "mappin.and.ellipse",
                    value: "\(stats.cityCount)",
                    label: "Cities visited",
                    iconColor: .pink
                )
                StatCard(
                    icon: "photo.stack.fill",
                    value: stats.totalGeotaggedPhotos.formatted(),
                    label: "Geotagged photos",
                    iconColor: .purple
                )
            }
        }
    }
}

#Preview {
    StatsCardsSection(stats: .mock)
        .padding()
}
