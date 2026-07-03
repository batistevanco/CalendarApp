//
//  MonthGrid.swift
//  CalenderApp
//
//  Pure calendar maths for laying out a month as a stable 6×7 grid, aligned to
//  the user's first weekday. Kept free of SwiftUI for easy testing.
//

import Foundation

enum MonthGrid {
    /// The 42 days (6 weeks) covering `month`, including leading/trailing days
    /// from adjacent months so the grid is always a full rectangle.
    static func days(of month: Date) -> [Date] {
        let cal = Calendar.current
        guard let monthStart = cal.dateInterval(of: .month, for: month)?.start else {
            return []
        }

        // How many leading days from the previous month to reach the first column.
        let weekday = cal.component(.weekday, from: monthStart)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        guard let gridStart = cal.date(byAdding: .day, value: -leading, to: monthStart) else {
            return []
        }

        return (0..<42).compactMap {
            cal.date(byAdding: .day, value: $0, to: gridStart)
        }
    }
}
