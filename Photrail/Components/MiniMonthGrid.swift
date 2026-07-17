import SwiftUI

/// A compact month: the month name over a 7-column grid of dots, where days you
/// were travelling are filled in the accent color. Used in the year calendar view
/// and the year share card.
struct MiniMonthGrid: View {
    let month: Date
    let tripDays: Set<Int>
    var accent: Color = .accentColor
    var idleColor: Color = Color.primary.opacity(0.12)
    var titleColor: Color = .primary
    var cellSize: CGFloat = 13

    private let calendar = Calendar.current
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: 2), count: 7)
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(monthName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(titleColor)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(width: cellSize, height: cellSize)
                }
                ForEach(days, id: \.self) { day in
                    Circle()
                        .fill(tripDays.contains(day) ? accent : idleColor)
                        .frame(width: cellSize * 0.66, height: cellSize * 0.66)
                        .frame(width: cellSize, height: cellSize)
                }
            }
        }
    }

    private var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMM"
        return f.string(from: month)
    }
    private var days: [Int] {
        Array(calendar.range(of: .day, in: .month, for: month) ?? 1..<2)
    }
    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: month)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}
