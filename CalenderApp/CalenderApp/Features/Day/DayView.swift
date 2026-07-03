//
//  DayView.swift
//  CalenderApp
//
//  The most important screen: a full-day timeline you can swipe between days,
//  pinch to zoom, and tap to inspect. Built on the shared `DayTimelineView` and
//  `CalendarStore` so it stays in lock-step with Today.
//

import SwiftUI

struct DayView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(Navigator.self) private var navigator

    @State private var selectedEvent: CalendarEvent?
    /// Shared zoom level across all day pages.
    @State private var hourHeight: CGFloat = 60

    /// A wide window of days for smooth horizontal paging.
    private let days: [Date] = {
        let today = Date().startOfDay
        return (-180...180).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: today)
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
        @Bindable var navigator = navigator

        return VStack(spacing: 0) {
            DayHeader(day: navigator.focusedDay) {
                withAnimation(.smooth) { navigator.focusedDay = Date().startOfDay }
            }

            TabView(selection: $navigator.focusedDay) {
                ForEach(days, id: \.self) { day in
                    DayPage(
                        day: day,
                        hourHeight: $hourHeight,
                        onSelect: { selectedEvent = $0 }
                    )
                    .tag(day)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

#Preview {
    DayView()
        .environment(CalendarStore(provider: MockEventProvider()))
        .environment(Navigator())
}
