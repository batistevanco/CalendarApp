//
//  Date+Cal.swift
//  CalenderApp
//
//  Small, focused date utilities used across the timeline, greeting and
//  event formatting. All calendar maths goes through `Calendar.current` so it
//  respects the user's locale, first-weekday and time-zone.
//

import Foundation

nonisolated extension Date {
    /// Midnight at the start of this date, in the current calendar.
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    /// Start of the week containing this date, honouring the user's first weekday.
    var startOfWeek: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: self)?.start ?? startOfDay
    }

    /// Minutes elapsed since midnight (0...1440). The timeline's core coordinate.
    var minutesSinceMidnight: Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    /// True when this date falls on today's calendar day.
    var isToday: Bool { Calendar.current.isDateInToday(self) }

    /// Whether two dates share the same calendar day.
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

/// Part of day, used to pick the greeting and set a calm tone.
nonisolated enum DayPart {
    case morning, afternoon, evening, night

    init(for date: Date) {
        switch date.minutesSinceMidnight / 60 {
        case 5..<12:  self = .morning
        case 12..<17: self = .afternoon
        case 17..<22: self = .evening
        default:      self = .night
        }
    }

    /// A warm, localisable greeting.
    var greeting: String {
        switch self {
        case .morning:   return String(localized: "Good morning")
        case .afternoon: return String(localized: "Good afternoon")
        case .evening:   return String(localized: "Good evening")
        case .night:     return String(localized: "Good night")
        }
    }
}
