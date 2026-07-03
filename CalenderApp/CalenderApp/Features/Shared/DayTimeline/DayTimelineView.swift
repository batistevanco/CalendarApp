//
//  DayTimelineView.swift
//  CalenderApp
//
//  The reusable vertical day timeline: an hour grid, absolutely-positioned
//  event cards with overlap handling, and a live current-time indicator.
//  Renders a full 24h canvas; the parent supplies the scroll view and can
//  auto-scroll to the present.
//

import SwiftUI

struct DayTimelineView: View {
    let day: Date
    let events: [CalendarEvent]
    /// Points per hour. Driven by pinch-to-zoom in the Day view.
    var hourHeight: CGFloat = 60
    /// When true, events can be dragged to move and resized via handles.
    var editable: Bool = false
    /// Called when a card is tapped.
    var onSelect: (CalendarEvent) -> Void = { _ in }
    /// Called when a drag/resize commits a new time range for an event.
    var onReschedule: (CalendarEvent, Date, Date) -> Void = { _, _, _ in }

    /// The event currently picked up for editing (shows resize handles).
    @State private var focusedID: String?

    /// Scroll-anchor id parents can target to bring "now" into view.
    static let nowAnchorID = "cal.timeline.now"

    private let gutterWidth: CGFloat = 56
    private let trailingInset = CalSpacing.s
    private let columnGap: CGFloat = 4

    private var geometry: TimelineGeometry {
        TimelineGeometry(day: day, hourHeight: hourHeight)
    }
    private var positioned: [PositionedEvent] {
        TimelineLayout.resolve(events)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                hourGrid
                eventLayer(width: proxy.size.width)
                nowIndicator
                scrollAnchor
            }
            .frame(width: proxy.size.width, alignment: .topLeading)
        }
        .frame(height: geometry.totalHeight)
    }

    // MARK: Hour grid

    private var hourGrid: some View {
        ForEach(0...24, id: \.self) { hour in
            let y = CGFloat(hour) * hourHeight
            HStack(alignment: .center, spacing: CalSpacing.s) {
                Text(hourLabel(hour))
                    .font(CalFont.hourMarker)
                    .monospacedDigit()
                    .foregroundStyle(CalColor.tertiaryText)
                    .frame(width: gutterWidth - CalSpacing.s, alignment: .trailing)

                Rectangle()
                    .fill(CalColor.hairline.opacity(0.5))
                    .frame(height: 0.5)
            }
            .offset(y: y - 6)
        }
        .accessibilityHidden(true)
    }

    private func hourLabel(_ hour: Int) -> String {
        guard hour < 24 else { return "" }
        var comps = DateComponents()
        comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? day
        return date.formatted(.dateTime.hour())
    }

    // MARK: Events

    private func eventLayer(width: CGFloat) -> some View {
        let contentWidth = width - gutterWidth - trailingInset
        return TimelineView(.everyMinute) { context in
            let now = context.date
            ZStack(alignment: .topLeading) {
                // Tap anywhere empty to dismiss the focused (editing) event.
                if editable, focusedID != nil {
                    Color.clear
                        .frame(width: width, height: geometry.totalHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { focusedID = nil }
                }

                ForEach(positioned) { item in
                    let colCount = CGFloat(item.columnCount)
                    let colWidth = (contentWidth - columnGap * (colCount - 1)) / colCount
                    let x = gutterWidth + CGFloat(item.column) * (colWidth + columnGap)
                    let y = geometry.y(for: item.event.start)
                    let h = geometry.height(from: item.event.start, to: item.event.end)

                    TimelineEventView(
                        event: item.event,
                        now: now,
                        baseX: x,
                        baseY: y,
                        width: colWidth,
                        baseHeight: h,
                        hourHeight: hourHeight,
                        editable: editable,
                        isFocused: focusedID == item.event.id,
                        onSelect: { onSelect(item.event) },
                        onFocus: { focusedID = item.event.id },
                        onReschedule: { start, end in
                            onReschedule(item.event, start, end)
                        }
                    )
                }
            }
        }
    }

    // MARK: Now line

    /// A 1pt anchor at the present moment (or 8am on other days) that parents
    /// can scroll to. Kept invisible; only its position matters.
    private var scrollAnchor: some View {
        let anchorDate = day.isToday ? Date() : Calendar.current.date(
            bySettingHour: 8, minute: 0, second: 0, of: day) ?? day
        return Color.clear
            .frame(width: 1, height: 1)
            .offset(y: geometry.y(for: anchorDate))
            .id(Self.nowAnchorID)
    }

    @ViewBuilder
    private var nowIndicator: some View {
        if day.isToday {
            TimelineView(.everyMinute) { context in
                CurrentTimeIndicator(gutterWidth: gutterWidth)
                    .offset(y: geometry.y(for: context.date) - 0.75)
            }
            .accessibilityHidden(true)
        }
    }
}
