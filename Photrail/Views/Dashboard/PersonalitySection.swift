import SwiftUI

/// "Your Travel Personality" — a list of category bars with the dominant one highlighted.
struct PersonalitySection: View {
    let profile: TravelPersonalityProfile

    private var maxPercentage: Double {
        max(profile.slices.first?.percentage ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                SectionHeader(title: "Your Travel Personality", systemImage: "person.crop.circle.badge.checkmark")
                Text("Based on your photo locations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(profile.visibleSlices) { slice in
                    PersonalityBar(slice: slice,
                                   fraction: slice.percentage / maxPercentage,
                                   isDominant: slice.category == profile.dominantCategory)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct PersonalityBar: View {
    let slice: TravelPersonalityProfile.Slice
    let fraction: Double
    let isDominant: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(slice.category.emoji)
                .font(.system(size: 22))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(slice.category.title)
                        .font(.subheadline.weight(isDominant ? .bold : .medium))
                    Spacer()
                    Text("\(Int(slice.percentage.rounded()))%")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(isDominant ? Color.accentColor : .secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule()
                            .fill(isDominant ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.accentColor.opacity(0.4)))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 8)
            }
        }
    }
}
