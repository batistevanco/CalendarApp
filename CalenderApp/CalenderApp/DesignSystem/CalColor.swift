//
//  CalColor.swift
//  CalenderApp
//
//  Semantic colour tokens and the event colour palette. We lean on system
//  materials and hierarchical styles so light/dark, high-contrast and
//  accessibility settings are honoured automatically.
//

import SwiftUI

/// Semantic colour tokens for the app. Prefer these over raw `Color` literals.
enum CalColor {
    /// The app's accent. Resolves to the environment accent set by `.tint` at
    /// the root (driven by `ThemeManager`), so the user's chosen colour flows
    /// everywhere. Defaults to calm indigo when no tint is present (previews).
    static var accent: Color { Color.accentColor }

    /// Primary reading colour for titles and body.
    static let primaryText = Color.primary
    /// Supporting colour for metadata and secondary lines.
    static let secondaryText = Color.secondary
    /// Faint colour for hints, hour labels and disabled glyphs.
    static let tertiaryText = Color(.tertiaryLabel)

    /// The base canvas behind all content.
    static let canvas = Color(.systemBackground)
    /// A subtly raised surface for grouped content.
    static let surface = Color(.secondarySystemBackground)

    /// Hairline separators and grid lines.
    static let hairline = Color(.separator)
}

/// The curated palette used to tint calendars and their events. Named colours
/// map to Apple's calendar hues but are hand-tuned for our glass surfaces.
nonisolated enum CalPalette: String, CaseIterable, Codable, Sendable {
    case indigo, blue, teal, green, lime, yellow, orange, red, pink, purple, graphite

    var color: Color {
        switch self {
        case .indigo:   return Color(hex: 0x5B6CFF)
        case .blue:     return Color(hex: 0x2F97FF)
        case .teal:     return Color(hex: 0x24C4C9)
        case .green:    return Color(hex: 0x34C759)
        case .lime:     return Color(hex: 0x9BDE3B)
        case .yellow:   return Color(hex: 0xFFCC00)
        case .orange:   return Color(hex: 0xFF9500)
        case .red:      return Color(hex: 0xFF453A)
        case .pink:     return Color(hex: 0xFF4F81)
        case .purple:   return Color(hex: 0xAF52DE)
        case .graphite: return Color(hex: 0x8E8E93)
        }
    }
}

extension Color {
    /// Creates a colour from a `0xRRGGBB` integer for a compact, readable palette.
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
