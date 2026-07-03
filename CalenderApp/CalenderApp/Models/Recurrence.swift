//
//  Recurrence.swift
//  CalenderApp
//
//  How often an event repeats. A small, provider-agnostic set of presets that
//  map cleanly onto EventKit's `EKRecurrenceRule` and Google's RRULE.
//

import Foundation

nonisolated enum Recurrence: String, Codable, Sendable, CaseIterable, Identifiable {
    case never, daily, weekly, biweekly, monthly, yearly

    var id: String { rawValue }

    var isRepeating: Bool { self != .never }

    /// Full label for the editor picker.
    var label: String {
        switch self {
        case .never:    return String(localized: "Never")
        case .daily:    return String(localized: "Every Day")
        case .weekly:   return String(localized: "Every Week")
        case .biweekly: return String(localized: "Every 2 Weeks")
        case .monthly:  return String(localized: "Every Month")
        case .yearly:   return String(localized: "Every Year")
        }
    }

    /// Compact label for detail rows.
    var shortLabel: String {
        switch self {
        case .never:    return String(localized: "One time")
        case .daily:    return String(localized: "Daily")
        case .weekly:   return String(localized: "Weekly")
        case .biweekly: return String(localized: "Fortnightly")
        case .monthly:  return String(localized: "Monthly")
        case .yearly:   return String(localized: "Yearly")
        }
    }
}

/// The scope to apply when updating or deleting a recurring/repeating event occurrence.
enum RecurrenceScope: String, Sendable, Codable {
    case thisEvent
    case futureEvents
}

