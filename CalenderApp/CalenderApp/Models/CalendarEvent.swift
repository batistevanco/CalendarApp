//
//  CalendarEvent.swift
//  CalenderApp
//
//  The core domain model: a single event, normalised across all providers.
//  Value-typed and `Sendable` so it flows safely across async boundaries.
//

import SwiftUI

/// A normalised calendar event. Providers translate their native events into
/// this shape; the entire UI is built against it.
nonisolated struct CalendarEvent: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?
    var url: URL?
    var guests: [String]
    /// Minutes of travel time to reach the event, if known.
    var travelMinutes: Int?

    /// Denormalised calendar metadata so a card can render without a lookup.
    var calendarID: String
    var calendarTitle: String
    var palette: CalPalette
    /// The calendar's true colour (`0xRRGGBB`) when a provider supplies one.
    /// Overrides `palette` so real Apple/Google calendar hues are honoured.
    var colorHex: UInt32?
    var source: EventSource
    /// The chosen repeat pattern (best-effort when read back).
    var recurrence: Recurrence
    /// Whether this occurrence belongs to a repeating series.
    var isRecurring: Bool

    init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        guests: [String] = [],
        travelMinutes: Int? = nil,
        calendarID: String,
        calendarTitle: String,
        palette: CalPalette,
        colorHex: UInt32? = nil,
        source: EventSource,
        recurrence: Recurrence = .never,
        isRecurring: Bool = false
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.url = url
        self.guests = guests
        self.travelMinutes = travelMinutes
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.palette = palette
        self.colorHex = colorHex
        self.source = source
        self.recurrence = recurrence
        self.isRecurring = isRecurring
    }

    /// The event's display colour: the provider's true hue when known,
    /// otherwise the semantic palette colour.
    var color: Color {
        if let colorHex { return Color(hex: colorHex) }
        return palette.color
    }

    /// Event length. Clamped to at least one minute so zero-length events still
    /// draw a tappable card on the timeline.
    var duration: TimeInterval { max(end.timeIntervalSince(start), 60) }

    /// Whether `date` falls within the event's running time.
    func isInProgress(at date: Date) -> Bool {
        date >= start && date < end
    }

    /// Fraction elapsed (0...1) at `date`, for progress rings and glow.
    func progress(at date: Date) -> Double {
        guard end > start else { return 0 }
        let f = date.timeIntervalSince(start) / end.timeIntervalSince(start)
        return min(max(f, 0), 1)
    }
}

// MARK: - Formatting

extension CalendarEvent {
    /// "9:30 – 10:15" style range in the user's locale, or "All-day".
    var timeRangeText: String {
        if isAllDay { return String(localized: "All-day") }
        let f = Date.FormatStyle.dateTime.hour().minute()
        return "\(start.formatted(f)) – \(end.formatted(f))"
    }
}
