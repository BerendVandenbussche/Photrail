import SwiftUI

/// Generates beautiful shareable stat cards and presents the native share sheet.
struct ShareCardView: View {
    let stats: TravelStats
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTheme: CardTheme = .midnight
    @State private var selectedCard: CardType = .worldPercentage
    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var showShareSheet = false

    enum CardTheme: String, CaseIterable {
        case midnight = "Midnight"
        case dawn = "Dawn"
        case forest = "Forest"
        case ocean = "Ocean"

        var gradient: AnyShapeStyle {
            switch self {
            case .midnight:
                return AnyShapeStyle(LinearGradient(colors: [.black, Color(white: 0.1)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            case .dawn:
                return AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.3),
                                                              Color(red: 1, green: 0.7, blue: 0.4)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            case .forest:
                return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.1, green: 0.35, blue: 0.2),
                                                              Color(red: 0.2, green: 0.55, blue: 0.3)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            case .ocean:
                return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.05, green: 0.15, blue: 0.5),
                                                              Color(red: 0.1, green: 0.55, blue: 0.9)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }

        var textColor: Color { .white }
    }

    enum CardType: String, CaseIterable {
        case worldPercentage = "World %"
        case countriesVisited = "Countries"
        case mostVisited = "Top Country"
        case yearRecap = "2026 Recap"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Card preview
                    StatCardPreview(stats: stats, theme: selectedTheme, cardType: selectedCard)
                        .frame(width: 320, height: 320)
                        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
                        .padding(.top, 20)

                    // Card type picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Style")
                            .font(.headline)
                            .padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(CardType.allCases, id: \.self) { type in
                                    Button(type.rawValue) {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedCard = type
                                        }
                                    }
                                    .font(.subheadline.weight(selectedCard == type ? .semibold : .regular))
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(selectedCard == type ? Color.accentColor : Color.secondary.opacity(0.12),
                                                in: Capsule())
                                    .foregroundStyle(selectedCard == type ? .white : .primary)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    // Theme picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Theme")
                            .font(.headline)
                            .padding(.horizontal, 24)
                        HStack(spacing: 12) {
                            ForEach(CardTheme.allCases, id: \.self) { theme in
                                Button {
                                    withAnimation(.spring(response: 0.3)) { selectedTheme = theme }
                                } label: {
                                    VStack(spacing: 6) {
                                        Circle()
                                            .fill(theme.gradient)
                                            .frame(width: 44, height: 44)
                                            .overlay {
                                                if selectedTheme == theme {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.weight(.bold))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                        Text(theme.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(selectedTheme == theme ? .primary : .secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Share button
                    Button {
                        renderAndShare()
                    } label: {
                        HStack {
                            if isRendering {
                                ProgressView().tint(.white)
                            } else {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                    }
                    .disabled(isRendering)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    private func renderAndShare() {
        isRendering = true
        Task { @MainActor in
            let renderer = ImageRenderer(content:
                StatCardPreview(stats: stats, theme: selectedTheme, cardType: selectedCard)
                    .frame(width: 1080, height: 1080)
            )
            renderer.scale = 1
            renderedImage = renderer.uiImage
            isRendering = false
            showShareSheet = renderedImage != nil
        }
    }
}

// MARK: - Card content

struct StatCardPreview: View {
    let stats: TravelStats
    let theme: ShareCardView.CardTheme
    let cardType: ShareCardView.CardType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(theme.gradient)

            VStack(spacing: 16) {
                Spacer()
                cardContent
                Spacer()
                HStack {
                    Spacer()
                    Text("Photrail")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textColor.opacity(0.5))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var cardContent: some View {
        switch cardType {
        case .worldPercentage:
            worldPercentageCard
        case .countriesVisited:
            countriesCard
        case .mostVisited:
            mostVisitedCard
        case .yearRecap:
            yearRecapCard
        }
    }

    private var worldPercentageCard: some View {
        VStack(spacing: 8) {
            Text(String(format: "%.1f%%", stats.worldPercentage))
                .font(.system(size: 80, weight: .black, design: .rounded))
                .foregroundStyle(theme.textColor)
            Text("of the world explored")
                .font(.title3.weight(.medium))
                .foregroundStyle(theme.textColor.opacity(0.8))
        }
    }

    private var countriesCard: some View {
        VStack(spacing: 8) {
            Text("\(stats.countryCount)")
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(theme.textColor)
            Text("countries visited")
                .font(.title3.weight(.medium))
                .foregroundStyle(theme.textColor.opacity(0.8))
            HStack(spacing: -8) {
                ForEach(stats.recentCountries.prefix(5)) { c in
                    Text(c.flag)
                        .font(.title)
                }
            }
            .padding(.top, 8)
        }
    }

    private var mostVisitedCard: some View {
        if let top = stats.mostPhotographedCountry {
            AnyView(VStack(spacing: 8) {
                Text(top.flag)
                    .font(.system(size: 80))
                Text(top.name)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textColor)
                Text("\(top.photoCount) photos captured")
                    .font(.subheadline)
                    .foregroundStyle(theme.textColor.opacity(0.7))
            })
        } else {
            AnyView(EmptyView())
        }
    }

    private var yearRecapCard: some View {
        VStack(spacing: 12) {
            Text("2026 Recap")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textColor.opacity(0.7))
            Text("\(stats.countryCount) countries")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(theme.textColor)
            Text("\(stats.cityCount) cities · \(stats.totalGeotaggedPhotos.formatted()) photos")
                .font(.subheadline)
                .foregroundStyle(theme.textColor.opacity(0.7))
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ShareCardView(stats: .mock)
}
