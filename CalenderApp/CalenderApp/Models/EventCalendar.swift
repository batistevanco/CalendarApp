//
//  EventCalendar.swift
//  CalenderApp
//
//  A calendar the user has connected (e.g. "Work", "Family"). Lightweight,
//  value-typed and provider-agnostic so Apple/Google/etc. all map onto it.
//

import SwiftUI

/// A single calendar belonging to an account, with its display colour.
nonisolated struct EventCalendar: Identifiable, Hashable, Sendable {
    /// Stable provider identifier (EventKit `calendarIdentifier`, Google id, …).
    let id: String
    var title: String
    var palette: CalPalette
    /// The calendar's true colour (`0xRRGGBB`), overriding `palette` when a
    /// provider supplies it.
    var colorHex: UInt32?
    var source: EventSource
    /// Account the calendar belongs to (e.g. an email address). `nil` for local.
    var accountName: String?
    /// Whether the user has this calendar switched on in our UI.
    var isVisible: Bool

    init(
        id: String,
        title: String,
        palette: CalPalette,
        colorHex: UInt32? = nil,
        source: EventSource,
        accountName: String? = nil,
        isVisible: Bool = true
    ) {
        self.id = id
        self.title = title
        self.palette = palette
        self.colorHex = colorHex
        self.source = source
        self.accountName = accountName
        self.isVisible = isVisible
    }

    var color: Color {
        if let colorHex { return Color(hex: colorHex) }
        return palette.color
    }
}
