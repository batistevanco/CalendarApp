//
//  EventProviding.swift
//  CalenderApp
//
//  The abstraction every calendar backend implements. The UI depends only on
//  this protocol, so EventKit, Google, or an in-memory mock are interchangeable.
//  Reads/writes are async to keep the main actor free and scrolling smooth.
//

import Foundation

/// Authorisation state for a provider, surfaced during onboarding.
enum ProviderAccess: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
}

/// A source of calendars and events. Conformers are `Sendable` and
/// `nonisolated` so their async work runs off the main actor, keeping the UI
/// buttery while data is fetched.
nonisolated protocol EventProviding: Sendable {
    /// Which backend this provider represents.
    var source: EventSource { get }

    /// Current authorisation for this provider.
    func access() async -> ProviderAccess

    /// Request access if needed; returns the resulting state.
    func requestAccess() async -> ProviderAccess

    /// All calendars the user has connected through this provider.
    func calendars() async throws -> [EventCalendar]

    /// Events overlapping `interval`, across the visible calendars.
    func events(in interval: DateInterval) async throws -> [CalendarEvent]

    /// Persists all editable fields of an existing event (title, times, all-day,
    /// location, notes, and target calendar) with the specified recurrence scope.
    func update(_ event: CalendarEvent, scope: RecurrenceScope) async throws

    /// Creates a new event from a draft and returns it fully resolved (real id,
    /// calendar colour, etc.).
    func create(_ draft: EventDraft) async throws -> CalendarEvent

    /// Deletes an event with the specified recurrence scope.
    func delete(_ event: CalendarEvent, scope: RecurrenceScope) async throws
}
