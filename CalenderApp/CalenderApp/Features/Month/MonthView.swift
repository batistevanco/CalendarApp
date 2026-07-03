//
//  MonthView.swift
//  CalenderApp
//
//  Redesigned to support a visual heatmap month grid and a premium vertical
//  timeline agenda view (matching Image 3) showing day nodes connected by a timeline axis.
//

import SwiftUI

struct MonthView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(Navigator.self) private var navigator

    /// One page per month, a wide window either side of today.
    private let months: [Date] = {
        let cal = Calendar.current
        let thisMonth = cal.dateInterval(of: .month, for: .now)?.start ?? .now
        return (-60...60).compactMap {
            cal.date(byAdding: .month, value: $0, to: thisMonth)
        }
    }()

    @State private var visibleMonth: Date = {
        Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    }()

    @State private var isTimelineView = true
    @State private var selectedEvent: CalendarEvent?

    var body: some View {
        Group {
            if store.isAccessDenied {
                CalendarAccessView()
            } else {
                content
            }
        }
        .background(CalColor.canvas)
        .sheet(item: $selectedEvent) { EventDetailView(event: $0) }
    }

    private var content: some View {
        VStack(spacing: CalSpacing.m) {
            // Month Header with Grid vs Timeline selector
            monthHeaderSection
            
            if isTimelineView {
                // Timeline List View (Image 3)
                timelineAgendaView
            } else {
                // Classic Heatmap Grid View
                VStack(spacing: CalSpacing.m) {
                    WeekdayStrip()
                        .padding(.horizontal, CalSpacing.screen)

                    TabView(selection: $visibleMonth) {
                        ForEach(months, id: \.self) { month in
                            MonthGridPage(month: month) { day in
                                navigator.openDay(day)
                            }
                            .tag(month)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
    }

    private var monthHeaderSection: some View {
        VStack(spacing: CalSpacing.s) {
            // View Mode Selector (Grid vs Timeline)
            HStack {
                Text(visibleMonth.formatted(.dateTime.year()))
                    .font(.system(.subheadline, design: .default, weight: .bold))
                    .foregroundStyle(CalColor.secondaryText)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.smooth) { isTimelineView = true }
                    } label: {
                        Text("Timeline")
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(isTimelineView ? Color.white : CalColor.primaryText)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(isTimelineView ? Color.black : Color.clear)
                            .clipShape(Capsule())
                    }
                    
                    Button {
                        withAnimation(.smooth) { isTimelineView = false }
                    } label: {
                        Text("Grid")
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(!isTimelineView ? Color.white : CalColor.primaryText)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(!isTimelineView ? Color.black : Color.clear)
                            .clipShape(Capsule())
                    }
                }
                .padding(2)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }
            .padding(.horizontal, CalSpacing.screen)
            .padding(.top, CalSpacing.s)

            // Month Swiper Navigation: < Jan Feb Mar >
            HStack {
                Button {
                    navigateMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(CalColor.primaryText)
                }
                
                Spacer()
                
                let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
                let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
                
                HStack(spacing: CalSpacing.xl) {
                    Text(prevMonth.formatted(.dateTime.month(.abbreviated)))
                        .font(CalFont.body)
                        .foregroundStyle(CalColor.secondaryText)
                        .onTapGesture {
                            withAnimation(.smooth) { visibleMonth = prevMonth }
                        }
                    
                    Text(visibleMonth.formatted(.dateTime.month(.wide)))
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundStyle(CalColor.primaryText)
                    
                    Text(nextMonth.formatted(.dateTime.month(.abbreviated)))
                        .font(CalFont.body)
                        .foregroundStyle(CalColor.secondaryText)
                        .onTapGesture {
                            withAnimation(.smooth) { visibleMonth = nextMonth }
                        }
                }
                .animation(.smooth, value: visibleMonth)
                
                Spacer()
                
                Button {
                    navigateMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(CalColor.primaryText)
                }
            }
            .padding(.horizontal, CalSpacing.screen)
            .padding(.vertical, CalSpacing.xs)
        }
    }

    private var timelineAgendaView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let daysData = monthDaysWithEvents
                if daysData.isEmpty {
                    VStack(spacing: CalSpacing.m) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundStyle(CalColor.tertiaryText)
                        Text("No events this month")
                            .font(CalFont.headline)
                            .foregroundStyle(CalColor.primaryText)
                        Text("Use the ＋ button below to create one.")
                            .font(CalFont.caption)
                            .foregroundStyle(CalColor.secondaryText)
                    }
                    .padding(.vertical, 80)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(daysData, id: \.date) { item in
                        timelineRow(date: item.date, events: item.events)
                    }
                }
            }
            .padding(.horizontal, CalSpacing.screen)
            .padding(.vertical, CalSpacing.s)
        }
        .scrollIndicators(.hidden)
        .task(id: visibleMonth) {
            let cal = Calendar.current
            let start = cal.dateInterval(of: .month, for: visibleMonth)?.start ?? visibleMonth
            let end = cal.dateInterval(of: .month, for: visibleMonth)?.end ?? visibleMonth
            await store.loadRange(from: start, to: end)
        }
    }

    private func timelineRow(date: Date, events: [CalendarEvent]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Day label
            VStack(alignment: .center, spacing: 2) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .foregroundStyle(CalColor.primaryText)
                
                Text(date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(CalColor.secondaryText)
            }
            .frame(width: 40, alignment: .leading)
            .padding(.top, 4)
            
            // Timeline axis connector line & dot node
            ZStack(alignment: .top) {
                // Line connecting down
                Rectangle()
                    .fill(CalColor.hairline)
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 4)
                
                // Node circle dot
                Circle()
                    .fill(date.isToday ? CalColor.accent : Color(.systemBackground))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(CalColor.accent, lineWidth: 2))
                    .background(Circle().fill(Color(.systemBackground)))
                    .padding(.top, 12)
            }
            .frame(width: 32)
            
            // Stack of daily event cards
            VStack(spacing: CalSpacing.m) {
                ForEach(events) { event in
                    timelineCard(for: event)
                        .onTapGesture { selectedEvent = event }
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 4)
        }
    }

    private func timelineCard(for event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: CalSpacing.s) {
            HStack {
                Text(meetingPlatform(for: event))
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .foregroundStyle(event.color)
                
                Spacer()
            }
            
            Text(event.title)
                .font(.system(.subheadline, design: .default, weight: .bold))
                .foregroundStyle(CalColor.primaryText)
                .lineLimit(1)
            
            HStack {
                Text(timeRangeText(for: event))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(CalColor.secondaryText)
                
                Spacer()
                
                if !event.guests.isEmpty {
                    AvatarGroupView(names: event.guests, size: 20)
                }
            }
        }
        .padding(CalSpacing.m)
        .background(event.color.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Helpers

    private func navigateMonth(by delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: visibleMonth) {
            withAnimation(.smooth) {
                visibleMonth = next
            }
        }
    }

    private var monthDaysWithEvents: [(date: Date, events: [CalendarEvent])] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .month, for: visibleMonth)?.start ?? visibleMonth
        let end = cal.dateInterval(of: .month, for: visibleMonth)?.end ?? visibleMonth
        
        var day = start
        var result: [(date: Date, events: [CalendarEvent])] = []
        while day < end {
            let dayEvents = store.events(on: day).timed
            if !dayEvents.isEmpty {
                result.append((day, dayEvents))
            }
            day = cal.date(byAdding: .day, value: 1, to: day) ?? end
        }
        return result
    }

    private func timeRangeText(for event: CalendarEvent) -> String {
        if event.isAllDay { return String(localized: "All-day") }
        let f = Date.FormatStyle.dateTime.hour().minute()
        return "\(event.start.formatted(f)) - \(event.end.formatted(f))"
    }

    private func meetingPlatform(for event: CalendarEvent) -> String {
        let loc = event.location?.lowercased() ?? ""
        let title = event.title.lowercased()
        if loc.contains("zoom") || title.contains("zoom") {
            return "Zoom Meeting"
        } else if loc.contains("meet.google") || loc.contains("google meet") || title.contains("google meet") {
            return "Google Meet"
        } else if loc.contains("teams") || title.contains("teams") {
            return "Microsoft Teams"
        } else if loc.contains("phone") || title.contains("call") {
            return "Phone Call"
        }
        return "In-person"
    }
}

/// Localised weekday initials, ordered by the user's first weekday.
private struct WeekdayStrip: View {
    private var symbols: [String] {
        let cal = Calendar.current
        let short = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(short[first...] + short[..<first])
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(CalFont.caption)
                    .foregroundStyle(CalColor.tertiaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// One month's 6×7 heatmap grid.
private struct MonthGridPage: View {
    @Environment(CalendarStore.self) private var store

    let month: Date
    var onSelectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: CalSpacing.xs),
                                count: 7)

    private var days: [Date] { MonthGrid.days(of: month) }

    var body: some View {
        LazyVGrid(columns: columns, spacing: CalSpacing.xs) {
            ForEach(days, id: \.self) { day in
                DayCell(
                    day: day,
                    inMonth: Calendar.current.isDate(day, equalTo: month, toGranularity: .month),
                    count: store.events(on: day).timed.count
                )
                .onTapGesture {
                    Haptics.tick()
                    onSelectDay(day)
                }
            }
        }
        .padding(.horizontal, CalSpacing.screen)
        .frame(maxHeight: .infinity, alignment: .top)
        .task {
            let end = Calendar.current.date(byAdding: .day, value: days.count,
                                            to: days.first ?? month) ?? month
            await store.loadRange(from: days.first ?? month, to: end)
        }
    }
}

/// A single heatmap day.
private struct DayCell: View {
    let day: Date
    let inMonth: Bool
    let count: Int

    /// Busyness → fill opacity. Calm, never garish.
    private var intensity: Double {
        guard count > 0 else { return 0 }
        return min(0.16 + Double(count) * 0.13, 0.9)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CalRadius.chip, style: .continuous)
                .fill(CalColor.accent.opacity(inMonth ? intensity : intensity * 0.4))

            if day.isToday {
                RoundedRectangle(cornerRadius: CalRadius.chip, style: .continuous)
                    .strokeBorder(CalColor.accent, lineWidth: 1.5)
            }

            Text(day.formatted(.dateTime.day()))
                .font(CalFont.subheadline)
                .monospacedDigit()
                .foregroundStyle(textColor)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(.rect(cornerRadius: CalRadius.chip))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let events: String
        switch count {
        case 0:  events = String(localized: "no events")
        case 1:  events = String(localized: "1 event")
        default: events = String(localized: "\(count) events")
        }
        return "\(date), \(events)"
    }

    private var textColor: Color {
        if day.isToday { return CalColor.accent }
        if !inMonth { return CalColor.tertiaryText }
        return intensity > 0.55 ? .white : CalColor.primaryText
    }
}

#Preview {
    MonthView()
        .environment(CalendarStore(provider: MockEventProvider()))
        .environment(Navigator())
}
