//
//  NaturalLanguageEventParser.swift
//  CalenderApp
//
//  Turns a phrase like "Tomorrow 14:00 Dentist" or "Fri dinner 7pm" into a
//  structured draft. Built on `NSDataDetector` — the same engine Mail/Messages
//  use for date detection — so it handles a wide range of natural phrasings and
//  locales without a hand-rolled grammar.
//

import Foundation

/// The result of interpreting a phrase.
nonisolated struct ParsedEvent: Sendable, Equatable {
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    /// True when a date/time was actually recognised (vs. a plain title).
    var matchedDate: Bool
}

nonisolated enum NaturalLanguageEventParser {
    /// Interprets `text`, relative to `now`, into a draftable event.
    static func parse(_ text: String, now: Date = .now) -> ParsedEvent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackStart = defaultStart(now: now)

        guard !trimmed.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        else {
            return ParsedEvent(title: trimmed, start: fallbackStart,
                               end: fallbackStart.addingTimeInterval(3600),
                               isAllDay: false, matchedDate: false)
        }

        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        // Use the last match so titles containing numbers ("Q3 review 5pm")
        // don't get mistaken for the time.
        guard let match = detector.matches(in: text, range: range).last,
              let matchedDate = match.date else {
            return ParsedEvent(title: cleanTitle(trimmed), start: fallbackStart,
                               end: fallbackStart.addingTimeInterval(3600),
                               isAllDay: false, matchedDate: false)
        }

        let matchedText = ns.substring(with: match.range)
        let timed = containsTime(matchedText)

        let start: Date
        let end: Date
        if timed {
            start = matchedDate
            end = match.duration > 0
                ? start.addingTimeInterval(match.duration)
                : start.addingTimeInterval(3600)
        } else {
            start = matchedDate.startOfDay
            end = start
        }

        let title = cleanTitle(ns.replacingCharacters(in: match.range, with: " "))
        return ParsedEvent(title: title, start: start, end: end,
                           isAllDay: !timed, matchedDate: true)
    }

    // MARK: Helpers

    /// The next whole hour — a sane default when no time is given.
    private static func defaultStart(now: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
        comps.hour = (comps.hour ?? 0) + 1
        comps.minute = 0
        return cal.date(from: comps) ?? now
    }

    /// Whether a matched date substring actually specified a time of day.
    private static func containsTime(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("noon") || lower.contains("midnight") { return true }
        if lower.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #"\d\s*(am|pm)"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// Cleans the leftover title: collapse whitespace and trim edge filler words
    /// ("at", "on", "from") and stray punctuation.
    private static func cleanTitle(_ raw: String) -> String {
        let collapsed = raw.replacingOccurrences(
            of: #"\s+"#, with: " ", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let fillers: Set<String> = ["at", "on", "from", "for", "the", "@"]
        var words = collapsed.split(separator: " ").map(String.init)
        while let first = words.first, fillers.contains(first.lowercased()) {
            words.removeFirst()
        }
        while let last = words.last, fillers.contains(last.lowercased()) {
            words.removeLast()
        }
        return words.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.-"))
    }
}
