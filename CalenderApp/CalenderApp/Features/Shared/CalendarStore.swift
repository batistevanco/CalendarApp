//
//  CalendarStore.swift
//  CalenderApp
//
//  The single source of truth shared across every screen. It owns the provider,
//  tracks authorisation, caches events per day, and applies optimistic edits
//  (move / resize) that write back through the provider. Injected via the
//  SwiftUI environment so Today, Day, Week and Month all read one cache.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class CalendarStore {
    private let provider: EventProviding

    /// Google sign-in/token manager, exposed so Settings can connect accounts.
    let googleAuth: GoogleAuthService

    /// Authorisation for the backing provider.
    private(set) var access: ProviderAccess = .notDetermined

    /// Events keyed by start-of-day. Reading through `events(on:)` in a view
    /// body establishes the observation dependency automatically.
    private var cache: [Date: [CalendarEvent]] = [:]
    private var loading: Set<Date> = []

    /// The user's connected calendars, for the editor's calendar picker.
    private(set) var calendars: [EventCalendar] = []

    /// Calendar ids the user has hidden. Persisted; filters every view.
    private(set) var hiddenCalendarIDs: Set<String> = []
    private let hiddenKey = "calendars.hidden"

    /// Pass an explicit `provider` for previews/tests; otherwise a composite of
    /// Apple (EventKit) + Google is built and shares the store's `googleAuth`.
    init(provider: EventProviding? = nil) {
        let auth = GoogleAuthService()
        self.googleAuth = auth
        self.provider = provider ?? CompositeEventProvider(
            apple: EventKitEventProvider(),
            google: GoogleCalendarEventProvider(auth: auth)
        )
        hiddenCalendarIDs = Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])
    }

    // MARK: Google accounts

    /// Connects a Google account interactively, then reloads everything.
    func connectGoogle() async throws {
        try await googleAuth.signIn()
        await reloadAll()
    }

    /// Disconnects a Google account and reloads.
    func disconnectGoogle(_ account: GoogleAccount) async {
        googleAuth.signOut(account)
        await reloadAll()
    }

    /// Clears caches and re-fetches calendars plus every previously-loaded day,
    /// so newly connected/disconnected accounts appear across all views.
    func reloadAll() async {
        let keys = Array(cache.keys)
        cache = [:]
        calendars = []
        searchWindowLoaded = false
        await loadCalendarsIfNeeded()
        for key in keys { await fetch(key) }
    }

    // MARK: Visibility

    func isVisible(_ calendarID: String) -> Bool {
        !hiddenCalendarIDs.contains(calendarID)
    }

    /// Shows or hides a calendar across the whole app.
    func setCalendar(_ calendarID: String, visible: Bool) {
        if visible { hiddenCalendarIDs.remove(calendarID) }
        else { hiddenCalendarIDs.insert(calendarID) }
        UserDefaults.standard.set(Array(hiddenCalendarIDs), forKey: hiddenKey)
    }

    var isAccessDenied: Bool { access == .denied }

    /// Explicitly requests provider access (used by onboarding). Returns the
    /// resulting authorisation state.
    @discardableResult
    func requestAccess() async -> ProviderAccess {
        let current = await provider.requestAccess()
        access = current
        return current
    }

    // MARK: Reads

    /// Cached events for a day, excluding calendars the user has hidden.
    func events(on day: Date) -> [CalendarEvent] {
        (cache[day.startOfDay] ?? []).filter { !hiddenCalendarIDs.contains($0.calendarID) }
    }

    /// Finds an event by id across all cached days. Reflects edits that moved
    /// the event to a different day, so detail views stay fresh.
    func event(withID id: String) -> CalendarEvent? {
        for events in cache.values {
            if let match = events.first(where: { $0.id == id }) { return match }
        }
        return nil
    }

    /// Upcoming (visible) events within the next `days`, for notification
    /// scheduling. Reads only what's cached.
    func upcomingEvents(withinDays days: Int) -> [CalendarEvent] {
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: now.startOfDay) ?? now
        return cache.values.flatMap { $0 }
            .filter {
                !hiddenCalendarIDs.contains($0.calendarID) && $0.end > now && $0.start < end
            }
            .sorted { $0.start < $1.start }
    }

    /// Ensures a day is loaded, requesting access once if needed. Cheap to call
    /// repeatedly — it no-ops when the day is cached or already in flight.
    func loadIfNeeded(_ day: Date) async {
        let key = day.startOfDay
        guard cache[key] == nil, !loading.contains(key) else { return }
        await ensureAccess()
        guard access == .authorized else { return }

        loading.insert(key)
        defer { loading.remove(key) }
        await fetch(key)
    }

    /// Loads a whole date range in a single provider call and populates the
    /// per-day cache (including empty days, so cells don't re-fetch). Used by
    /// Week and Month for efficient overviews.
    func loadRange(from start: Date, to end: Date) async {
        await ensureAccess()
        guard access == .authorized else { return }
        let startKey = start.startOfDay
        guard let fetched = try? await provider.events(
            in: DateInterval(start: startKey, end: end)
        ) else { return }

        var grouped: [Date: [CalendarEvent]] = [:]
        for event in fetched {
            grouped[event.start.startOfDay, default: []].append(event)
        }
        let cal = Calendar.current
        var day = startKey
        while day < end {
            cache[day] = (grouped[day] ?? []).sorted { $0.start < $1.start }
            day = cal.date(byAdding: .day, value: 1, to: day) ?? end
        }
    }

    /// Forces a re-fetch of a day (pull-to-refresh).
    func refresh(_ day: Date) async {
        await ensureAccess()
        guard access == .authorized else { return }
        await fetch(day.startOfDay)
    }

    private func fetch(_ key: Date) async {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: key) ?? key
        if let fetched = try? await provider.events(in: DateInterval(start: key, end: end)) {
            cache[key] = fetched.sorted { $0.start < $1.start }
        }
    }

    /// Loads the calendar list once, for the editor's picker.
    func loadCalendarsIfNeeded() async {
        guard calendars.isEmpty else { return }
        await ensureAccess()
        guard access == .authorized else { return }
        if let cals = try? await provider.calendars() {
            calendars = cals
        }
    }

    func calendar(id: String?) -> EventCalendar? {
        guard let id else { return nil }
        return calendars.first { $0.id == id }
    }

    /// The calendar new events default to.
    var defaultCalendarID: String? { calendars.first?.id }

    // MARK: Search

    private var searchWindowLoaded = false

    /// Searches loaded events, lazily loading a broad window (≈ a year) on the
    /// first query. Results are ordered nearest-to-now: upcoming ascending, then
    /// past descending.
    func search(_ query: String) async -> [CalendarEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        await loadSearchWindow()

        let now = Date()
        let matched = cache.values.flatMap { $0 }
            .filter { !hiddenCalendarIDs.contains($0.calendarID) && $0.matches(trimmed) }
        let upcoming = matched.filter { $0.start >= now }.sorted { $0.start < $1.start }
        let past = matched.filter { $0.start < now }.sorted { $0.start > $1.start }
        return upcoming + past
    }

    private func loadSearchWindow() async {
        guard !searchWindowLoaded else { return }
        searchWindowLoaded = true
        let cal = Calendar.current
        let today = Date().startOfDay
        let start = cal.date(byAdding: .day, value: -120, to: today) ?? today
        let end = cal.date(byAdding: .day, value: 400, to: today) ?? today
        await loadRange(from: start, to: end)
    }

    private func ensureAccess() async {
        if access == .notDetermined {
            var current = await provider.access()
            if current == .notDetermined {
                current = await provider.requestAccess()
            }
            access = current
        }
    }

    // MARK: Edits

    /// Moves/resizes an event: updates the cache immediately for instant UI,
    /// then persists through the provider. On write failure the day is re-fetched
    /// so the UI reconciles with the source of truth.
    func reschedule(_ event: CalendarEvent, start: Date, end: Date) async {
        var updated = event
        updated.start = start
        updated.end = end
        apply(updated)

        do {
            try await provider.update(updated, scope: .thisEvent)
        } catch {
            await refresh(event.start)
            await refresh(updated.start)
        }
    }

    /// Applies edits from a draft to an existing event, then persists.
    func saveEdit(_ draft: EventDraft, original: CalendarEvent, scope: RecurrenceScope) async {
        var updated = original
        updated.title = draft.title
        updated.start = draft.start
        updated.end = draft.end
        updated.isAllDay = draft.isAllDay
        updated.location = draft.location.isEmpty ? nil : draft.location
        updated.notes = draft.notes.isEmpty ? nil : draft.notes
        updated.recurrence = draft.recurrence
        if let cal = calendar(id: draft.calendarID) {
            updated.calendarID = cal.id
            updated.calendarTitle = cal.title
            updated.palette = cal.palette
            updated.colorHex = cal.colorHex
        }

        if scope == .futureEvents || original.recurrence.isRepeating || draft.recurrence.isRepeating {
            apply(updated)
            do {
                try await provider.update(updated, scope: scope)
                await reloadAll()
            } catch {
                await reloadAll()
            }
        } else {
            apply(updated)
            do {
                try await provider.update(updated, scope: scope)
            } catch {
                await refresh(original.start)
                await refresh(updated.start)
            }
        }
    }

    /// Creates a new event from a draft, inserting it into the cache.
    @discardableResult
    func create(_ draft: EventDraft) async -> CalendarEvent? {
        await ensureAccess()
        guard access == .authorized else { return nil }
        guard let created = try? await provider.create(draft) else { return nil }
        apply(created)
        // A repeating event has more occurrences than the one we just inserted;
        // reload so they all appear.
        if draft.recurrence.isRepeating {
            await reloadAll()
        }
        return created
    }

    /// Deletes an event, removing it from the cache immediately.
    func delete(_ event: CalendarEvent, scope: RecurrenceScope = .thisEvent) async {
        remove(event)
        if event.isRecurring || event.recurrence.isRepeating || scope == .futureEvents {
            try? await provider.delete(event, scope: scope)
            await reloadAll()
        } else {
            try? await provider.delete(event, scope: scope)
        }
    }

    /// Replaces (or inserts) an event in the cache, moving it to the correct day.
    private func apply(_ event: CalendarEvent) {
        remove(event)
        let key = event.start.startOfDay
        cache[key, default: []].append(event)
        cache[key]?.sort { $0.start < $1.start }
    }

    /// Removes an event from wherever it lives in the cache.
    private func remove(_ event: CalendarEvent) {
        for (key, var events) in cache where events.contains(where: { $0.id == event.id }) {
            events.removeAll { $0.id == event.id }
            cache[key] = events
        }
    }
}
