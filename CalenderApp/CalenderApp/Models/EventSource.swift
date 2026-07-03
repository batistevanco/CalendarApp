//
//  EventSource.swift
//  CalenderApp
//
//  Where a calendar originates. The app never owns data — it presents calendars
//  from these providers. New providers slot in here without touching the UI.
//

import SwiftUI

/// A backing provider for a calendar. The app is a beautiful lens over these.
enum EventSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case apple
    case google
    case outlook
    case exchange
    case caldav

    var id: String { rawValue }

    /// Human-facing name.
    var displayName: String {
        switch self {
        case .apple:    return "Apple Calendar"
        case .google:   return "Google Calendar"
        case .outlook:  return "Outlook"
        case .exchange: return "Exchange"
        case .caldav:   return "CalDAV"
        }
    }

    /// SF Symbol used in account rows and legends.
    var symbolName: String {
        switch self {
        case .apple:    return "applelogo"
        case .google:   return "g.circle.fill"
        case .outlook:  return "envelope.fill"
        case .exchange: return "arrow.triangle.2.circlepath"
        case .caldav:   return "network"
        }
    }

    /// Providers wired up in the current build. Others are future-ready.
    var isAvailable: Bool {
        switch self {
        case .apple, .google: return true
        case .outlook, .exchange, .caldav: return false
        }
    }
}
