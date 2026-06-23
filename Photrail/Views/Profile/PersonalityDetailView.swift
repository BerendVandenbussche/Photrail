import SwiftUI

/// Explains what a single travel-personality category was based on.
struct PersonalityDetailView: View {
    let category: TravelCategory
    let profile: TravelPersonalityProfile
    @Environment(\.dismiss) private var dismiss

    private var percentage: Int {
        Int((profile.categoryPercentages[category] ?? 0).rounded())
    }
    private var photoCount: Int { profile.photoCount(for: category) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    infoCard(icon: "photo.on.rectangle.angled",
                             title: photoCount == 1 ? "1 photo" : "\(photoCount) photos",
                             detail: "contributed to this style")

                    infoCard(icon: "questionmark.circle",
                             title: "How it's measured",
                             detail: category.basis)

                    Text("Your travel personality is calculated entirely on‑device from where your photos were taken. Everyday photos within 50 km of home are excluded so it reflects your travels.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                    Spacer(minLength: 20)
                }
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(category.emoji).font(.system(size: 64))
            Text("\(percentage)%")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.tint)
            Text(category.title)
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func infoCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

#Preview {
    PersonalityDetailView(category: .nature, profile: .empty)
}
