import SwiftUI

/// A month calendar with a flag on every day you were on a trip. Tapping a trip day
/// opens that trip; the month can be shared as a branded card.
struct CalendarView: View {
    let trips: [Trip]

    private enum Mode: String, CaseIterable, Identifiable { case month = "Month", year = "Year"; var id: String { rawValue } }

    @State private var mode: Mode = .month
    @State private var month: Date = Calendar.current.startOfMonth(for: Date())
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var showSharePreview = false
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let yearColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var entries: [Int: TripCalendar.DayEntry] {
        TripCalendar.entries(for: month, trips: trips, calendar: calendar)
    }
    private var yearMonths: [(month: Date, entries: [Int: TripCalendar.DayEntry])] {
        TripCalendar.year(year, trips: trips, calendar: calendar)
    }
    private var yearSummary: TripCalendar.YearSummary {
        TripCalendar.summary(forYear: year, trips: trips, calendar: calendar)
    }

    private var canGoForward: Bool {
        month < calendar.startOfMonth(for: Date())
    }
    private var canGoForwardYear: Bool {
        year < calendar.component(.year, from: Date())
    }
    private var shareDisabled: Bool {
        mode == .month ? entries.isEmpty : yearSummary.daysAway == 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .month { monthContent } else { yearContent }
            }
            .padding(20)
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSharePreview = true } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(shareDisabled)
            }
        }
        .sheet(isPresented: $showSharePreview) {
            if mode == .month {
                CalendarSharePreview(month: month, entries: entries)
            } else {
                YearSharePreview(year: year, months: yearMonths, summary: yearSummary)
            }
        }
    }

    // MARK: - Month mode

    @ViewBuilder
    private var monthContent: some View {
        monthHeader
        weekdayRow
        grid
        if entries.isEmpty {
            Text("No trips this month")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            monthSummary
        }
    }

    // MARK: - Year mode

    @ViewBuilder
    private var yearContent: some View {
        HStack {
            Button { year -= 1 } label: {
                Image(systemName: "chevron.left").font(.headline).foregroundStyle(.tint)
            }
            Spacer()
            Text(String(year)).font(.title3.weight(.bold))
            Spacer()
            Button { if canGoForwardYear { year += 1 } } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(canGoForwardYear ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .disabled(!canGoForwardYear)
        }

        LazyVGrid(columns: yearColumns, spacing: 16) {
            ForEach(yearMonths, id: \.month) { item in
                Button {
                    month = item.month
                    withAnimation { mode = .month }
                } label: {
                    MiniMonthGrid(month: item.month, tripDays: Set(item.entries.keys), cellSize: 12)
                }
                .buttonStyle(.plain)
            }
        }

        if yearSummary.daysAway == 0 {
            Text("No trips in \(String(year))")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            yearSummaryCard
        }
    }

    private var yearSummaryCard: some View {
        let s = yearSummary
        return VStack(alignment: .leading, spacing: 12) {
            Text("\(L.daysAway(s.daysAway)) · \(L.countries(s.countries.count)) · \(L.trips(s.tripCount))")
                .font(.subheadline.weight(.semibold))
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(s.countries, id: \.flag) { item in
                    Text("\(item.flag) \(L.days(item.days))")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            Text(s.monthsTravelled >= 12
                 ? "You travelled every month of \(String(year))! 🌍"
                 : "You travelled in \(s.monthsTravelled) of 12 months 🌍")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppCard.padding)
        .card()
        .padding(.top, 4)
    }

    private var monthHeader: some View {
        HStack {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left").font(.headline).foregroundStyle(.tint)
            }
            Spacer()
            Text(monthTitle).font(.title3.weight(.bold))
            Spacer()
            Button { step(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(canGoForward ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .disabled(!canGoForward)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 48) }
            ForEach(daysInMonth, id: \.self) { day in
                if let entry = entries[day] {
                    NavigationLink { TripDetailView(trip: entry.trip) } label: { dayCell(day: day, entry: entry) }
                        .buttonStyle(.plain)
                } else {
                    dayCell(day: day, entry: nil)
                }
            }
        }
    }

    // MARK: - Month summary

    /// Distinct countries this month with day counts, most days first.
    private var monthCountries: [(flag: String, days: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries.values { counts[entry.flag, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.map { (flag: $0.key, days: $0.value) }
    }

    private var monthSummary: some View {
        let daysAway = entries.count
        let countries = monthCountries.count
        let trips = Set(entries.values.map { $0.trip.id }).count
        let pct = Int((Double(daysAway) / Double(daysInMonth.count) * 100).rounded())
        let monthName: String = {
            let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: month)
        }()

        return VStack(alignment: .leading, spacing: 12) {
            Text("\(L.daysAway(daysAway)) · \(L.countries(countries)) · \(L.trips(trips))")
                .font(.subheadline.weight(.semibold))

            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(monthCountries, id: \.flag) { item in
                    Text("\(item.flag) \(L.days(item.days))")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
            }

            Text(daysAway >= daysInMonth.count
                 ? "Away the entire month! 🌍"
                 : "You spent \(pct)% of \(monthName) abroad 🌍")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppCard.padding)
        .card()
        .padding(.top, 4)
    }

    private func dayCell(day: Int, entry: TripCalendar.DayEntry?) -> some View {
        VStack(spacing: 2) {
            if let entry {
                Text(entry.flag).font(.system(size: 22))
                Text("\(day)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            } else {
                Text("\(day)").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(entry != nil ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    private var daysInMonth: [Int] {
        Array(calendar.range(of: .day, in: .month, for: month) ?? 1..<2)
    }

    /// Blank leading cells so day 1 lands under the right weekday.
    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: month)   // 1 = Sunday
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = DateFormatter().veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func step(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.easeInOut(duration: 0.2)) { month = next }
        }
    }
}

// MARK: - Share preview

/// Shows a live preview of the month card before sharing.
private struct CalendarSharePreview: View {
    let month: Date
    let entries: [Int: TripCalendar.DayEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                SharePreviewCanvas(size: CalendarShareCardView.canvasSize) {
                    CalendarShareCardView(month: month, entries: entries)
                }

                Button { share() } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .navigationTitle("Share Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func share() {
        if let image = ShareCardRenderer.render(
            CalendarShareCardView(month: month, entries: entries),
            baseSize: CalendarShareCardView.canvasSize,
            opaque: true
        ) {
            SharePresenter.present([image])
        }
    }
}

/// Shows a live preview of the year card before sharing.
private struct YearSharePreview: View {
    let year: Int
    let months: [(month: Date, entries: [Int: TripCalendar.DayEntry])]
    let summary: TripCalendar.YearSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                SharePreviewCanvas(size: YearShareCardView.canvasSize) {
                    YearShareCardView(year: year, months: months, summary: summary)
                }

                Button { share() } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .navigationTitle("Share Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func share() {
        if let image = ShareCardRenderer.render(
            YearShareCardView(year: year, months: months, summary: summary),
            baseSize: YearShareCardView.canvasSize,
            opaque: true
        ) {
            SharePresenter.present([image])
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
