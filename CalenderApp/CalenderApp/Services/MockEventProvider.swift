//
//  MockEventProvider.swift
//  CalenderApp
//
//  An in-memory provider that generates a believable schedule around "now".
//  It lets us build and preview the whole UI before wiring EventKit/Google,
//  and doubles as SwiftUI-preview and test data.
//

import Foundation

/// Generates a realistic day of events relative to the current time so the
/// Today screen always has something alive to show.
nonisolated struct MockEventProvider: EventProviding {
    let source: EventSource = .apple

    // A small set of connected calendars.
    private let personal = EventCalendar(id: "cal.personal", title: "Personal",
                                         palette: .indigo, source: .apple, accountName: "iCloud")
    private let work = EventCalendar(id: "cal.work", title: "Work",
                                     palette: .blue, source: .google, accountName: "you@work.com")
    private let health = EventCalendar(id: "cal.health", title: "Health",
                                       palette: .green, source: .apple, accountName: "iCloud")
    private let social = EventCalendar(id: "cal.social", title: "Social",
                                       palette: .pink, source: .google, accountName: "you@gmail.com")

    func access() async -> ProviderAccess { .authorized }
    func requestAccess() async -> ProviderAccess { .authorized }

    func calendars() async throws -> [EventCalendar] {
        [personal, work, health, social]
    }

    /// The mock is stateless (it regenerates each day), so edits are a no-op.
    /// Optimistic UI updates in `CalendarStore` keep previews interactive.
    func update(_ event: CalendarEvent, scope: RecurrenceScope) async throws {}

    func delete(_ event: CalendarEvent, scope: RecurrenceScope) async throws {}

    /// Returns the draft resolved into a full event so the store can show it.
    func create(_ draft: EventDraft) async throws -> CalendarEvent {
        let calendar = personal
        return CalendarEvent(
            id: "mock.\(UUID().uuidString)",
            title: draft.title,
            start: draft.start,
            end: draft.end,
            isAllDay: draft.isAllDay,
            location: draft.location.isEmpty ? nil : draft.location,
            notes: draft.notes.isEmpty ? nil : draft.notes,
            calendarID: draft.calendarID ?? calendar.id,
            calendarTitle: calendar.title,
            palette: calendar.palette,
            source: calendar.source,
            recurrence: draft.recurrence,
            isRecurring: draft.recurrence.isRepeating
        )
    }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        // Tiny latency so loading transitions are exercised realistically.
        try? await Task.sleep(for: .milliseconds(180))
        let cal = Calendar.current
        var result: [CalendarEvent] = []

        // Generate a schedule for each day the interval touches.
        var day = cal.startOfDay(for: interval.start)
        while day < interval.end {
            result.append(contentsOf: schedule(for: day, calendar: cal))
            day = cal.date(byAdding: .day, value: 1, to: day) ?? interval.end
        }
        return result.filter { interval.intersects(DateInterval(start: $0.start, end: max($0.end, $0.start.addingTimeInterval(60)))) }
    }

    /// Builds a plausible day. Weekdays are busier than weekends.
    private func schedule(for day: Date, calendar cal: Calendar) -> [CalendarEvent] {
        func at(_ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        let weekday = cal.component(.weekday, from: day)
        let isWeekend = (weekday == 1 || weekday == 7)
        let key = Int(day.timeIntervalSince1970)

        if isWeekend {
            return [
                event("\(key).run", "Morning run", at(8, 30), at(9, 15), health,
                      location: "Riverside Park", travel: 10),
                event("\(key).brunch", "Brunch with Sam", at(11, 0), at(12, 30), social,
                      location: "Café Lumen", guests: ["Sam"]),
                event("\(key).read", "Reading & coffee", at(15, 0), at(16, 0), personal),
            ]
        }

        return [
            event("\(key).standup", "Team standup", at(9, 30), at(9, 45), work,
                  location: "Zoom", guests: ["Design", "Eng"]),
            event("\(key).design", "Design review", at(10, 0), at(11, 0), work,
                  location: "Studio", guests: ["Maya", "Jon"]),
            // Deliberately overlaps the design review to exercise the layout.
            event("\(key).call", "Investor call", at(10, 30), at(11, 15), work,
                  location: "Phone", guests: ["A. Reed"]),
            event("\(key).lunch", "Lunch with Alex", at(12, 30), at(13, 30), social,
                  location: "Green Bowl", guests: ["Alex"], travel: 12),
            event("\(key).focus", "Focus: roadmap", at(14, 0), at(15, 30), work),
            event("\(key).gym", "Gym session", at(18, 0), at(19, 0), health,
                  location: "Fitness First", travel: 15),
            event("\(key).dinner", "Dinner", at(20, 0), at(21, 30), personal,
                  location: "Home"),
        ]
    }

    private func event(
        _ id: String, _ title: String, _ start: Date, _ end: Date,
        _ calendar: EventCalendar, location: String? = nil,
        guests: [String] = [], travel: Int? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, title: title, start: start, end: end,
            location: location, guests: guests, travelMinutes: travel,
            calendarID: calendar.id, calendarTitle: calendar.title,
            palette: calendar.palette, source: calendar.source
        )
    }
}
