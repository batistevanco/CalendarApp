//
//  GreetingHeader.swift
//  CalenderApp
//
//  The calm, oversized greeting at the top of Today: time-aware salutation,
//  the full date, and two quiet chips for weather (placeholder) and the day's
//  event count.
//

import SwiftUI

struct GreetingHeader: View {
    let date: Date
    let now: Date
    let eventCount: Int
    /// Current conditions, when WeatherKit has them.
    var weather: WeatherNow?

    var body: some View {
        VStack(alignment: .leading, spacing: CalSpacing.s) {
            Text(DayPart(for: now).greeting)
                .font(CalFont.greeting)
                .foregroundStyle(CalColor.primaryText)

            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(CalFont.title)
                .foregroundStyle(CalColor.secondaryText)

            HStack(spacing: CalSpacing.s) {
                if let weather {
                    InfoChip(symbol: weather.symbolName,
                             text: weather.temperatureText,
                             tint: .orange)
                        .accessibilityLabel("\(weather.condition), \(weather.temperatureText)")
                }
                InfoChip(symbol: "calendar", text: eventSummary, tint: CalColor.accent)
            }
            .padding(.top, CalSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eventSummary: String {
        switch eventCount {
        case 0:  return String(localized: "No events")
        case 1:  return String(localized: "1 event")
        default: return String(localized: "\(eventCount) events")
        }
    }
}

/// A small rounded chip used in the header. Quiet by default, tinted glyph.
private struct InfoChip: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: CalSpacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(text)
                .foregroundStyle(CalColor.secondaryText)
        }
        .font(CalFont.caption)
        .padding(.horizontal, CalSpacing.m)
        .padding(.vertical, CalSpacing.s)
        .glassCard(cornerRadius: CalRadius.pill)
    }
}
