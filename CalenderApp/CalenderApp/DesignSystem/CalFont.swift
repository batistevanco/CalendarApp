//
//  CalFont.swift
//  CalenderApp
//
//  Typography scale. Built on the system font so Dynamic Type, weights and
//  optical sizing all come for free. Rounded design is reserved for numerals
//  (times, dates) to give the app its calm, premium character.
//

import SwiftUI

/// Typography tokens. Every text style is relative to a Dynamic Type text
/// style so the app scales gracefully with the user's preferred size.
enum CalFont {
    /// The oversized greeting on the Today screen.
    static let greeting = Font.system(.largeTitle, design: .default, weight: .bold)
    /// Screen and section titles.
    static let title = Font.system(.title2, design: .default, weight: .semibold)
    /// Prominent card titles.
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    /// Default reading body.
    static let body = Font.system(.body, design: .default)
    /// Secondary metadata.
    static let subheadline = Font.system(.subheadline, design: .default)
    /// Fine print, hour labels, chips.
    static let caption = Font.system(.caption, design: .default, weight: .medium)

    /// Large clock-style numerals (countdowns, hero times).
    static let timeDisplay = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    /// Inline times on cards and rows.
    static let timeLabel = Font.system(.subheadline, design: .rounded, weight: .medium)
    /// Faint hour markers down the timeline gutter.
    static let hourMarker = Font.system(.caption2, design: .rounded, weight: .medium)
}
