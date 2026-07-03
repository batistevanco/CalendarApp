//
//  LiveActivityController.swift
//  CalenderApp
//
//  Starts, updates and ends the Live Activity that counts down to the current
//  or next event. It runs a single activity at a time and only for events
//  happening soon, so the Lock Screen stays uncluttered.
//

import Foundation
import ActivityKit

@MainActor
final class LiveActivityController {
    private var activity: Activity<EventActivityAttributes>?

    /// How far ahead an upcoming event may be before we show an activity.
    private let lookAhead: TimeInterval = 4 * 3600

    /// Reconciles the running activity with the current/next event.
    func update(current: CalendarEvent?, next: CalendarEvent?, now: Date = .now) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Prefer an in-progress event; otherwise the next one, if it's soon.
        let target: CalendarEvent?
        let inProgress: Bool
        if let current {
            target = current
            inProgress = true
        } else if let next, next.start.timeIntervalSince(now) <= lookAhead {
            target = next
            inProgress = false
        } else {
            target = nil
            inProgress = false
        }

        guard let event = target else {
            Task { await end() }
            return
        }

        let state = EventActivityAttributes.ContentState(
            targetDate: inProgress ? event.end : event.start,
            isInProgress: inProgress,
            location: event.location
        )

        if let activity, activity.attributes.title == event.title {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        } else {
            Task { await restart(for: event, state: state) }
        }
    }

    private func restart(for event: CalendarEvent,
                         state: EventActivityAttributes.ContentState) async {
        await end()
        let attributes = EventActivityAttributes(title: event.title, colorHex: event.colorHex)
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    func end() async {
        for activity in Activity<EventActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
    }
}
