//
//  EventQueries.swift
//  CalenderApp
//
//  Small, reusable derivations over a day's events. Keeping these on the
//  collection lets every screen ask the same questions the same way.
//

import Foundation

extension Array where Element == CalendarEvent {
    /// Timed (non all-day) events, sorted by start.
    var timed: [CalendarEvent] {
        filter { !$0.isAllDay }.sorted { $0.start < $1.start }
    }

    /// All-day events for the day.
    var allDay: [CalendarEvent] {
        filter(\.isAllDay)
    }

    /// The event in progress at `now` (soonest to end if several overlap).
    func current(at now: Date) -> CalendarEvent? {
        filter { !$0.isAllDay && $0.isInProgress(at: now) }.min { $0.end < $1.end }
    }

    /// The next event that hasn't started yet.
    func next(at now: Date) -> CalendarEvent? {
        filter { !$0.isAllDay && $0.start > now }.min { $0.start < $1.start }
    }
}

extension CalendarEvent {
    /// Whether the event matches a search query across its meaningful text.
    /// Case- and diacritic-insensitive so "cafe" finds "Café".
    func matches(_ query: String) -> Bool {
        var haystack = [title, location ?? "", notes ?? "", calendarTitle]
        haystack.append(contentsOf: guests)
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return haystack.contains { $0.range(of: query, options: options) != nil }
    }
}
