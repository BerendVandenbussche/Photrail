import SwiftUI

/// A branded, render-ready share card for a single trip. 9:16, photo-backed.
struct TripShareCardView: View {
    let trip: Trip
    var cover: UIImage?
    /// Cached Health insights, when available — drives the activity-based theme.
    var insights: TripInsights? = nil

    static let canvasSize = CGSize(width: 360, height: 640)

    /// The activity theme chosen from the trip's workouts (or `.standard`).
    private var theme: TripShareTheme { .decide(trip: trip, insights: insights) }

    /// Workout chapters that belong to the chosen theme (empty for `.standard`).
    private var themeChapters: [WorkoutChapter] {
        (insights?.workoutChapters ?? []).filter {
            TripShareTheme.kind(forActivityKey: $0.activityKey) == theme.kind
        }
    }

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .environment(\.locale, Locale(identifier: "en_US"))   // share cards stay English
    }

    @ViewBuilder
    private var background: some View {
        if let cover {
            Image(uiImage: cover)
                .resizable()
                .scaledToFill()
                .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                .clipped()
                .overlay(LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.8)],
                                        startPoint: .top, endPoint: .bottom))
        } else {
            LinearGradient(colors: [theme.gradientTop, theme.gradientBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer()
            headline
            Spacer(minLength: 20)
            statsRow
            footer.padding(.top, 18)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 7) {
            LogoMark(color: .white).frame(width: 18, height: 18)
            Text("Photrail")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            Spacer()
            Text(yearText)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let badge = theme.badge {
                HStack(spacing: 6) {
                    if let emoji = theme.emoji { Text(emoji).font(.system(size: 14)) }
                    Text(badge)
                        .font(.system(size: 12, weight: .heavy)).tracking(1.4)
                }
                .foregroundStyle(theme.gradientTop)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(theme.accent))
            }
            Text(trip.englishDateRange.uppercased())
                .font(.system(size: 12, weight: .bold)).tracking(1.6)
                .foregroundStyle(theme.accent)
            Text(trip.isMultiCountry ? "\(trip.flagsLine)\n\(trip.englishDisplayName)" : "\(trip.flag) \(trip.englishDisplayName)")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(3).minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            if !trip.cities.isEmpty {
                Text(trip.cities.prefix(4).joined(separator: " · "))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            ForEach(statItems, id: \.1) { value, label in
                VStack(spacing: 3) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.white.opacity(0.12)))
    }

    private var days: Int {
        (Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0) + 1
    }

    /// Total distance of the theme's workouts, in km (0 if none recorded).
    private var themeDistanceKm: Double {
        themeChapters.compactMap(\.distanceMeters).reduce(0, +) / 1000
    }

    /// Total active energy of the theme's workouts, in kcal (0 if none recorded).
    private var themeKcal: Double {
        themeChapters.compactMap(\.activeEnergyKcal).reduce(0, +)
    }

    private var statItems: [(String, String)] {
        switch theme.kind {
        case .standard: return standardStats
        default:        return Array(themedStats.prefix(4))
        }
    }

    /// The original, location-focused stat set (also the fallback when Health is off).
    private var standardStats: [(String, String)] {
        var items: [(String, String)] = []
        if trip.isMultiCountry {
            items.append(("\(trip.countries.count)", "Countries"))
        }
        items += [
            ("\(trip.cities.count)", trip.cities.count == 1 ? "City" : "Cities"),
            ("\(trip.photoCount)", "Photos"),
            ("\(days)", "Days")
        ]
        if trip.routeDistanceKm >= 1 {
            items.insert(("\(Int(trip.routeDistanceKm).formatted())", "km"), at: 2)
        }
        if let peak = trip.highestAltitudeText, (trip.highestAltitude ?? 0) >= 1000 {
            items.append((peak.replacingOccurrences(of: " m", with: ""), "Peak (m)"))
        }
        return Array(items.prefix(4))
    }

    /// Activity-focused stats. Each theme leads with its own signal, then fills with
    /// generally useful trip numbers.
    private var themedStats: [(String, String)] {
        let sessions = themeChapters.count
        let distance = themeDistanceKm
        let kcal = themeKcal
        let peak = trip.highestAltitude ?? 0
        let flights = insights?.flightsClimbed ?? 0

        func dist() -> (String, String)? {
            distance >= 1 ? ("\(Int(distance).formatted())", "km") : nil
        }
        func energy() -> (String, String)? {
            kcal >= 1 ? ("\(Int(kcal).formatted())", "kcal") : nil
        }
        func peakStat() -> (String, String)? {
            peak >= 500 ? ("\(Int(peak).formatted())", "Peak (m)") : nil
        }

        var items: [(String, String)] = [("\(days)", "Days")]
        switch theme.kind {
        case .ski:
            items.append(("\(sessions)", sessions == 1 ? "Day on piste" : "Days on piste"))
            if let p = peakStat() { items.append(p) }
            if flights > 0 { items.append(("\((flights * 3).formatted())", "Vertical (m)")) }
            if let e = energy() { items.append(e) }
        case .hike:
            items.append(("\(sessions)", sessions == 1 ? "Hike" : "Hikes"))
            if let d = dist() { items.append(d) }
            if let p = peakStat() { items.append(p) }
            if let e = energy() { items.append(e) }
        case .cycle:
            items.append(("\(sessions)", sessions == 1 ? "Ride" : "Rides"))
            if let d = dist() { items.append(d) }
            if let e = energy() { items.append(e) }
        case .run:
            items.append(("\(sessions)", sessions == 1 ? "Run" : "Runs"))
            if let d = dist() { items.append(d) }
            if let e = energy() { items.append(e) }
        case .water:
            items.append(("\(sessions)", sessions == 1 ? "Swim" : "Swims"))
            if let d = dist() { items.append(d) }
            if let e = energy() { items.append(e) }
        case .standard:
            break
        }
        // Backfill with photos so short activity lists still feel complete.
        if items.count < 4 { items.append(("\(trip.photoCount)", "Photos")) }
        return items
    }

    private var footer: some View {
        Text("Your travel history, automatically")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
    }

    private var yearText: String {
        let f = DateFormatter(); f.dateFormat = "yyyy"
        return f.string(from: trip.startDate)
    }
}
