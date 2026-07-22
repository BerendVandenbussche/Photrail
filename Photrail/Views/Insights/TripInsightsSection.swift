import SwiftUI

/// The "Trip Insights" section rendered inside `TripDetailView`. Handles the late opt-in,
/// loading, empty state, and the per-feature cards. Excitement badges themselves appear on
/// individual photos (full-screen viewer); here we show a summary.
struct TripInsightsSection: View {
    let trip: Trip
    /// Populated after computing so the trip's photo grid can badge photos with their vibe.
    @Binding var excitement: [String: ExcitementSample]

    @Environment(AppViewModel.self) private var appVM
    @State private var insights: TripInsights?
    @State private var loading = false
    @State private var selectedChapter: WorkoutChapter?

    /// Once the user dismisses the opt-in card, hide the whole section on every trip so
    /// they're greeted with useful content instead. They can still enable it from the Me tab.
    private var isHidden: Bool { !appVM.insightsEnabled && appVM.insightsPromptDismissed }

    var body: some View {
        Group {
            if isHidden {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Trip Insights").padding(.horizontal, 20)

                    if !appVM.insightsEnabled {
                        InsightsPermissionPrompt(
                            onEnable: { Task { await enable() } },
                            onDismiss: { appVM.insightsPromptDismissed = true })
                    } else if let insights {
                        if !insights.authorized || !insights.hasAnyContent {
                            InsightsEmptyState { appVM.openSettings() }
                        } else {
                            content(insights)
                        }
                    } else {
                        loadingCard
                    }
                }
            }
        }
        .task { if appVM.insightsEnabled, insights == nil { await load() } }
        .sheet(item: $selectedChapter) { WorkoutChapterView(chapter: $0) }
    }

    // MARK: - State transitions

    private func enable() async {
        _ = await appVM.enableInsights()
        await load()
    }

    private func load() async {
        loading = true
        let result = await appVM.computeInsights(for: trip)
        insights = result
        excitement = Dictionary(result.excitement.map { ($0.photoID, $0) }, uniquingKeysWith: { a, _ in a })
        loading = false
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Reading your Health data…").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppCard.padding)
        .card()
        .padding(.horizontal, 20)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ insights: TripInsights) -> some View {
        VStack(spacing: 12) {
            if let flights = insights.flightsClimbed, let milestone = insights.elevationMilestone {
                elevationCard(flights: flights, milestone: milestone)
            }
            if let kcal = insights.activeEnergyKcal, let food = insights.foodEquivalent {
                fuelCard(kcal: kcal, food: food)
            }
            if let persona = insights.persona {
                personaCard(persona)
            }
            if !insights.excitement.isEmpty {
                excitementCard(insights.excitement)
            }
            if !insights.workoutChapters.isEmpty {
                workoutsCard(insights.workoutChapters)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Feature cards

    private func elevationCard(flights: Int, milestone: ElevationMilestone) -> some View {
        InsightCard(icon: "mountain.2.fill", tint: .green, title: "Vertical Exploration") {
            Text("\(flights) flights climbed")
                .font(.subheadline.weight(.bold))
            Text("\(milestone.emoji) That's \(formatted(milestone.multiple))× the \(milestone.landmarkName)!")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fuelCard(kcal: Double, food: FoodEquivalent) -> some View {
        InsightCard(icon: "flame.fill", tint: .orange, title: "Travel Fuel") {
            Text("You burned \(Int(kcal)) kcal")
                .font(.subheadline.weight(.bold))
            (Text("\(food.emoji) ≈ \(food.count) ") + Text(foodLabel(food.foodKey)))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func personaCard(_ persona: TravelPersona) -> some View {
        InsightCard(icon: "figure.walk.motion", tint: .purple, title: "Travel Persona") {
            HStack(alignment: .top, spacing: 12) {
                Text(persona.emoji).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(persona.titleKey)).font(.subheadline.weight(.bold))
                    Text(LocalizedStringKey(persona.blurbKey))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(persona.steps.formatted()) steps")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func excitementCard(_ samples: [ExcitementSample]) -> some View {
        let peak = samples.max { $0.bpm < $1.bpm }
        return InsightCard(icon: "heart.fill", tint: .pink, title: "Excitement Meter") {
            Text("Heart rate matched to \(samples.count) photos")
                .font(.subheadline.weight(.bold))
            if let peak {
                Text("\(peak.badge.emoji) Peak \(Int(peak.bpm)) bpm — tap a photo to see its vibe")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func workoutsCard(_ chapters: [WorkoutChapter]) -> some View {
        InsightCard(icon: "figure.run", tint: .blue, title: "Workout Chapters") {
            VStack(spacing: 0) {
                ForEach(chapters) { chapter in
                    Button { selectedChapter = chapter } label: {
                        HStack(spacing: 12) {
                            Text(chapter.emoji).font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(chapterTitle(chapter.activityKey)).font(.subheadline.weight(.semibold))
                                Text(chapter.durationText).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(chapter.photoIDs.count)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                            Image(systemName: "photo.stack").font(.caption).foregroundStyle(.tertiary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    if chapter.id != chapters.last?.id { Divider() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func chapterTitle(_ key: String) -> LocalizedStringKey {
        switch key {
        case "running":      return "Run"
        case "walking":      return "Walk"
        case "cycling":      return "Ride"
        case "hiking":       return "Hike"
        case "swimming":     return "Swim"
        case "yoga":         return "Yoga"
        case "climbing":     return "Climb"
        case "snowboarding": return "Snowboard"
        case "skiing":       return "Ski"
        case "snowSports":   return "Snow Sports"
        case "skating":      return "Skating"
        default:             return "Workout"
        }
    }

    private func foodLabel(_ key: String) -> LocalizedStringKey {
        switch key {
        case "croissant":    return "croissants"
        case "pizza slice":  return "pizza slices"
        case "sushi piece":  return "sushi pieces"
        case "burger":       return "burgers"
        case "tapa":         return "tapas"
        case "waffle":       return "waffles"
        case "stroopwafel":  return "stroopwafels"
        case "pretzel":      return "pretzels"
        case "pad thai plate": return "pad thai plates"
        case "taco":         return "tacos"
        case "samosa":       return "samosas"
        case "fish & chips": return "fish & chips"
        case "gyro":         return "gyros"
        case "chocolate bar": return "chocolate bars"
        case "strudel slice": return "strudel slices"
        case "custard tart": return "custard tarts"
        default:             return "meals"
        }
    }
}

/// A small titled card used for each insight feature.
private struct InsightCard<Content: View>: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                Text(title).font(.subheadline.weight(.semibold))
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppCard.padding)
        .card()
    }
}
