//
//  TimelineGeometry.swift
//  CalenderApp
//
//  Pure geometry + overlap maths for the day timeline. Kept free of SwiftUI so
//  it is trivially testable and reused by both the Today and Day screens.
//

import Foundation
import CoreGraphics

/// Maps between clock time and vertical offset on the timeline canvas.
struct TimelineGeometry {
    /// The calendar day being displayed (used to anchor minute maths).
    let day: Date
    /// Points per hour. Pinch-to-zoom drives this later.
    var hourHeight: CGFloat

    /// Total canvas height for a full 24h day.
    var totalHeight: CGFloat { hourHeight * 24 }

    /// Vertical offset for a given date, clamped to the day.
    func y(for date: Date) -> CGFloat {
        let minutes = minutesFromDayStart(to: date)
        return CGFloat(minutes) / 60 * hourHeight
    }

    /// Height for a duration between two dates (min 24pt so cards stay tappable).
    func height(from start: Date, to end: Date) -> CGFloat {
        let minutes = max(end.timeIntervalSince(start) / 60, 1)
        return max(CGFloat(minutes) / 60 * hourHeight, 24)
    }

    /// Minutes from the start of `day` to `date`, clamped to 0...1440.
    private func minutesFromDayStart(to date: Date) -> Int {
        let start = Calendar.current.startOfDay(for: day)
        let minutes = Int(date.timeIntervalSince(start) / 60)
        return min(max(minutes, 0), 24 * 60)
    }
}

/// An event with its resolved column position for side-by-side overlap layout.
struct PositionedEvent: Identifiable {
    let event: CalendarEvent
    /// Zero-based column within its overlap cluster.
    let column: Int
    /// Number of columns in the cluster (all peers share this for equal widths).
    let columnCount: Int

    var id: String { event.id }
}

enum TimelineLayout {
    /// Resolves overlapping events into columns. Events that overlap in time are
    /// grouped into a cluster and packed into the fewest columns possible, then
    /// every peer in the cluster is given the same column count so their widths
    /// match — the way Apple's Calendar lays out concurrent events.
    static func resolve(_ events: [CalendarEvent]) -> [PositionedEvent] {
        let timed = events
            .filter { !$0.isAllDay }
            .sorted { $0.start == $1.start ? $0.end > $1.end : $0.start < $1.start }
        guard !timed.isEmpty else { return [] }

        var result: [PositionedEvent] = []
        var cluster: [CalendarEvent] = []
        var clusterEnd = Date.distantPast

        func flush() {
            guard !cluster.isEmpty else { return }
            result.append(contentsOf: pack(cluster))
            cluster.removeAll(keepingCapacity: true)
        }

        for event in timed {
            if event.start < clusterEnd {
                cluster.append(event)
                clusterEnd = max(clusterEnd, event.end)
            } else {
                flush()
                cluster = [event]
                clusterEnd = event.end
            }
        }
        flush()
        return result
    }

    /// Greedily packs one overlap cluster into columns.
    private static func pack(_ cluster: [CalendarEvent]) -> [PositionedEvent] {
        var columnEnds: [Date] = []          // last end date per column
        var assigned: [(CalendarEvent, Int)] = []

        for event in cluster {
            if let col = columnEnds.firstIndex(where: { $0 <= event.start }) {
                columnEnds[col] = event.end
                assigned.append((event, col))
            } else {
                columnEnds.append(event.end)
                assigned.append((event, columnEnds.count - 1))
            }
        }

        let count = max(columnEnds.count, 1)
        return assigned.map { PositionedEvent(event: $0.0, column: $0.1, columnCount: count) }
    }
}
