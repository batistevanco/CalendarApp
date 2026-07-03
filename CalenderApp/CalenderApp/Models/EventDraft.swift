//
//  EventDraft.swift
//  CalenderApp
//
//  A mutable working copy used by the editor for both creating and editing an
//  event. Keeping edits in a draft (rather than mutating a live event) means
//  Cancel is free and Save is a single, explicit commit.
//

import Foundation

nonisolated struct EventDraft: Sendable, Equatable {
    /// `nil` for a brand-new event; otherwise the id of the event being edited.
    var id: String?
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var location: String
    var notes: String
    /// Target calendar id. Resolved to the provider's default when `nil`.
    var calendarID: String?
    var recurrence: Recurrence

    /// True when there's enough to save.
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && end >= start
    }

    var isNew: Bool { id == nil }

    // MARK: Editing an existing event

    init(from event: CalendarEvent) {
        id = event.id
        title = event.title
        start = event.start
        end = event.end
        isAllDay = event.isAllDay
        location = event.location ?? ""
        notes = event.notes ?? ""
        calendarID = event.calendarID
        recurrence = event.recurrence
    }

    // MARK: Creating a new event

    init(day: Date, calendarID: String? = nil) {
        id = nil
        title = ""
        start = Self.defaultStart(for: day)
        end = start.addingTimeInterval(3600)
        isAllDay = false
        location = ""
        notes = ""
        self.calendarID = calendarID
        recurrence = .never
    }

    /// A sensible starting time: the next whole hour today, or 9am on other days.
    private static func defaultStart(for day: Date) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(day) {
            var comps = cal.dateComponents([.year, .month, .day, .hour], from: .now)
            comps.hour = (comps.hour ?? 0) + 1   // normalises past midnight
            comps.minute = 0
            return cal.date(from: comps) ?? .now
        }
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }
}
