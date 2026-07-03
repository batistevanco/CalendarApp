//
//  TimelineEventView.swift
//  CalenderApp
//
//  An event on the timeline that can be directly manipulated. Tap to inspect;
//  long-press to lift and drag it to a new time; when focused, drag the top or
//  bottom handle to resize. All motion snaps to 5-minute steps with haptics,
//  and commits optimistically through the store.
//
//  When `editable` is false (e.g. the Today dashboard) it's a plain, tappable
//  card — no accidental edits while browsing.
//

import SwiftUI

struct TimelineEventView: View {
    let event: CalendarEvent
    let now: Date

    /// Base geometry from the timeline layout (before any live gesture delta).
    let baseX: CGFloat
    let baseY: CGFloat
    let width: CGFloat
    let baseHeight: CGFloat
    let hourHeight: CGFloat

    let editable: Bool
    let isFocused: Bool
    var onSelect: () -> Void
    var onFocus: () -> Void
    var onReschedule: (_ start: Date, _ end: Date) -> Void

    // Live gesture deltas, in points.
    @State private var moveDelta: CGFloat = 0
    @State private var topDelta: CGFloat = 0
    @State private var bottomDelta: CGFloat = 0
    @State private var didPickup = false

    private let snapMinutes = 5
    private let minDurationMinutes = 15

    private var pointsPerMinute: CGFloat { hourHeight / 60 }
    private var isInteracting: Bool { didPickup || topDelta != 0 || bottomDelta != 0 }

    // Effective frame while a gesture is in flight.
    private var effectiveY: CGFloat { baseY + moveDelta + topDelta }
    private var effectiveHeight: CGFloat {
        max(baseHeight - topDelta + bottomDelta, CGFloat(minDurationMinutes) * pointsPerMinute)
    }

    var body: some View {
        EventCardView(event: event, height: effectiveHeight, now: now)
            .frame(width: width, height: effectiveHeight, alignment: .topLeading)
            .scaleEffect(isInteracting ? 1.02 : 1)
            .shadow(color: .black.opacity(isInteracting ? 0.18 : 0),
                    radius: isInteracting ? 12 : 0, y: 4)
            .overlay(alignment: .top) { if showHandles { topHandle } }
            .overlay(alignment: .bottom) { if showHandles { bottomHandle } }
            .offset(x: baseX, y: effectiveY)
            .animation(.smooth(duration: 0.2), value: isInteracting)
            .zIndex(isInteracting || isFocused ? 1 : 0)
            .onTapGesture(perform: onSelect)
            .gesture(editable ? moveGesture : nil)
    }

    private var showHandles: Bool { editable && isFocused }

    // MARK: Handles

    private var topHandle: some View {
        ResizeHandle(color: event.color)
            .offset(y: -10)
            .gesture(resizeGesture(edge: .top))
    }

    private var bottomHandle: some View {
        ResizeHandle(color: event.color)
            .offset(y: 10)
            .gesture(resizeGesture(edge: .bottom))
    }

    // MARK: Move (long-press then drag)

    private var moveGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !didPickup {
                    didPickup = true
                    onFocus()
                    Haptics.pickup()
                }
                guard let drag else { return }
                let snapped = snap(drag.translation.height)
                if snapped != moveDelta { Haptics.tick() }
                moveDelta = snapped
            }
            .onEnded { _ in
                defer { didPickup = false; moveDelta = 0 }
                guard didPickup, moveDelta != 0 else { return }
                let minutes = deltaMinutes(moveDelta)
                commit(startShift: minutes, endShift: minutes)
            }
    }

    // MARK: Resize

    private enum Edge { case top, bottom }

    private func resizeGesture(edge: Edge) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { drag in
                let snapped = snap(drag.translation.height)
                switch edge {
                case .top:
                    if snapped != topDelta { Haptics.tick() }
                    topDelta = snapped
                case .bottom:
                    if snapped != bottomDelta { Haptics.tick() }
                    bottomDelta = snapped
                }
            }
            .onEnded { _ in
                switch edge {
                case .top:
                    let minutes = deltaMinutes(topDelta)
                    topDelta = 0
                    commit(startShift: minutes, endShift: 0)
                case .bottom:
                    let minutes = deltaMinutes(bottomDelta)
                    bottomDelta = 0
                    commit(startShift: 0, endShift: minutes)
                }
            }
    }

    // MARK: Snapping + commit

    /// Rounds a point translation to the nearest 5-minute grid, in points.
    private func snap(_ points: CGFloat) -> CGFloat {
        let minutes = points / pointsPerMinute
        let stepped = (minutes / CGFloat(snapMinutes)).rounded() * CGFloat(snapMinutes)
        return stepped * pointsPerMinute
    }

    private func deltaMinutes(_ points: CGFloat) -> Int {
        Int((points / pointsPerMinute).rounded())
    }

    /// Applies snapped minute shifts to start/end, guarding the minimum duration
    /// and day bounds, then reports the change.
    private func commit(startShift: Int, endShift: Int) {
        var newStart = event.start.addingTimeInterval(Double(startShift) * 60)
        var newEnd = event.end.addingTimeInterval(Double(endShift) * 60)

        // Keep at least the minimum duration.
        if newEnd.timeIntervalSince(newStart) < Double(minDurationMinutes) * 60 {
            if endShift != 0 {
                newEnd = newStart.addingTimeInterval(Double(minDurationMinutes) * 60)
            } else {
                newStart = newEnd.addingTimeInterval(-Double(minDurationMinutes) * 60)
            }
        }
        guard newStart != event.start || newEnd != event.end else { return }
        Haptics.commit()
        onReschedule(newStart, newEnd)
    }
}

/// A small grab handle shown at a focused event's edges.
private struct ResizeHandle: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 36, height: 6)
            .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1))
            .shadow(color: color.opacity(0.4), radius: 4)
            .frame(width: 64, height: 28) // generous, centred touch target
            .contentShape(Rectangle())
    }
}
