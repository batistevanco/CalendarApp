//
//  CalSpacing.swift
//  CalenderApp
//
//  Layout constants for the design system. A single, deliberate spacing scale
//  keeps rhythm consistent across every screen. Values follow a 4pt base grid.
//

import CoreGraphics

/// Spacing scale. Use these instead of hard-coded numbers so the app breathes
/// with one consistent rhythm.
enum CalSpacing {
    /// 2pt — hairline gaps between tightly-coupled elements.
    static let xxs: CGFloat = 2
    /// 4pt — icon-to-label, chip internals.
    static let xs: CGFloat = 4
    /// 8pt — default gap between related elements.
    static let s: CGFloat = 8
    /// 12pt — comfortable inner padding.
    static let m: CGFloat = 12
    /// 16pt — standard card padding.
    static let l: CGFloat = 16
    /// 20pt — the horizontal screen margin used app-wide.
    static let screen: CGFloat = 20
    /// 24pt — separation between distinct groups.
    static let xl: CGFloat = 24
    /// 32pt — section spacing.
    static let xxl: CGFloat = 32
    /// 48pt — generous, calm whitespace between major regions.
    static let xxxl: CGFloat = 48
}

/// Corner radii tuned to feel like first-party iOS surfaces.
enum CalRadius {
    static let chip: CGFloat = 10
    static let card: CGFloat = 16
    static let sheet: CGFloat = 28
    static let event: CGFloat = 12
    /// Fully rounded — for pills and the live-time knob.
    static let pill: CGFloat = 999
}
