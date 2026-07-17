import SwiftUI

/// A branded, render-ready share card of a travel calendar month: a flag on every
/// day you were on a trip. Matches the other share cards' visual language.
struct CalendarShareCardView: View {
    let month: Date
    let entries: [Int: TripCalendar.DayEntry]

    static let canvasSize = CGSize(width: 360, height: 640)

    private let calendar = Calendar.current
    private static let top = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let bottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private let accent = Color(red: 0.6, green: 0.55, blue: 1.0)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom)
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 14)
            Text("MY TRAVEL MONTH")
                .font(.system(size: 12, weight: .bold)).tracking(1.6)
                .foregroundStyle(accent)
            Text(monthTitle)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(headlineText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 2)

            Spacer(minLength: 14)
            weekdayRow
            grid
            Spacer(minLength: 12)
            chipsRow
            Text(superlativeText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent)
                .padding(.top, 6)
            Spacer(minLength: 12)
            footer
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 7) {
            LogoMark(color: .white).frame(width: 18, height: 18)
            Text("Photrail").font(.system(size: 15, weight: .heavy, design: .rounded))
            Spacer()
            Text(yearText)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 34) }
            ForEach(daysInMonth, id: \.self) { day in
                ZStack {
                    if let entry = entries[day] {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                        Text(entry.flag).font(.system(size: 17))
                    } else {
                        Text("\(day)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .frame(height: 34)
            }
        }
    }

    private var chipsRow: some View {
        FlowLayout(spacing: 6, rowSpacing: 6) {
            ForEach(monthCountries.prefix(6), id: \.flag) { item in
                Text("\(item.flag) \(item.days)\(item.days == 1 ? " day" : " days")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            LogoMark(color: accent).frame(width: 13, height: 13)
            Text("Made with Photrail")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("· travel history, automatically")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM"
        return f.string(from: month)
    }
    private var yearText: String {
        let f = DateFormatter(); f.dateFormat = "yyyy"
        return f.string(from: month)
    }
    private var monthCountries: [(flag: String, days: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries.values { counts[entry.flag, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.map { (flag: $0.key, days: $0.value) }
    }

    private var headlineText: String {
        let days = entries.count
        let countries = monthCountries.count
        let trips = Set(entries.values.map { $0.trip.id }).count
        return "\(days) \(days == 1 ? "day" : "days") away · "
            + "\(countries) \(countries == 1 ? "country" : "countries") · "
            + "\(trips) \(trips == 1 ? "trip" : "trips")"
    }

    private var superlativeText: String {
        let days = entries.count
        let total = daysInMonth.count
        guard total > 0 else { return "" }
        if days >= total { return "Away the entire month! 🌍" }
        let pct = Int((Double(days) / Double(total) * 100).rounded())
        return "You spent \(pct)% of \(monthTitle) abroad 🌍"
    }
    private var daysInMonth: [Int] {
        Array(calendar.range(of: .day, in: .month, for: month) ?? 1..<2)
    }
    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: month)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
    private var orderedWeekdaySymbols: [String] {
        let symbols = DateFormatter().veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
