//
//  CalendarWidgetBundle.swift
//  CalendarWidgets (extension target)
//
//  The widget bundle: an "Up Next" glanceable widget, a "Today" schedule
//  widget, and the event Live Activity. Reads the shared App Group snapshot the
//  app publishes — no EventKit access needed in the extension.
//
//  These files belong to the WIDGET EXTENSION target. See WIDGETS_SETUP.md.
//

import WidgetKit
import SwiftUI

@main
struct CalendarWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        ScheduleWidget()
        EventLiveActivity()
    }
}

// MARK: - Timeline

struct EventEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEvent]
}

struct EventProvider: TimelineProvider {
    func placeholder(in context: Context) -> EventEntry {
        EventEntry(date: .now, events: EventProvider.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (EventEntry) -> Void) {
        let events = context.isPreview ? EventProvider.sample : WidgetSnapshotStore.read()
        completion(EventEntry(date: .now, events: events))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> Void) {
        let all = WidgetSnapshotStore.read()
        let now = Date()

        // Refresh at "now" and at each upcoming boundary so countdowns roll over.
        var dates = [now]
        dates += all
            .flatMap { [$0.start, $0.end] }
            .filter { $0 > now }
            .sorted()
            .prefix(8)

        let entries = dates.map { EventEntry(date: $0, events: all) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static let sample: [WidgetEvent] = [
        WidgetEvent(id: "1", title: "Design review", start: .now.addingTimeInterval(1800),
                    end: .now.addingTimeInterval(5400), isAllDay: false,
                    colorHex: 0x2F97FF, location: "Studio"),
        WidgetEvent(id: "2", title: "Lunch with Alex", start: .now.addingTimeInterval(9000),
                    end: .now.addingTimeInterval(12600), isAllDay: false,
                    colorHex: 0xFF4F81, location: "Green Bowl"),
    ]
}

// MARK: - Snapshot helpers

extension Array where Element == WidgetEvent {
    /// Upcoming or in-progress timed events, soonest first, from a reference date.
    func upcoming(from date: Date) -> [WidgetEvent] {
        filter { !$0.isAllDay && $0.end > date }.sorted { $0.start < $1.start }
    }

    /// Events that fall on the same day as `date`.
    func today(_ date: Date) -> [WidgetEvent] {
        let cal = Calendar.current
        return filter { !$0.isAllDay && cal.isDate($0.start, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }
}

// MARK: - Up Next

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpNextWidget", provider: EventProvider()) { entry in
            UpNextView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Up Next")
        .description("Your next event at a glance.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct UpNextView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EventEntry

    private var event: WidgetEvent? { entry.events.upcoming(from: entry.date).first }

    var body: some View {
        switch family {
        case .accessoryInline:
            if let event {
                Text("\(event.title) · \(event.start, style: .relative)")
            } else {
                Text("No events")
            }
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let event {
                Text("UP NEXT").font(.caption2).foregroundStyle(.secondary)
                Text(event.title).font(.headline).lineLimit(1)
                Text(event.start, style: .relative).font(.caption)
            } else {
                Text("Nothing scheduled").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let event {
                HStack(spacing: 6) {
                    Capsule().fill(event.color).frame(width: 3, height: 14)
                    Text("UP NEXT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text(event.start, style: .time).font(.subheadline).foregroundStyle(.secondary)
                Text(event.start, style: .relative)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(event.color)
            } else {
                Text("Nothing\nscheduled").font(.headline).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Today schedule

struct ScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScheduleWidget", provider: EventProvider()) { entry in
            ScheduleView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Your schedule for the day.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct ScheduleView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EventEntry

    private var rows: [WidgetEvent] {
        Array(entry.events.today(entry.date).prefix(family == .systemLarge ? 7 : 3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.date, format: .dateTime.weekday(.wide).day().month())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if rows.isEmpty {
                Spacer()
                Text("No more events today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(rows) { event in
                    HStack(spacing: 8) {
                        Capsule().fill(event.color).frame(width: 3, height: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text(event.start, style: .time)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
