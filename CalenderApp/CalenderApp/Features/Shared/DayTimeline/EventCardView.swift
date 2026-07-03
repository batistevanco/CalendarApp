//
//  EventCardView.swift
//  CalenderApp
//
//  A single event on the timeline. Adapts its density to the height it's given
//  and gains a soft glow while the event is in progress.
//

import SwiftUI

struct EventCardView: View {
    let event: CalendarEvent
    /// Rendered height, so the card can choose a compact or full layout.
    let height: CGFloat
    /// Live reference time, for the in-progress glow.
    let now: Date

    private var isActive: Bool { event.isInProgress(at: now) }
    private var isCompact: Bool { height < 46 }

    var body: some View {
        HStack(alignment: .top, spacing: CalSpacing.s) {
            Capsule()
                .fill(event.color)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, isCompact ? 4 : CalSpacing.s)
        .padding(.horizontal, CalSpacing.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(event.color.opacity(isActive ? 0.28 : 0.16),
                    in: .rect(cornerRadius: CalRadius.event, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CalRadius.event, style: .continuous)
                .strokeBorder(event.color.opacity(isActive ? 0.9 : 0.0),
                              lineWidth: isActive ? 1.5 : 0)
        )
        .shadow(color: event.color.opacity(isActive ? 0.35 : 0),
                radius: isActive ? 10 : 0, y: 2)
        .animation(.smooth(duration: 0.4), value: isActive)
        .contentShape(.rect(cornerRadius: CalRadius.event))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    /// A single spoken summary of the event for VoiceOver.
    private var accessibilityLabel: String {
        var parts = [event.title, event.timeRangeText]
        if let location = event.location, !location.isEmpty { parts.append(location) }
        if isActive { parts.append(String(localized: "in progress")) }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var content: some View {
        if isCompact {
            HStack(spacing: CalSpacing.xs) {
                Text(event.title)
                    .font(CalFont.caption)
                    .foregroundStyle(CalColor.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(event.start, format: .dateTime.hour().minute())
                    .font(CalFont.hourMarker)
                    .foregroundStyle(CalColor.secondaryText)
                    .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(CalFont.headline)
                    .foregroundStyle(CalColor.primaryText)
                    .lineLimit(height > 70 ? 2 : 1)
                    .minimumScaleFactor(0.85)

                Text(event.timeRangeText)
                    .font(CalFont.hourMarker)
                    .foregroundStyle(event.color)

                if let location = event.location, height > 74 {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(CalFont.hourMarker)
                        .foregroundStyle(CalColor.secondaryText)
                        .lineLimit(1)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }
}
