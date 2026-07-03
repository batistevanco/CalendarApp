//
//  NotificationManager.swift
//  CalenderApp
//
//  Local notifications for upcoming events and "time to leave" travel reminders,
//  via UNUserNotifications. Settings are persisted; scheduling is idempotent —
//  each sync clears our previous reminders and re-schedules from the current
//  events, staying safely under the system's 64-pending limit.
//

import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
final class NotificationManager {
    /// Master switch for event reminders.
    var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Keys.enabled) } }
    /// Minutes before an event to remind.
    var leadMinutes: Int { didSet { defaults.set(leadMinutes, forKey: Keys.lead) } }
    /// Whether to add a "time to leave" reminder when travel time is known.
    var travelEnabled: Bool { didSet { defaults.set(travelEnabled, forKey: Keys.travel) } }

    /// Whether the system has granted notification permission.
    private(set) var isAuthorized = false

    /// Offered lead-time options, in minutes.
    static let leadOptions = [0, 5, 10, 15, 30, 60]

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let idPrefix = "cal.reminder."
    private let maxScheduled = 60   // headroom under the 64 system limit

    private enum Keys {
        static let enabled = "notif.enabled"
        static let lead = "notif.lead"
        static let travel = "notif.travel"
    }

    init() {
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? false
        leadMinutes = defaults.object(forKey: Keys.lead) as? Int ?? 10
        travelEnabled = defaults.object(forKey: Keys.travel) as? Bool ?? true
    }

    // MARK: Authorisation

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Requests permission; returns whether it was granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        isAuthorized = granted
        return granted
    }

    // MARK: Scheduling

    /// Replaces all app-scheduled reminders with fresh ones for `events`.
    func sync(events: [CalendarEvent]) async {
        // Clear our previously-scheduled reminders (leave others untouched).
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard isEnabled, isAuthorized else { return }

        let now = Date()
        var count = 0
        for event in events where !event.isAllDay {
            guard count < maxScheduled else { break }

            let leadFire = event.start.addingTimeInterval(-Double(leadMinutes) * 60)
            if leadFire > now {
                await add(
                    id: "\(idPrefix)\(event.id).lead",
                    title: event.title,
                    body: reminderBody(event),
                    at: leadFire
                )
                count += 1
            }

            if travelEnabled, let travel = event.travelMinutes, count < maxScheduled {
                let leaveFire = event.start.addingTimeInterval(-Double(travel) * 60)
                if leaveFire > now {
                    await add(
                        id: "\(idPrefix)\(event.id).travel",
                        title: String(localized: "Time to leave"),
                        body: travelBody(event, minutes: travel),
                        at: leaveFire
                    )
                    count += 1
                }
            }
        }
    }

    /// Cancels every reminder this app scheduled.
    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    private func add(id: String, title: String, body: String, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func reminderBody(_ event: CalendarEvent) -> String {
        if let location = event.location, !location.isEmpty {
            return "\(event.start.formatted(.dateTime.hour().minute())) · \(location)"
        }
        return leadMinutes == 0
            ? String(localized: "Starting now")
            : String(localized: "In \(leadMinutes) minutes")
    }

    private func travelBody(_ event: CalendarEvent, minutes: Int) -> String {
        if let location = event.location, !location.isEmpty {
            return "\(minutes) min to \(location)"
        }
        return "\(minutes) min to \(event.title)"
    }
}
