import SwiftUI

/// A branded, render-ready share card of a whole year's travel: a 12-month mini
/// calendar with trip days highlighted, plus year insights. Matches the other cards.
struct YearShareCardView: View {
    let year: Int
    let months: [(month: Date, entries: [Int: TripCalendar.DayEntry])]
    let summary: TripCalendar.YearSummary

    static let canvasSize = CGSize(width: 360, height: 640)

    private static let top = Color(red: 0.07, green: 0.09, blue: 0.24)
    private static let bottom = Color(red: 0.22, green: 0.13, blue: 0.42)
    private let accent = Color(red: 0.6, green: 0.55, blue: 1.0)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom)
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .environment(\.locale, Locale(identifier: "en_US"))   // share cards stay English
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 10)
            Text("MY YEAR IN TRAVEL")
                .font(.system(size: 12, weight: .bold)).tracking(1.6)
                .foregroundStyle(accent)
            Text(String(year))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(headlineText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 2)

            Spacer(minLength: 12)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(months, id: \.month) { item in
                    MiniMonthGrid(month: item.month,
                                  tripDays: Set(item.entries.keys),
                                  accent: accent,
                                  idleColor: .white.opacity(0.12),
                                  titleColor: .white.opacity(0.85),
                                  cellSize: 10,
                                  locale: Locale(identifier: "en_US"))
                }
            }

            Spacer(minLength: 10)
            chipsRow
            Text(superlativeText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent)
                .padding(.top, 6)
            Spacer(minLength: 10)
            footer
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 7) {
            LogoMark(color: .white).frame(width: 18, height: 18)
            Text("Photrail").font(.system(size: 15, weight: .heavy, design: .rounded))
            Spacer()
        }
        .foregroundStyle(.white)
    }

    private var chipsRow: some View {
        FlowLayout(spacing: 6, rowSpacing: 6) {
            ForEach(summary.countries.prefix(6), id: \.flag) { item in
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

    private var headlineText: String {
        "\(summary.daysAway) days away · "
            + "\(summary.countries.count) \(summary.countries.count == 1 ? "country" : "countries") · "
            + "\(summary.tripCount) \(summary.tripCount == 1 ? "trip" : "trips")"
    }

    private var superlativeText: String {
        if summary.monthsTravelled >= 12 { return "You travelled every month of the year! 🌍" }
        return "You travelled in \(summary.monthsTravelled) of 12 months 🌍"
    }
}
