//
//  CompositeEventProvider.swift
//  CalenderApp
//
//  Merges several providers behind the single `EventProviding` the app depends
//  on. Reads fan out and combine; writes route to the provider that owns the
//  event (by source) or the target calendar (by id). Apple is the primary
//  provider whose authorisation gates the app; Google is additive.
//

import Foundation

actor CompositeEventProvider: EventProviding {
    nonisolated let source: EventSource = .apple

    private let apple: EventProviding
    private let google: EventProviding

    /// Calendar ids known to belong to Google, learned from `calendars()`.
    private var googleCalendarIDs: Set<String> = []

    init(apple: EventProviding, google: EventProviding) {
        self.apple = apple
        self.google = google
    }

    // MARK: Access (driven by Apple/EventKit)

    func access() async -> ProviderAccess { await apple.access() }
    func requestAccess() async -> ProviderAccess { await apple.requestAccess() }

    // MARK: Reads (merge, tolerant of one side failing)

    func calendars() async throws -> [EventCalendar] {
        async let appleCals = tryCalendars(apple)
        async let googleCals = tryCalendars(google)
        let (a, g) = await (appleCals, googleCals)
        googleCalendarIDs = Set(g.map(\.id))
        return a + g
    }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        async let appleEvents = tryEvents(apple, interval)
        async let googleEvents = tryEvents(google, interval)
        let (a, g) = await (appleEvents, googleEvents)
        return a + g
    }

    // MARK: Writes (routed)

    func update(_ event: CalendarEvent, scope: RecurrenceScope) async throws {
        try await provider(for: event).update(event, scope: scope)
    }

    func delete(_ event: CalendarEvent, scope: RecurrenceScope) async throws {
        try await provider(for: event).delete(event, scope: scope)
    }

    func create(_ draft: EventDraft) async throws -> CalendarEvent {
        // Ensure our calendar-ownership map is populated before routing.
        if googleCalendarIDs.isEmpty { _ = try? await calendars() }
        let target: EventProviding = (draft.calendarID.map { googleCalendarIDs.contains($0) } ?? false)
            ? google : apple
        return try await target.create(draft)
    }

    // MARK: Routing helpers

    private func provider(for event: CalendarEvent) -> EventProviding {
        event.source == .google ? google : apple
    }

    private func tryCalendars(_ provider: EventProviding) async -> [EventCalendar] {
        (try? await provider.calendars()) ?? []
    }

    private func tryEvents(_ provider: EventProviding, _ interval: DateInterval) async -> [CalendarEvent] {
        (try? await provider.events(in: interval)) ?? []
    }
}
