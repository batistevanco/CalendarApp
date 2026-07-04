//
//  GoogleDTO.swift
//  CalenderApp
//
//  Codable models for the Google Calendar v3 JSON, plus mapping to and from our
//  provider-agnostic domain types.
//

import Foundation

// MARK: - Calendar list

nonisolated struct CalendarListResponse: Decodable {
    let items: [GCalendar]
}

nonisolated struct GCalendar: Decodable {
    let id: String
    let summary: String
    let backgroundColor: String?

    static func fallback(id: String) -> GCalendar {
        GCalendar(id: id, summary: "Google Calendar", backgroundColor: nil)
    }

    func asEventCalendar(account: GoogleAccount) -> EventCalendar {
        EventCalendar(
            id: id,
            title: summary,
            palette: .blue,
            colorHex: GoogleColor.hex(backgroundColor),
            source: .google,
            accountName: account.email
        )
    }
}

// MARK: - Events

nonisolated struct EventsResponse: Decodable {
    let items: [GEvent]
}

nonisolated struct GEvent: Decodable {
    let id: String?
    let summary: String?
    let location: String?
    let description: String?
    let htmlLink: String?
    let start: GDateTime?
    let end: GDateTime?
    let attendees: [GAttendee]?
    let recurringEventId: String?
    /// RRULE/RDATE/EXDATE lines — only present on a series master.
    let recurrence: [String]?

    func asCalendarEvent(calendar: GCalendar) -> CalendarEvent? {
        guard let id,
              let startInfo = start?.resolved,
              let endInfo = end?.resolved else { return nil }

        return CalendarEvent(
            id: "\(calendar.id)|\(id)",
            title: summary ?? String(localized: "(No title)"),
            start: startInfo.date,
            end: endInfo.date,
            isAllDay: startInfo.isAllDay,
            location: location,
            notes: description,
            url: htmlLink.flatMap(URL.init(string:)),
            guests: attendees?.compactMap { $0.displayName ?? $0.email } ?? [],
            calendarID: calendar.id,
            calendarTitle: calendar.summary,
            palette: .blue,
            colorHex: GoogleColor.hex(calendar.backgroundColor),
            source: .google,
            isRecurring: recurringEventId != nil
        )
    }
}

nonisolated struct GAttendee: Decodable {
    let email: String?
    let displayName: String?
}

/// Google represents times as either `dateTime` (RFC3339) or `date` (all-day).
nonisolated struct GDateTime: Decodable {
    let dateTime: String?
    let date: String?

    var resolved: (date: Date, isAllDay: Bool)? {
        if let dateTime, let parsed = GoogleDate.parseDateTime(dateTime) {
            return (parsed, false)
        }
        if let date, let parsed = GoogleDate.parseDate(date) {
            return (parsed, true)
        }
        return nil
    }
}

// MARK: - Write payload

/// Minimal PATCH body that only rewrites a series' recurrence rules.
nonisolated struct GRecurrencePatch: Encodable {
    var recurrence: [String]
}

nonisolated struct GEventWrite: Encodable {
    var summary: String
    var location: String?
    var description: String?
    var start: GDateTimeWrite
    var end: GDateTimeWrite
    /// RRULE lines, set only when creating a repeating master event.
    var recurrence: [String]?

    init(from draft: EventDraft) {
        summary = draft.title
        location = draft.location.isEmpty ? nil : draft.location
        description = draft.notes.isEmpty ? nil : draft.notes
        start = GDateTimeWrite(date: draft.start, allDay: draft.isAllDay)
        end = GDateTimeWrite(date: GEventWrite.endDate(draft.start, draft.end, allDay: draft.isAllDay),
                             allDay: draft.isAllDay)
        recurrence = GEventWrite.rrule(draft.recurrence)
    }

    init(from event: CalendarEvent) {
        summary = event.title
        location = event.location
        description = event.notes
        start = GDateTimeWrite(date: event.start, allDay: event.isAllDay)
        end = GDateTimeWrite(date: GEventWrite.endDate(event.start, event.end, allDay: event.isAllDay),
                             allDay: event.isAllDay)
        // Recurrence lives on the master; editing a single instance leaves it alone.
        recurrence = nil
    }

    /// Maps a preset to Google's RRULE syntax.
    static func rrule(_ recurrence: Recurrence) -> [String]? {
        switch recurrence {
        case .never:    return nil
        case .daily:    return ["RRULE:FREQ=DAILY"]
        case .weekly:   return ["RRULE:FREQ=WEEKLY"]
        case .biweekly: return ["RRULE:FREQ=WEEKLY;INTERVAL=2"]
        case .monthly:  return ["RRULE:FREQ=MONTHLY"]
        case .yearly:   return ["RRULE:FREQ=YEARLY"]
        }
    }

    /// Google treats an all-day event's `end.date` as exclusive, so ensure it is
    /// at least the day after the start.
    private static func endDate(_ start: Date, _ end: Date, allDay: Bool) -> Date {
        guard allDay else { return end }
        if end <= start {
            return Calendar.current.date(byAdding: .day, value: 1, to: start) ?? end
        }
        return end
    }
}

nonisolated struct GDateTimeWrite: Encodable {
    var dateTime: String?
    var date: String?

    init(date: Date, allDay: Bool) {
        if allDay {
            self.date = GoogleDate.formatDate(date)
        } else {
            self.dateTime = GoogleDate.formatDateTime(date)
        }
    }
}

// MARK: - Date + colour helpers

nonisolated enum GoogleDate {
    // Formatters are created per call: cheap enough at our volume and free of
    // shared mutable (non-Sendable) global state.
    private static func isoParser(fractional: Bool) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds]
                                     : [.withInternetDateTime]
        return f
    }

    private static func dayFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    static func parseDateTime(_ string: String) -> Date? {
        isoParser(fractional: true).date(from: string)
            ?? isoParser(fractional: false).date(from: string)
    }

    static func parseDate(_ string: String) -> Date? {
        dayFormatter().date(from: string)
    }

    static func formatDateTime(_ date: Date) -> String {
        isoParser(fractional: false).string(from: date)
    }

    static func formatDate(_ date: Date) -> String {
        dayFormatter().string(from: date)
    }
}

nonisolated enum GoogleColor {
    /// Parses a "#RRGGBB" hex string into a packed `0xRRGGBB` value.
    static func hex(_ string: String?) -> UInt32? {
        guard let string else { return nil }
        let cleaned = string.hasPrefix("#") ? String(string.dropFirst()) : string
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        return value
    }
}
