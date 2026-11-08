import WidgetKit
import SwiftUI

// MARK: - Timeline

struct CountdownEntry: TimelineEntry {
    let date: Date
    let countdown: WidgetCountdown?
}

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, countdown: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        let countdown = context.isPreview ? .placeholder : WidgetCountdownStore.load()
        completion(CountdownEntry(date: .now, countdown: countdown))
    }

    /// One entry now and one at each of the next midnights, so the count ticks over on its
    /// own. The app reloads the timeline whenever the plans change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let countdown = WidgetCountdownStore.load()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var entries = [CountdownEntry(date: .now, countdown: countdown)]
        for offset in 1...7 {
            guard let midnight = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            entries.append(CountdownEntry(date: midnight, countdown: countdown))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

private let countdownGradient = LinearGradient(
    colors: [Color(red: 0.07, green: 0.10, blue: 0.23),
             Color(red: 0.13, green: 0.18, blue: 0.38)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

/// The big figure and the words under it, for each phase.
private struct CountdownFigure {
    let value: String
    let caption: String

    init?(_ countdown: WidgetCountdown, on date: Date) {
        switch countdown.phase(on: date) {
        case .upcoming(let days) where days == 0:
            value = String(localized: "Today")
            caption = String(localized: "Have a great trip!")
        case .upcoming(let days):
            value = "\(days)"
            caption = days == 1 ? String(localized: "day to go") : String(localized: "days to go")
        case .underway(let day, let total):
            value = String(localized: "Day \(day)")
            caption = String(localized: "of \(total)")
        case .over:
            return nil
        }
    }
}

private struct CountdownHeader: View {
    var body: some View {
        HStack(spacing: 5) {
            LogoMark(color: .white).frame(width: 13, height: 13)
            Text("Next trip").font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}

private struct SmallCountdownView: View {
    let countdown: WidgetCountdown
    let figure: CountdownFigure

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CountdownHeader()
            Spacer(minLength: 0)
            Text(figure.value)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5).lineLimit(1)
                .foregroundStyle(.white)
            Text(figure.caption)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: 0)
            Text(verbatim: "\(countdown.flag) \(countdown.name)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumCountdownView: View {
    let countdown: WidgetCountdown
    let figure: CountdownFigure

    private var dates: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: countdown.startDate, to: countdown.endDate)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(figure.value)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text(figure.caption)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .frame(minWidth: 90, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                CountdownHeader()
                Spacer(minLength: 0)
                Text(verbatim: "\(countdown.flag) \(countdown.name)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.8)
                Text(dates)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                if !countdown.route.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane")
                        Text(verbatim: countdown.route.joined(separator: " → "))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// No plan yet (or the last one is over): point at where to make one.
private struct NoTripView: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CountdownHeader()
            Spacer(minLength: 0)
            Image(systemName: "airplane.departure")
                .font(.system(size: compact ? 24 : 28, weight: .semibold))
            Text("No trip planned")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text("Plan one in Photrail to start the countdown.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct CountdownEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    var body: some View {
        let figure = entry.countdown.flatMap { CountdownFigure($0, on: entry.date) }
        switch family {
        case .accessoryCircular:
            Group {
                if let figure {
                    VStack(spacing: 0) {
                        Text(figure.value).font(.system(size: 18, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5).lineLimit(1)
                        Text(entry.countdown?.flag ?? "").font(.system(size: 12))
                    }
                } else {
                    Image(systemName: "airplane.departure")
                }
            }
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryRectangular:
            Group {
                if let countdown = entry.countdown, let figure {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: "\(countdown.flag) \(countdown.name)").font(.headline).lineLimit(1)
                        Text(verbatim: "\(figure.value) \(figure.caption)").font(.caption)
                        if !countdown.route.isEmpty {
                            Text(verbatim: countdown.route.joined(separator: " → "))
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                } else {
                    Label("No trip planned", systemImage: "airplane.departure").font(.headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            Group {
                if let countdown = entry.countdown, let figure {
                    Text(verbatim: "\(countdown.flag) \(figure.value) \(figure.caption)")
                } else {
                    Text("No trip planned")
                }
            }
            .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            Group {
                if let countdown = entry.countdown, let figure {
                    MediumCountdownView(countdown: countdown, figure: figure)
                } else {
                    NoTripView(compact: false)
                }
            }
            .containerBackground(for: .widget) { countdownGradient }
        default:
            Group {
                if let countdown = entry.countdown, let figure {
                    SmallCountdownView(countdown: countdown, figure: figure)
                } else {
                    NoTripView(compact: true)
                }
            }
            .containerBackground(for: .widget) { countdownGradient }
        }
    }
}

// MARK: - Widget

struct PhotrailCountdownWidget: Widget {
    let kind = "PhotrailCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownProvider()) { entry in
            CountdownEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Trip Countdown"))
        .description(String(localized: "Counts down the days to your next planned trip."))
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    PhotrailCountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: .placeholder)
    CountdownEntry(date: .now, countdown: nil)
}

#Preview(as: .systemMedium) {
    PhotrailCountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: .placeholder)
}
