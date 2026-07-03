//
//  WidgetBridge.swift
//  CalenderApp
//
//  Publishes a snapshot of upcoming events to the shared App Group and asks
//  WidgetKit to refresh. Called whenever the app's view of the near future
//  changes (launch, foreground, edits).
//

import Foundation
import WidgetKit

extension WidgetEvent {
    init(from event: CalendarEvent) {
        self.init(
            id: event.id,
            title: event.title,
            start: event.start,
            end: event.end,
            isAllDay: event.isAllDay,
            colorHex: event.colorHex ?? WidgetEvent.paletteHex(event.palette),
            location: event.location
        )
    }

    /// Falls back to the palette's hue when a provider gave no explicit colour.
    private static func paletteHex(_ palette: CalPalette) -> UInt32? {
        switch palette {
        case .indigo:   return 0x5B6CFF
        case .blue:     return 0x2F97FF
        case .teal:     return 0x24C4C9
        case .green:    return 0x34C759
        case .lime:     return 0x9BDE3B
        case .yellow:   return 0xFFCC00
        case .orange:   return 0xFF9500
        case .red:      return 0xFF453A
        case .pink:     return 0xFF4F81
        case .purple:   return 0xAF52DE
        case .graphite: return 0x8E8E93
        }
    }
}

enum WidgetBridge {
    /// Writes the next handful of events and reloads all widget timelines.
    static func publish(_ events: [CalendarEvent]) {
        let snapshot = events.prefix(20).map(WidgetEvent.init(from:))
        WidgetSnapshotStore.write(Array(snapshot))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
