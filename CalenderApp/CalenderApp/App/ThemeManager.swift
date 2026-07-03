//
//  ThemeManager.swift
//  CalenderApp
//
//  User-selectable appearance: accent colour and light/dark mode, persisted
//  across launches. The accent is applied once at the root via `.tint`, and
//  `CalColor.accent` resolves to that environment accent — so a single change
//  recolours the whole app, live.
//

import SwiftUI
import Observation

/// Light / Dark / follow-System.
enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .light:  return String(localized: "Light")
        case .dark:   return String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

@MainActor
@Observable
final class ThemeManager {
    var accent: CalPalette {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }
    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let accent = "theme.accent"
        static let appearance = "theme.appearance"
    }

    init() {
        let storedAccent = defaults.string(forKey: Keys.accent).flatMap(CalPalette.init(rawValue:))
        accent = storedAccent ?? .indigo
        let storedAppearance = defaults.string(forKey: Keys.appearance).flatMap(AppearanceMode.init(rawValue:))
        appearance = storedAppearance ?? .system
    }

    var accentColor: Color { accent.color }
}
