import Foundation

/// Builds a per-day view of a month: which days you were on a trip, and the flag of
/// the country you were in that day (using the trip's stops for multi-country trips).
enum TripCalendar {
    struct DayEntry: Identifiable, Sendable {
        let day: Int          // day of month (1-based)
        let date: Date
        let flag: String
        let trip: Trip
        var id: Int { day }
    }

    /// Map of day-of-month → entry for every day you were travelling that month.
    static func entries(for month: Date, trips: [Trip], calendar: Calendar = .current) -> [Int: DayEntry] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [:] }

        var result: [Int: DayEntry] = [:]
        for dayNum in range {
            guard let date = calendar.date(byAdding: .day, value: dayNum - 1, to: monthStart) else { continue }
            guard let trip = trips.first(where: { trip in
                let start = calendar.startOfDay(for: trip.startDate)
                let end = calendar.startOfDay(for: trip.endDate)
                return date >= start && date <= end
            }) else { continue }
            result[dayNum] = DayEntry(day: dayNum, date: date,
                                      flag: flag(for: trip, on: date, calendar: calendar), trip: trip)
        }
        return result
    }

    /// The 12 months of a year, each with its day → entry map.
    static func year(_ year: Int, trips: [Trip], calendar: Calendar = .current) -> [(month: Date, entries: [Int: DayEntry])] {
        (1...12).compactMap { m in
            guard let monthDate = calendar.date(from: DateComponents(year: year, month: m)) else { return nil }
            return (monthDate, entries(for: monthDate, trips: trips, calendar: calendar))
        }
    }

    /// Aggregate insights for a whole year.
    struct YearSummary: Sendable {
        let daysAway: Int
        let monthsTravelled: Int
        let tripCount: Int
        let countries: [(flag: String, days: Int)]   // most days first
    }

    static func summary(forYear year: Int, trips: [Trip], calendar: Calendar = .current) -> YearSummary {
        let months = self.year(year, trips: trips, calendar: calendar)
        var flagDays: [String: Int] = [:]
        var tripIDs = Set<String>()
        var daysAway = 0
        var monthsTravelled = 0
        for (_, entries) in months where !entries.isEmpty {
            monthsTravelled += 1
            for entry in entries.values {
                daysAway += 1
                flagDays[entry.flag, default: 0] += 1
                tripIDs.insert(entry.trip.id)
            }
        }
        return YearSummary(daysAway: daysAway, monthsTravelled: monthsTravelled,
                           tripCount: tripIDs.count,
                           countries: flagDays.sorted { $0.value > $1.value }.map { (flag: $0.key, days: $0.value) })
    }

    /// The flag for a specific day of a trip — the most recent stop reached by that day
    /// (so a multi-country journey shows the right country per day), else the trip's primary.
    private static func flag(for trip: Trip, on day: Date, calendar: Calendar) -> String {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let reached = trip.stops.filter { $0.firstVisit < nextDay }
        if let last = reached.max(by: { $0.firstVisit < $1.firstVisit }) { return last.flag }
        return trip.flag
    }
}
