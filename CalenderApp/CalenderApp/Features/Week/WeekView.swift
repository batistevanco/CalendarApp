//
//  WeekView.swift
//  CalenderApp
//
//  A clean, gesture-driven week. Swipe between weeks, pinch to zoom the hours,
//  tap a day header to open it, tap an event for detail. Built on the shared
//  week timeline and store.
//

import SwiftUI

struct WeekView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(Navigator.self) private var navigator

    @State private var visibleWeek: Date = Date().startOfWeek
    @State private var selectedEvent: CalendarEvent?
    @State private var hourHeight: CGFloat = 48

    private let weeks: [Date] = {
        let start = Date().startOfWeek
        let cal = Calendar.current
        return (-80...80).compactMap {
            cal.date(byAdding: .weekOfYear, value: $0, to: start)
        }
    }()

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
        VStack(spacing: CalSpacing.s) {
            WeekHeader(weekStart: visibleWeek) {
                withAnimation(.smooth) { visibleWeek = Date().startOfWeek }
            }
            WeekdayHeaderRow(weekStart: visibleWeek) { day in
                navigator.openDay(day)
            }

            TabView(selection: $visibleWeek) {
                ForEach(weeks, id: \.self) { week in
                    WeekPage(
                        weekStart: week,
                        hourHeight: $hourHeight,
                        onSelect: { selectedEvent = $0 }
                    )
                    .tag(week)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

/// Week range title, e.g. "30 Jun – 6 Jul", with a Today return.
private struct WeekHeader: View {
    let weekStart: Date
    var onToday: () -> Void

    private var isCurrentWeek: Bool {
        Calendar.current.isDate(weekStart, equalTo: Date().startOfWeek, toGranularity: .day)
    }
    private var rangeText: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let f = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "\(weekStart.formatted(f)) – \(end.formatted(f))"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(rangeText)
                .font(CalFont.title)
                .foregroundStyle(CalColor.primaryText)
            Spacer()
            if !isCurrentWeek {
                Button(action: onToday) {
                    Text("Today")
                        .font(CalFont.caption)
                        .padding(.horizontal, CalSpacing.m)
                        .padding(.vertical, CalSpacing.s)
                }
                .buttonStyle(.glass)
                .tint(CalColor.accent)
            }
        }
        .padding(.horizontal, CalSpacing.screen)
        .padding(.top, CalSpacing.s)
        .animation(.smooth, value: weekStart)
    }
}

/// The tappable weekday + date row, aligned to the timeline's gutter.
private struct WeekdayHeaderRow: View {
    let weekStart: Date
    var onSelectDay: (Date) -> Void

    private var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: WeekMetrics.gutter)
            ForEach(days, id: \.self) { day in
                Button {
                    Haptics.tick()
                    onSelectDay(day)
                } label: {
                    VStack(spacing: 2) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(CalFont.hourMarker)
                            .foregroundStyle(CalColor.tertiaryText)
                        Text(day.formatted(.dateTime.day()))
                            .font(CalFont.timeLabel)
                            .foregroundStyle(day.isToday ? .white : CalColor.primaryText)
                            .frame(width: 28, height: 28)
                            .background {
                                if day.isToday {
                                    Circle().fill(CalColor.accent)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .accessibilityHint("Opens this day")
            }
        }
        .padding(.horizontal, CalSpacing.xs)
    }
}

/// One week's scrollable timeline, with pinch-to-zoom and auto-scroll to now.
private struct WeekPage: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let weekStart: Date
    @Binding var hourHeight: CGFloat
    var onSelect: (CalendarEvent) -> Void

    @State private var zoomBase: CGFloat?
    @State private var didScroll = false

    private var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                WeekTimelineView(
                    days: days,
                    eventsByDay: days.map { store.events(on: $0).timed },
                    hourHeight: hourHeight,
                    onSelect: onSelect
                )
                .padding(.horizontal, CalSpacing.s)
                .padding(.vertical, CalSpacing.m)
            }
            .scrollIndicators(.hidden)
            .gesture(zoomGesture)
            .task {
                let end = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                await store.loadRange(from: weekStart, to: end)
                guard !didScroll else { return }
                didScroll = true
                if reduceMotion {
                    scroll.scrollTo(WeekTimelineView.nowAnchorID, anchor: .center)
                } else {
                    withAnimation(.smooth) {
                        scroll.scrollTo(WeekTimelineView.nowAnchorID, anchor: .center)
                    }
                }
            }
        }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = zoomBase ?? hourHeight
                if zoomBase == nil { zoomBase = hourHeight }
                hourHeight = min(max(base * value.magnification, 36), 160)
            }
            .onEnded { _ in zoomBase = nil }
    }
}
