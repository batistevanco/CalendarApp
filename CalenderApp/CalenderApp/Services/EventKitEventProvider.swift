//
//  EventKitEventProvider.swift
//  CalenderApp
//
//  Reads the user's real Apple Calendar database via EventKit. Implemented as
//  an `actor` so the non-Sendable `EKEventStore` stays safely isolated and all
//  fetching happens off the main actor — keeping scrolling perfectly smooth.
//
//  This is the first real `EventProviding` backend; the mock remains for
//  previews and tests. Google and the rest slot in as sibling providers.
//

import EventKit
import UIKit   // Only for reading EKCalendar colours (CGColor → RGB).

actor EventKitEventProvider: EventProviding {
    nonisolated let source: EventSource = .apple

    private let store = EKEventStore()

    // MARK: Authorisation

    func access() async -> ProviderAccess {
        Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    func requestAccess() async -> ProviderAccess {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined else { return Self.map(status) }
        do {
            let granted = try await store.requestFullAccessToEvents()
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    // MARK: Reads

    func calendars() async throws -> [EventCalendar] {
        store.calendars(for: .event).map(Self.mapCalendar)
    }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        // Fetch across all event calendars; visibility filtering happens in the UI.
        let predicate = store.predicateForEvents(
            withStart: interval.start, end: interval.end, calendars: nil
        )
        return store.events(matching: predicate).map(Self.mapEvent)
    }

    // MARK: Writes

    func update(_ event: CalendarEvent, scope: RecurrenceScope) async throws {
        // Our ids are "<eventIdentifier>|<startTimestamp>"; recover the EK id.
        let ekID = String(event.id.split(separator: "|").first ?? "")
        guard let ekEvent = store.event(withIdentifier: ekID) else { return }
        ekEvent.title = event.title
        ekEvent.startDate = event.start
        ekEvent.endDate = event.end
        ekEvent.isAllDay = event.isAllDay
        ekEvent.location = event.location
        ekEvent.notes = event.notes
        if let target = calendar(withID: event.calendarID) {
            ekEvent.calendar = target
        }

        let wasRecurring = ekEvent.hasRecurrenceRules
        if scope == .futureEvents || !wasRecurring {
            if let rule = Self.ekRule(for: event.recurrence) {
                ekEvent.recurrenceRules = [rule]
            } else {
                ekEvent.recurrenceRules = nil
            }
        }
        let span: EKSpan = (scope == .futureEvents) ? .futureEvents : .thisEvent
        try store.save(ekEvent, span: span, commit: true)
    }

    func create(_ draft: EventDraft) async throws -> CalendarEvent {
        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title = draft.title
        ekEvent.startDate = draft.start
        ekEvent.endDate = draft.end
        ekEvent.isAllDay = draft.isAllDay
        ekEvent.location = draft.location.isEmpty ? nil : draft.location
        ekEvent.notes = draft.notes.isEmpty ? nil : draft.notes
        ekEvent.calendar = calendar(withID: draft.calendarID)
            ?? store.defaultCalendarForNewEvents
        if let rule = Self.ekRule(for: draft.recurrence) {
            ekEvent.recurrenceRules = [rule]
        }
        try store.save(ekEvent, span: .thisEvent, commit: true)
        return Self.mapEvent(ekEvent)
    }

    func delete(_ event: CalendarEvent, scope: RecurrenceScope) async throws {
        let ekID = String(event.id.split(separator: "|").first ?? "")
        guard let ekEvent = store.event(withIdentifier: ekID) else { return }
        let span: EKSpan = (scope == .futureEvents) ? .futureEvents : .thisEvent
        try store.remove(ekEvent, span: span, commit: true)
    }

    /// Looks up a writable calendar by our identifier.
    private func calendar(withID id: String?) -> EKCalendar? {
        guard let id else { return nil }
        return store.calendars(for: .event).first { $0.calendarIdentifier == id }
    }

    // MARK: Mapping (pure, off-actor safe)

    nonisolated private static func map(_ status: EKAuthorizationStatus) -> ProviderAccess {
        switch status {
        case .notDetermined:            return .notDetermined
        case .fullAccess, .authorized:  return .authorized
        case .writeOnly, .denied, .restricted: return .denied
        @unknown default:               return .denied
        }
    }

    nonisolated private static func mapCalendar(_ c: EKCalendar) -> EventCalendar {
        EventCalendar(
            id: c.calendarIdentifier,
            title: c.title,
            palette: .indigo,
            colorHex: hex(from: c.cgColor),
            source: .apple,
            accountName: c.source?.title,
            isVisible: true
        )
    }

    nonisolated private static func mapEvent(_ e: EKEvent) -> CalendarEvent {
        let cal = e.calendar
        let start = e.startDate ?? .now
        // Combine the event id with its start so individual occurrences of a
        // recurring series stay uniquely identifiable on the timeline.
        let base = e.eventIdentifier ?? e.calendarItemIdentifier
        let id = "\(base)|\(start.timeIntervalSince1970)"

        return CalendarEvent(
            id: id,
            title: e.title ?? String(localized: "(No title)"),
            start: start,
            end: e.endDate ?? start,
            isAllDay: e.isAllDay,
            location: e.location?.isEmpty == false ? e.location : nil,
            notes: e.hasNotes ? e.notes : nil,
            url: e.url,
            guests: (e.attendees ?? []).compactMap(\.name),
            calendarID: cal?.calendarIdentifier ?? "",
            calendarTitle: cal?.title ?? "",
            palette: .indigo,
            colorHex: hex(from: cal?.cgColor),
            source: .apple,
            recurrence: recurrence(from: e.recurrenceRules?.first),
            isRecurring: e.hasRecurrenceRules
        )
    }

    /// Maps an EventKit rule to our preset recurrence (best-effort).
    nonisolated private static func recurrence(from rule: EKRecurrenceRule?) -> Recurrence {
        guard let rule else { return .never }
        switch rule.frequency {
        case .daily:   return .daily
        case .weekly:  return rule.interval == 2 ? .biweekly : .weekly
        case .monthly: return .monthly
        case .yearly:  return .yearly
        @unknown default: return .never
        }
    }

    /// Builds an EventKit rule for one of our presets.
    nonisolated private static func ekRule(for recurrence: Recurrence) -> EKRecurrenceRule? {
        switch recurrence {
        case .never:    return nil
        case .daily:    return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly:   return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .biweekly: return EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil)
        case .monthly:  return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .yearly:   return EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        }
    }

    /// Converts an EventKit `CGColor` into a compact `0xRRGGBB` value.
    nonisolated private static func hex(from cgColor: CGColor?) -> UInt32? {
        guard let cgColor else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(cgColor: cgColor).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }
        func channel(_ v: CGFloat) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
        return (channel(r) << 16) | (channel(g) << 8) | channel(b)
    }
}
