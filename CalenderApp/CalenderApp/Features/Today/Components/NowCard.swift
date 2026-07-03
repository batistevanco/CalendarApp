//
//  NowCard.swift
//  CalenderApp
//
//  The hero of the Today screen. It answers one question at a glance: what's
//  happening right now? Either the in-progress event with a live progress bar
//  and time remaining, or a calm "you're free" state pointing at what's next.
//

import SwiftUI

struct NowCard: View {
    let current: CalendarEvent?
    let next: CalendarEvent?
    let now: Date
    var onSelect: (CalendarEvent) -> Void = { _ in }

    var body: some View {
        Group {
            if let current {
                activeCard(current)
            } else {
                freeCard
            }
        }
        .padding(CalSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: CalRadius.card)
        .animation(.smooth(duration: 0.5), value: current?.id)
    }

    // MARK: In-progress

    private func activeCard(_ event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: CalSpacing.m) {
            HStack {
                Label {
                    Text("Now").textCase(.uppercase)
                } icon: {
                    Circle().fill(event.color).frame(width: 8, height: 8)
                }
                .font(CalFont.caption)
                .foregroundStyle(event.color)

                Spacer()

                Text(event.timeRangeText)
                    .font(CalFont.timeLabel)
                    .foregroundStyle(CalColor.secondaryText)
            }

            Text(event.title)
                .font(CalFont.title)
                .foregroundStyle(CalColor.primaryText)

            if let location = event.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(CalFont.subheadline)
                    .foregroundStyle(CalColor.secondaryText)
            }

            ProgressBar(progress: event.progress(at: now), tint: event.color)
                .accessibilityHidden(true)

            Text(remainingText(until: event.end))
                .font(CalFont.timeLabel)
                .foregroundStyle(event.color)
        }
        .contentShape(.rect)
        .onTapGesture { onSelect(event) }
    }

    // MARK: Free time

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: CalSpacing.m) {
            Label {
                Text("Free").textCase(.uppercase)
            } icon: {
                Image(systemName: "sparkles")
            }
            .font(CalFont.caption)
            .foregroundStyle(CalColor.accent)

            if let next {
                Text("You're free until \(next.start.formatted(.dateTime.hour().minute()))")
                    .font(CalFont.title)
                    .foregroundStyle(CalColor.primaryText)

                HStack(spacing: CalSpacing.s) {
                    Circle().fill(next.color).frame(width: 8, height: 8)
                    Text("Next · \(next.title)")
                        .font(CalFont.subheadline)
                        .foregroundStyle(CalColor.secondaryText)
                    Spacer(minLength: 0)
                    Text(startsInText(next.start))
                        .font(CalFont.timeLabel)
                        .foregroundStyle(next.color)
                }
                .contentShape(.rect)
                .onTapGesture { onSelect(next) }
            } else {
                Text("Nothing left today")
                    .font(CalFont.title)
                    .foregroundStyle(CalColor.primaryText)
                Text("Enjoy the open space.")
                    .font(CalFont.subheadline)
                    .foregroundStyle(CalColor.secondaryText)
            }
        }
    }

    // MARK: Copy

    private func remainingText(until end: Date) -> String {
        let mins = Int(end.timeIntervalSince(now) / 60) + 1
        return "\(durationPhrase(minutes: mins)) left"
    }

    private func startsInText(_ start: Date) -> String {
        let mins = Int(start.timeIntervalSince(now) / 60) + 1
        return "in \(durationPhrase(minutes: mins))"
    }

    /// Compact, human duration: "45 min", "1 hr", "2 hr 15 min".
    private func durationPhrase(minutes: Int) -> String {
        let m = max(minutes, 1)
        let h = m / 60
        let rem = m % 60
        if h == 0 { return "\(rem) min" }
        if rem == 0 { return "\(h) hr" }
        return "\(h) hr \(rem) min"
    }
}

/// A rounded progress bar tinted to the event colour.
private struct ProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * progress, 6))
            }
        }
        .frame(height: 6)
        .animation(.smooth, value: progress)
    }
}
