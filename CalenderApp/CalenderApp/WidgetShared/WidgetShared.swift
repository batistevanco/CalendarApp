//
//  WidgetShared.swift
//  CalenderApp
//
//  Types shared between the app and the widget/Live-Activity extension. Add
//  THIS FILE to BOTH targets' membership (app + widget extension) in Xcode.
//  It has no dependency on the app's internals, so it compiles in either.
//

import Foundation
import ActivityKit
import SwiftUI

/// App Group used to hand the widget a snapshot of upcoming events.
/// Register this identifier as an App Group capability on BOTH targets.
enum AppGroup {
    static let identifier = "group.be.vancoilliestudio.CalenderApp"
    static let snapshotKey = "widget.snapshot.events"
}

/// A minimal, Codable event the widget can render without touching EventKit.
struct WidgetEvent: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let colorHex: UInt32?
    let location: String?

    var color: Color {
        guard let colorHex else { return .blue }
        return Color(
            .sRGB,
            red: Double((colorHex >> 16) & 0xFF) / 255,
            green: Double((colorHex >> 8) & 0xFF) / 255,
            blue: Double(colorHex & 0xFF) / 255
        )
    }
}

/// Reads/writes the shared snapshot the widget reads from.
enum WidgetSnapshotStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    static func write(_ events: [WidgetEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults?.set(data, forKey: AppGroup.snapshotKey)
    }

    static func read() -> [WidgetEvent] {
        guard let data = defaults?.data(forKey: AppGroup.snapshotKey),
              let events = try? JSONDecoder().decode([WidgetEvent].self, from: data)
        else { return [] }
        return events
    }
}

/// Live Activity attributes for an ongoing/next event countdown.
struct EventActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The event's end (in progress) or start (upcoming) that we count to.
        var targetDate: Date
        /// True while the event is happening, false when it's still upcoming.
        var isInProgress: Bool
        var location: String?
    }

    var title: String
    var colorHex: UInt32?

    var color: Color {
        guard let colorHex else { return .blue }
        return Color(
            .sRGB,
            red: Double((colorHex >> 16) & 0xFF) / 255,
            green: Double((colorHex >> 8) & 0xFF) / 255,
            blue: Double(colorHex & 0xFF) / 255
        )
    }
}
