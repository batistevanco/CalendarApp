//
//  EventLiveActivity.swift
//  CalendarWidgets (extension target)
//
//  The Live Activity UI for the current/next event: a Lock Screen banner and
//  the Dynamic Island in its compact, minimal and expanded forms. Data comes
//  from `EventActivityAttributes`, updated by the app.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct EventLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(context.attributes.color.opacity(0.12))
                .activitySystemActionForegroundColor(context.attributes.color)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.title, systemImage: "calendar")
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(context.attributes.color)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.targetDate, style: .timer)
                        .font(.headline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 64)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.isInProgress ? "Ends" : "Starts")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let location = context.state.location {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "calendar")
                    .foregroundStyle(context.attributes.color)
            } compactTrailing: {
                Text(context.state.targetDate, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "calendar")
                    .foregroundStyle(context.attributes.color)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<EventActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(context.attributes.color)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(context.state.isInProgress ? "Happening now" : "Up next")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let location = context.state.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.targetDate, style: .timer)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(context.attributes.color)
                    .multilineTextAlignment(.trailing)
                Text(context.state.isInProgress ? "remaining" : "to go")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
