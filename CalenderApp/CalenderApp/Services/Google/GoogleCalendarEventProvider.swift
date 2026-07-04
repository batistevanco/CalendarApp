//
//  GoogleCalendarEventProvider.swift
//  CalenderApp
//
//  Reads and writes Google Calendar via its REST API (v3) over URLSession —
//  no Google SDK. Aggregates across every connected account. Access tokens
//  come from `GoogleAuthService`, refreshed transparently.
//

import Foundation
import SwiftUI

nonisolated final class GoogleCalendarEventProvider: EventProviding {
    let source: EventSource = .google
    private let auth: GoogleAuthService

    init(auth: GoogleAuthService) {
        self.auth = auth
    }

    // MARK: Access

    func access() async -> ProviderAccess {
        let accounts = await auth.accounts
        return accounts.isEmpty ? .notDetermined : .authorized
    }

    /// Google connects interactively via `GoogleAuthService.signIn()`, not here.
    func requestAccess() async -> ProviderAccess {
        await access()
    }

    // MARK: Reads

    func calendars() async throws -> [EventCalendar] {
        let accounts = await auth.accounts
        var result: [EventCalendar] = []
        for account in accounts {
            let token = try await auth.validAccessToken(for: account)
            let list: CalendarListResponse = try await get(
                "users/me/calendarList", token: token
            )
            result.append(contentsOf: list.items.map { $0.asEventCalendar(account: account) })
        }
        return result
    }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        let accounts = await auth.accounts
        guard !accounts.isEmpty else { return [] }

        var result: [CalendarEvent] = []
        for account in accounts {
            let token = try await auth.validAccessToken(for: account)
            let calendars: CalendarListResponse = try await get(
                "users/me/calendarList", token: token
            )
            for calendar in calendars.items {
                let events = try await fetchEvents(
                    calendarID: calendar.id, calendar: calendar,
                    account: account, token: token, interval: interval
                )
                result.append(contentsOf: events)
            }
        }
        return result
    }

    private func fetchEvents(
        calendarID: String, calendar: GCalendar, account: GoogleAccount,
        token: String, interval: DateInterval
    ) async throws -> [CalendarEvent] {
        let iso = ISO8601DateFormatter()
        let query = [
            URLQueryItem(name: "timeMin", value: iso.string(from: interval.start)),
            URLQueryItem(name: "timeMax", value: iso.string(from: interval.end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "250"),
        ]
        let path = "calendars/\(calendarID.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? calendarID)/events"
        let response: EventsResponse = try await get(path, token: token, query: query)
        return response.items.compactMap { $0.asCalendarEvent(calendar: calendar) }
    }

    // MARK: Writes

    func create(_ draft: EventDraft) async throws -> CalendarEvent {
        let (account, calendarID) = try await targetCalendar(for: draft.calendarID)
        let token = try await auth.validAccessToken(for: account)
        let body = GEventWrite(from: draft)
        let path = "calendars/\(calendarID)/events"
        let created: GEvent = try await send("POST", path, token: token, body: body)
        let calendar = try await calendarMeta(calendarID, token: token) ?? .fallback(id: calendarID)
        return created.asCalendarEvent(calendar: calendar) ?? CalendarEvent(
            id: "\(calendarID)|\(created.id ?? UUID().uuidString)",
            title: draft.title, start: draft.start, end: draft.end,
            calendarID: calendarID, calendarTitle: calendar.summary,
            palette: .blue, source: .google
        )
    }

    func update(_ event: CalendarEvent, scope: RecurrenceScope) async throws {
        guard let (calendarID, eventID) = split(event.id) else { return }
        let account = try await account(owning: calendarID)
        let token = try await auth.validAccessToken(for: account)

        // "This event" edits the concrete instance and never touches the series rule.
        if scope == .thisEvent {
            var body = GEventWrite(from: event)
            body.recurrence = nil
            let _: GEvent = try await send("PATCH", "calendars/\(calendarID)/events/\(eventID)",
                                           token: token, body: body)
            return
        }

        // "This and future": split the series. End the old series just before this
        // occurrence, then start a fresh series from the edited instance.
        let masterID = Self.masterID(from: eventID)
        let master: GEvent = try await get("calendars/\(calendarID)/events/\(masterID)", token: token)
        let existing = master.recurrence ?? []

        if !existing.isEmpty {
            let patch = GRecurrencePatch(recurrence: Self.truncate(existing, before: event.start))
            let _: GEvent = try await send("PATCH", "calendars/\(calendarID)/events/\(masterID)",
                                           token: token, body: patch)
        }

        var body = GEventWrite(from: event)
        body.recurrence = event.recurrence.isRepeating
            ? GEventWrite.rrule(event.recurrence)
            : Self.stripLimits(existing)
        let _: GEvent = try await send("POST", "calendars/\(calendarID)/events",
                                       token: token, body: body)
    }

    func delete(_ event: CalendarEvent, scope: RecurrenceScope) async throws {
        guard let (calendarID, eventID) = split(event.id) else { return }
        let account = try await account(owning: calendarID)
        let token = try await auth.validAccessToken(for: account)

        // "This event" removes just the single instance.
        if scope == .thisEvent {
            try await sendVoid("DELETE", "calendars/\(calendarID)/events/\(eventID)", token: token)
            return
        }

        // "This and future": truncate the master's recurrence so this occurrence
        // and everything after it drop off, leaving past occurrences intact.
        let masterID = Self.masterID(from: eventID)
        let master: GEvent = try await get("calendars/\(calendarID)/events/\(masterID)", token: token)
        let existing = master.recurrence ?? []

        guard !existing.isEmpty else {
            // Not really a series — just delete it.
            try await sendVoid("DELETE", "calendars/\(calendarID)/events/\(masterID)", token: token)
            return
        }
        let patch = GRecurrencePatch(recurrence: Self.truncate(existing, before: event.start))
        let _: GEvent = try await send("PATCH", "calendars/\(calendarID)/events/\(masterID)",
                                       token: token, body: patch)
    }

    // MARK: Recurrence rule helpers

    /// The series-master id for a Google instance id ("<master>_<timestamp>").
    private static func masterID(from eventID: String) -> String {
        String(eventID.split(separator: "_").first ?? Substring(eventID))
    }

    /// Ends each RRULE just before `date` by rewriting its UNTIL, leaving
    /// RDATE/EXDATE lines untouched.
    private static func truncate(_ lines: [String], before date: Date) -> [String] {
        let until = untilStamp(date.addingTimeInterval(-1))
        return lines.map { line in
            guard line.uppercased().hasPrefix("RRULE") else { return line }
            return stripLimitParams(line) + ";UNTIL=\(until)"
        }
    }

    /// Removes any UNTIL/COUNT bounds so an RRULE becomes open-ended (for a new series).
    private static func stripLimits(_ lines: [String]) -> [String] {
        lines.map { $0.uppercased().hasPrefix("RRULE") ? stripLimitParams($0) : $0 }
    }

    private static func stripLimitParams(_ line: String) -> String {
        line.split(separator: ";").map(String.init)
            .filter { part in
                let u = part.uppercased()
                return !u.hasPrefix("UNTIL=") && !u.hasPrefix("COUNT=")
            }
            .joined(separator: ";")
    }

    /// RFC5545 UTC timestamp (`yyyyMMdd'T'HHmmss'Z'`) for an RRULE UNTIL value.
    private static func untilStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.string(from: date)
    }

    // MARK: Routing helpers

    /// Our Google event ids are "<calendarID>|<eventID>".
    private func split(_ id: String) -> (calendarID: String, eventID: String)? {
        let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    private func targetCalendar(for calendarID: String?) async throws -> (GoogleAccount, String) {
        let accounts = await auth.accounts
        guard let first = accounts.first else { throw GoogleError.noRefreshToken }
        guard let calendarID else { return (first, "primary") }
        let account = (try? await self.account(owning: calendarID)) ?? first
        return (account, calendarID)
    }

    private func account(owning calendarID: String) async throws -> GoogleAccount {
        let accounts = await auth.accounts
        for account in accounts {
            let token = try await auth.validAccessToken(for: account)
            let list: CalendarListResponse = try await get("users/me/calendarList", token: token)
            if list.items.contains(where: { $0.id == calendarID }) { return account }
        }
        guard let first = accounts.first else { throw GoogleError.noRefreshToken }
        return first
    }

    private func calendarMeta(_ calendarID: String, token: String) async throws -> GCalendar? {
        let list: CalendarListResponse = try await get("users/me/calendarList", token: token)
        return list.items.first { $0.id == calendarID }
    }

    // MARK: Networking

    private func get<T: Decodable>(_ path: String, token: String,
                                   query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(
            url: GoogleConfig.apiBase.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    private func send<T: Decodable>(_ method: String, _ path: String, token: String,
                                    body: some Encodable) async throws -> T {
        var request = URLRequest(url: GoogleConfig.apiBase.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func sendVoid(_ method: String, _ path: String, token: String) async throws {
        var request = URLRequest(url: GoogleConfig.apiBase.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw GoogleError.decoding
        }
        return decoded
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw GoogleError.decoding }
        guard (200..<300).contains(http.statusCode) else { throw GoogleError.http(http.statusCode) }
    }
}
