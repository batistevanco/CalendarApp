//
//  WeekTimelineView.swift
//  CalenderApp
//
//  A seven-column day-grid for a single week. Shares the timeline geometry and
//  overlap layout with the Day view, so events read consistently everywhere.
//  Renders a full 24h canvas; the parent scrolls and can jump to "now".
//

import SwiftUI

/// Shared metrics so the weekday header and the timeline columns line up.
enum WeekMetrics {
    static let gutter: CGFloat = 44
}

struct WeekTimelineView: View {
    let days: [Date]                     // exactly 7, aligned to first weekday
    let eventsByDay: [[CalendarEvent]]   // parallel to `days`
    var hourHeight: CGFloat = 48
    var onSelect: (CalendarEvent) -> Void = { _ in }

    static let nowAnchorID = "cal.week.now"

    private let gutterWidth = WeekMetrics.gutter
    private let columnInset: CGFloat = 2

    private var geometry: TimelineGeometry {
        TimelineGeometry(day: days.first ?? .now, hourHeight: hourHeight)
    }

    var body: some View {
        GeometryReader { proxy in
            let colWidth = (proxy.size.width - gutterWidth) / 7
            ZStack(alignment: .topLeading) {
                todayHighlight(colWidth: colWidth)
                hourGrid
                columnSeparators(colWidth: colWidth)
                eventLayer(colWidth: colWidth)
                nowIndicator
                scrollAnchor
            }
            .frame(width: proxy.size.width, alignment: .topLeading)
        }
        .frame(height: geometry.totalHeight)
    }

    // MARK: Background

    private func todayHighlight(colWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
            if day.isToday {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(CalColor.accent.opacity(0.06))
                    .frame(width: colWidth, height: geometry.totalHeight)
                    .offset(x: gutterWidth + CGFloat(index) * colWidth)
            }
        }
    }

    private var hourGrid: some View {
        ForEach(0...24, id: \.self) { hour in
            let y = CGFloat(hour) * hourHeight
            HStack(alignment: .center, spacing: CalSpacing.xs) {
                Text(hour < 24 ? hourLabel(hour) : "")
                    .font(CalFont.hourMarker)
                    .monospacedDigit()
                    .foregroundStyle(CalColor.tertiaryText)
                    .frame(width: gutterWidth - CalSpacing.xs, alignment: .trailing)
                Rectangle()
                    .fill(CalColor.hairline.opacity(0.4))
                    .frame(height: 0.5)
            }
            .offset(y: y - 6)
        }
    }

    private func columnSeparators(colWidth: CGFloat) -> some View {
        ForEach(1..<7) { i in
            Rectangle()
                .fill(CalColor.hairline.opacity(0.3))
                .frame(width: 0.5, height: geometry.totalHeight)
                .offset(x: gutterWidth + CGFloat(i) * colWidth)
        }
    }

    // MARK: Events

    private func eventLayer(colWidth: CGFloat) -> some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            ForEach(Array(days.enumerated()), id: \.offset) { index, _ in
                let positioned = TimelineLayout.resolve(eventsByDay[index])
                ForEach(positioned) { item in
                    let cols = CGFloat(item.columnCount)
                    let usable = colWidth - columnInset * 2
                    let subWidth = usable / cols
                    let x = gutterWidth + CGFloat(index) * colWidth + columnInset
                        + CGFloat(item.column) * subWidth
                    let y = geometry.y(for: item.event.start)
                    let h = geometry.height(from: item.event.start, to: item.event.end)

                    EventCardView(event: item.event, height: h, now: now)
                        .frame(width: subWidth - 1, height: h, alignment: .topLeading)
                        .offset(x: x, y: y)
                        .onTapGesture { onSelect(item.event) }
                }
            }
        }
    }

    // MARK: Now + anchor

    @ViewBuilder
    private var nowIndicator: some View {
        if days.contains(where: \.isToday) {
            TimelineView(.everyMinute) { context in
                HStack(spacing: 0) {
                    Circle().fill(CalColor.accent).frame(width: 7, height: 7)
                        .frame(width: gutterWidth, alignment: .trailing)
                    Rectangle().fill(CalColor.accent).frame(height: 1)
                }
                .offset(y: geometry.y(for: context.date) - 0.5)
            }
        }
    }

    private var scrollAnchor: some View {
        let day = days.first ?? .now
        let anchor = days.contains(where: \.isToday)
            ? Date()
            : (Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day)
        return Color.clear
            .frame(width: 1, height: 1)
            .offset(y: geometry.y(for: anchor))
            .id(Self.nowAnchorID)
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? .now
        return date.formatted(.dateTime.hour())
    }
}
