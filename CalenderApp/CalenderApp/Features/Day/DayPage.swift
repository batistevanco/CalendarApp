//
//  DayPage.swift
//  CalenderApp
//
//  One day's scrollable timeline within the paged Day View. Loads its own day,
//  auto-scrolls to the present, and hosts pinch-to-zoom (which mutates the
//  shared hour-height so the zoom level is consistent across days).
//

import SwiftUI

struct DayPage: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: Date
    @Binding var hourHeight: CGFloat
    var onSelect: (CalendarEvent) -> Void

    /// Hour-height captured at the start of a pinch, so scaling is relative.
    @State private var zoomBase: CGFloat?
    @State private var didScroll = false

    private let minHour: CGFloat = 44
    private let maxHour: CGFloat = 200

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                DayTimelineView(
                    day: day,
                    events: store.events(on: day).timed,
                    hourHeight: hourHeight,
                    editable: true,
                    onSelect: onSelect,
                    onReschedule: { event, start, end in
                        Task { await store.reschedule(event, start: start, end: end) }
                    }
                )
                .padding(.horizontal, CalSpacing.screen)
                .padding(.vertical, CalSpacing.l)
            }
            .scrollIndicators(.hidden)
            .gesture(zoomGesture)
            .task {
                await store.loadIfNeeded(day)
                guard !didScroll else { return }
                didScroll = true
                if reduceMotion {
                    scroll.scrollTo(DayTimelineView.nowAnchorID, anchor: .center)
                } else {
                    withAnimation(.smooth) {
                        scroll.scrollTo(DayTimelineView.nowAnchorID, anchor: .center)
                    }
                }
            }
        }
    }

    /// Pinch to expand or compress the hours. Two-finger, so it coexists with
    /// one-finger vertical scrolling and horizontal paging.
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = zoomBase ?? hourHeight
                if zoomBase == nil { zoomBase = hourHeight }
                hourHeight = min(max(base * value.magnification, minHour), maxHour)
            }
            .onEnded { _ in zoomBase = nil }
    }
}
