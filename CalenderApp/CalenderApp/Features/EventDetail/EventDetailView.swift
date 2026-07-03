//
//  EventDetailView.swift
//  CalenderApp
//
//  Redesigned to a premium modern details view matching the screenshots.
//  Includes custom back and options toolbar, badge, split time card, and attendee avatars.
//

import SwiftUI

struct EventDetailView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(WeatherStore.self) private var weather
    @Environment(\.dismiss) private var dismiss

    let event: CalendarEvent

    @State private var isEditing = false
    @State private var confirmingDelete = false

    /// The freshest copy from the store (reflects edits made in the editor,
    /// even ones that moved the event to another day).
    private var live: CalendarEvent {
        store.event(withID: event.id) ?? event
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalSpacing.xl) {
                    // Header Subtitle
                    Text("Event Details")
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(CalColor.secondaryText)
                    
                    // Platform Badge
                    Text(meetingPlatform(for: live))
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(live.color)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(live.color.opacity(0.12))
                        .clipShape(Capsule())
                    
                    // Big Bold Title
                    Text(live.title)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(CalColor.primaryText)
                        .lineSpacing(4)
                        .padding(.vertical, CalSpacing.xs)
                    
                    // Split Time Card
                    splitTimeCard
                    
                    // Other Details (Location, Guests, Notes, Weather)
                    detailsSection
                    
                    // Delete Button
                    deleteButton
                }
                .padding(CalSpacing.xl)
            }
            .background(CalColor.canvas)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(CalColor.primaryText)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isEditing = true
                        } label: {
                            Label("Edit Event", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Label("Delete Event", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(CalColor.primaryText)
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                EventEditor(mode: .edit(live))
            }
            .confirmationDialog(
                (live.isRecurring || live.recurrence.isRepeating) ? "This is a repeating event." : "Delete this event?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                if live.isRecurring || live.recurrence.isRepeating {
                    Button("Delete This Occurrence Only", role: .destructive) {
                        Haptics.commit()
                        Task { await store.delete(live, scope: .thisEvent) }
                        dismiss()
                    }
                    Button("Delete All Future Events", role: .destructive) {
                        Haptics.commit()
                        Task { await store.delete(live, scope: .futureEvents) }
                        dismiss()
                    }
                } else {
                    Button("Delete Event", role: .destructive) {
                        Haptics.commit()
                        Task { await store.delete(live, scope: .thisEvent) }
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: Components

    private var splitTimeCard: some View {
        HStack(spacing: CalSpacing.l) {
            // Duration & Date
            VStack(alignment: .leading, spacing: 4) {
                Text("Time")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(CalColor.secondaryText)
                
                HStack(alignment: .bottom, spacing: 2) {
                    Text(durationText(for: live))
                        .font(.system(size: 36, weight: .semibold, design: .default))
                        .foregroundStyle(CalColor.primaryText)
                    
                    Text("Minutes")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(CalColor.secondaryText)
                        .padding(.bottom, 6)
                }
                
                Text(live.start.formatted(.dateTime.month(.wide).day()))
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(CalColor.primaryText)
            }
            
            Spacer()
            
            // Divider
            Rectangle()
                .fill(CalColor.hairline)
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 4)
            
            Spacer()
            
            // Start & End Times
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start")
                        .font(.system(.caption2, design: .default))
                        .foregroundStyle(CalColor.secondaryText)
                    
                    Text(live.start.formatted(.dateTime.hour().minute()))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(CalColor.primaryText)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("End")
                        .font(.system(.caption2, design: .default))
                        .foregroundStyle(CalColor.secondaryText)
                    
                    Text(live.end.formatted(.dateTime.hour().minute()))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(CalColor.primaryText)
                }
            }
            .frame(width: 100, alignment: .leading)
        }
        .padding(CalSpacing.l)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var detailsSection: some View {
        VStack(spacing: CalSpacing.m) {
            // Location Card
            if let location = live.location, !location.isEmpty {
                DetailCard(symbol: "mappin.and.ellipse", title: "Location", content: location, color: live.color)
            }
            
            // Guests Card
            if !live.guests.isEmpty {
                VStack(alignment: .leading, spacing: CalSpacing.s) {
                    HStack {
                        Image(systemName: "person.2")
                            .foregroundStyle(live.color)
                        Text("Guests")
                            .font(CalFont.caption)
                            .foregroundStyle(CalColor.secondaryText)
                        Spacer()
                    }
                    
                    AvatarGroupView(names: live.guests, size: 28)
                        .padding(.leading, 2)
                    
                    Text(live.guests.joined(separator: ", "))
                        .font(CalFont.body)
                        .foregroundStyle(CalColor.primaryText)
                }
                .padding(CalSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            // Weather Forecast Card
            if let forecast = weather.forecast(on: live.start) {
                DetailCard(symbol: forecast.symbolName, title: "Weather Forecast",
                           content: "\(forecast.highText) high · \(forecast.lowText) low", color: .orange)
            }
            
            // Notes Card
            if let notes = live.notes, !notes.isEmpty {
                DetailCard(symbol: "text.alignleft", title: "Notes", content: notes, color: live.color)
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Label("Delete Event", systemImage: "trash")
                .font(CalFont.body)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CalSpacing.s)
        }
        .buttonStyle(.glass)
        .tint(.red)
        .padding(.top, CalSpacing.m)
    }

    // MARK: Helpers

    private func durationText(for event: CalendarEvent) -> String {
        let mins = Int(event.duration / 60)
        return "\(mins)"
    }

    private func meetingPlatform(for event: CalendarEvent) -> String {
        let loc = event.location?.lowercased() ?? ""
        let title = event.title.lowercased()
        if loc.contains("zoom") || title.contains("zoom") {
            return "Zoom Meeting"
        } else if loc.contains("meet.google") || loc.contains("google meet") || title.contains("google meet") {
            return "Google Meet"
        } else if loc.contains("teams") || title.contains("teams") {
            return "Microsoft Teams"
        } else if loc.contains("phone") || title.contains("call") {
            return "Phone Call"
        }
        return "In-person"
    }
}

/// A clean details card in the details scroll list
private struct DetailCard: View {
    let symbol: String
    let title: String
    let content: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: CalSpacing.s) {
            HStack(spacing: CalSpacing.s) {
                Image(systemName: symbol)
                    .foregroundStyle(color)
                Text(title)
                    .font(CalFont.caption)
                    .foregroundStyle(CalColor.secondaryText)
                Spacer()
            }
            Text(content)
                .font(CalFont.body)
                .foregroundStyle(CalColor.primaryText)
        }
        .padding(CalSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    EventDetailView(event: CalendarEvent(
        id: "preview", title: "Brainstorming session for a new product design",
        start: .now, end: .now.addingTimeInterval(1800),
        location: "Zoom Meeting", notes: "Review wireframes and sketch out some ideas.",
        guests: ["Sarah Jenkins", "Alex Rivera", "David Chen"],
        calendarID: "personal", calendarTitle: "Personal", palette: .indigo, source: .apple
    ))
    .environment(CalendarStore(provider: MockEventProvider()))
    .environment(WeatherStore())
}
