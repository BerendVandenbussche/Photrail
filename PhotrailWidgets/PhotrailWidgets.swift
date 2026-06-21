import WidgetKit
import SwiftUI

// MARK: - Timeline

struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: WidgetSharedStats
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: .now, stats: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        let stats = context.isPreview ? .placeholder : WidgetSharedStore.load()
        completion(StatsEntry(date: .now, stats: stats))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let entry = StatsEntry(date: .now, stats: WidgetSharedStore.load())
        // The app proactively reloads timelines after each scan; refresh in 6h as a fallback.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

private struct MetricView: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct SmallStatsView: View {
    let stats: WidgetSharedStats
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "globe.europe.africa.fill")
                Text("Photrail")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Text("\(stats.countryCount)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(stats.countryCount == 1 ? "country" : "countries")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Text("\(stats.worldPercentageText) of the world")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediumStatsView: View {
    let stats: WidgetSharedStats
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "globe.europe.africa.fill")
                Text("Photrail")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if let flag = stats.topCountryFlag, let name = stats.topCountryName {
                    Text("\(flag) \(name)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer()

            HStack(spacing: 18) {
                MetricView(value: "\(stats.countryCount)", label: "Countries")
                MetricView(value: "\(stats.cityCount)", label: "Cities")
                MetricView(value: "\(stats.visitedContinents)/\(stats.totalContinents)", label: "Continents")
                MetricView(value: stats.worldPercentageText, label: "of World")
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AccessoryRectangularView: View {
    let stats: WidgetSharedStats
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("\(stats.countryCount) countries", systemImage: "globe.europe.africa.fill")
                .font(.headline)
            Text("\(stats.cityCount) cities · \(stats.worldPercentageText) of world")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WondersView: View {
    let stats: WidgetSharedStats
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: 5) {
                Image(systemName: "star.circle.fill")
                Text("World Wonders")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(stats.sevenWondersSeen)")
                    .font(.system(size: compact ? 40 : 48, weight: .heavy, design: .rounded))
                Text("/ 7")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)

            if !stats.seenWonderEmojis.isEmpty {
                Text(stats.seenWonderEmojis.prefix(compact ? 4 : 9).joined(separator: " "))
                    .font(.system(size: compact ? 16 : 20))
                    .lineLimit(1)
            }

            Text("\(stats.totalWondersSeen) landmarks explored")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Widget entry view

/// Shared Midnight gradient used by all Photrail widgets.
private let widgetGradient = LinearGradient(
    colors: [Color(red: 0.07, green: 0.10, blue: 0.23),
             Color(red: 0.13, green: 0.18, blue: 0.38)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

struct PhotrailWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatsEntry

    private var gradient: LinearGradient { widgetGradient }

    var body: some View {
        switch family {
        case .systemSmall:
            SmallStatsView(stats: entry.stats)
                .containerBackground(for: .widget) { gradient }
        case .systemMedium:
            MediumStatsView(stats: entry.stats)
                .containerBackground(for: .widget) { gradient }
        case .accessoryRectangular:
            AccessoryRectangularView(stats: entry.stats)
                .containerBackground(for: .widget) { Color.clear }
        default:
            SmallStatsView(stats: entry.stats)
                .containerBackground(for: .widget) { gradient }
        }
    }
}

// MARK: - Widget

struct PhotrailStatsWidget: Widget {
    let kind = "PhotrailStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            PhotrailWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Travel Stats")
        .description("Your countries, cities and continents at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct PhotrailWondersEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatsEntry

    var body: some View {
        WondersView(stats: entry.stats, compact: family == .systemSmall)
            .containerBackground(for: .widget) { widgetGradient }
    }
}

struct PhotrailWondersWidget: Widget {
    let kind = "PhotrailWondersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            PhotrailWondersEntryView(entry: entry)
        }
        .configurationDisplayName("World Wonders")
        .description("How many of the 7 World Wonders and famous landmarks you've seen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    PhotrailStatsWidget()
} timeline: {
    StatsEntry(date: .now, stats: .placeholder)
}

#Preview(as: .systemMedium) {
    PhotrailStatsWidget()
} timeline: {
    StatsEntry(date: .now, stats: .placeholder)
}

#Preview(as: .systemSmall) {
    PhotrailWondersWidget()
} timeline: {
    StatsEntry(date: .now, stats: .placeholder)
}
