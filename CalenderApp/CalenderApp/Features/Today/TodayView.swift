//
//  TodayView.swift
//  CalenderApp
//
//  Redesigned to a premium modern dashboard layout matching the screenshots.
//  Includes a greeting header, weather details, search filtering, and upcoming task card layouts,
//  with the ability to switch between the Agenda List and the Day Timeline view.
//

import SwiftUI

struct TodayView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(WeatherStore.self) private var weather
    @State private var selected: CalendarEvent?
    @State private var showingSettings = false
    @State private var isAgendaView = true
    @State private var searchQuery = ""
    @State private var didInitialScroll = false

    /// Captured once per appearance; Today doesn't cross midnight in-session.
    private let day = Date().startOfDay

    private var events: [CalendarEvent] { store.events(on: day) }

    private var filteredEvents: [CalendarEvent] {
        let all = events
        guard !searchQuery.isEmpty else { return all }
        let q = searchQuery.lowercased()
        return all.filter {
            $0.title.lowercased().contains(q) ||
            ($0.location?.lowercased().contains(q) ?? false) ||
            ($0.notes?.lowercased().contains(q) ?? false) ||
            $0.guests.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.isAccessDenied {
                    CalendarAccessView()
                        .background(CalColor.canvas)
                        .task { await store.loadIfNeeded(day) }
                } else {
                    mainContent
                }
            }
            .sheet(item: $selected) { EventDetailView(event: $0) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    private var mainContent: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: CalSpacing.xl) {
                    // Header Bar (Welcome message + Avatar)
                    headerBar
                    
                    // View Toggle (Today vs Calendar)
                    viewToggle
                    
                    // Date Header
                    dateHeader
                    
                    // Weather Card (Fills when weather store has data)
                    weatherCard
                    
                    // Search Bar
                    searchBar
                    
                    if isAgendaView {
                        // Agenda List View
                        agendaListView
                    } else {
                        // Classic Hour-by-hour Timeline View
                        DayTimelineView(
                            day: day,
                            events: events.timed,
                            onSelect: { selected = $0 }
                        )
                    }
                }
                .padding(.horizontal, CalSpacing.screen)
                .padding(.vertical, CalSpacing.l)
            }
            .scrollIndicators(.hidden)
            .background(CalColor.canvas)
            .refreshable { await store.refresh(day) }
            .task {
                await store.loadIfNeeded(day)
                guard !didInitialScroll else { return }
                didInitialScroll = true
                withAnimation(.smooth) {
                    scroll.scrollTo(DayTimelineView.nowAnchorID, anchor: .center)
                }
            }
        }
    }

    // MARK: Components

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal")
                        .font(.body)
                        .foregroundStyle(CalColor.primaryText)
                        .onTapGesture { showingSettings = true }
                    
                    Text("Welcome back,")
                        .font(.system(.body, design: .default))
                        .foregroundStyle(CalColor.secondaryText)
                    
                    Text("Jaydon")
                        .font(.system(.body, design: .default, weight: .bold))
                        .foregroundStyle(CalColor.primaryText)
                }
            }
            
            Spacer()
            
            // Profile image with a nice border
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundStyle(CalColor.accent.gradient)
                .background(Circle().fill(Color(.systemGray6)))
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        }
    }

    private var viewToggle: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.smooth) { isAgendaView = true }
            } label: {
                Text("Today")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(isAgendaView ? Color.white : CalColor.primaryText)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background {
                        if isAgendaView {
                            Capsule().fill(Color.black)
                        } else {
                            Capsule().stroke(CalColor.hairline, lineWidth: 1)
                        }
                    }
            }

            Button {
                withAnimation(.smooth) { isAgendaView = false }
            } label: {
                Text("Calendar")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(!isAgendaView ? Color.white : CalColor.primaryText)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background {
                        if !isAgendaView {
                            Capsule().fill(Color.black)
                        } else {
                            Capsule().stroke(CalColor.hairline, lineWidth: 1)
                        }
                    }
            }
            Spacer()
        }
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.formatted(.dateTime.month(.wide).day().year()))
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundStyle(CalColor.primaryText)
            
            Text(day.formatted(.dateTime.weekday(.wide)))
                .font(.system(size: 24, weight: .medium, design: .default))
                .foregroundStyle(CalColor.secondaryText)
        }
    }

    private var weatherCard: some View {
        HStack(spacing: CalSpacing.l) {
            // Temperature & City
            VStack(alignment: .leading, spacing: 4) {
                Text("Weather")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(CalColor.secondaryText)
                
                HStack(alignment: .top, spacing: 0) {
                    let temp = weather.now?.temperatureText.replacingOccurrences(of: "°", with: "") ?? "21"
                    Text(temp)
                        .font(.system(size: 42, weight: .semibold, design: .default))
                        .foregroundStyle(CalColor.primaryText)
                    
                    Text(" ºC")
                        .font(.system(.body, design: .default, weight: .medium))
                        .foregroundStyle(CalColor.primaryText)
                        .padding(.top, 6)
                }
                
                Text(weather.cityName)
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
            
            // Sunrise & Sunset
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sunrise")
                        .font(.system(.caption2, design: .default))
                        .foregroundStyle(CalColor.secondaryText)
                    
                    Text(weather.sunriseText)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(CalColor.primaryText)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sunset")
                        .font(.system(.caption2, design: .default))
                        .foregroundStyle(CalColor.secondaryText)
                    
                    Text(weather.sunsetText)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(CalColor.primaryText)
                }
            }
            .frame(width: 80, alignment: .leading)
        }
        .padding(CalSpacing.l)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var searchBar: some View {
        HStack(spacing: CalSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CalColor.secondaryText)
            
            TextField("Search meeting, task etc...", text: $searchQuery)
                .font(CalFont.body)
                .submitLabel(.done)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, CalSpacing.m)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var agendaListView: some View {
        VStack(alignment: .leading, spacing: CalSpacing.m) {
            Text("Upcoming Task")
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundStyle(CalColor.primaryText)
                .padding(.bottom, 2)
            
            if filteredEvents.isEmpty {
                VStack(spacing: CalSpacing.s) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(CalColor.accent)
                    Text("No upcoming events")
                        .font(CalFont.headline)
                        .foregroundStyle(CalColor.primaryText)
                    Text("You have a completely clear schedule.")
                        .font(CalFont.caption)
                        .foregroundStyle(CalColor.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else {
                ForEach(filteredEvents) { event in
                    agendaRow(for: event)
                        .onTapGesture { selected = event }
                }
            }
        }
    }

    private func agendaRow(for event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: CalSpacing.m) {
            HStack {
                Text(meetingPlatform(for: event))
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(event.color)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(event.color.opacity(0.12))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Guest Avatars
                if !event.guests.isEmpty {
                    AvatarGroupView(names: event.guests, size: 24)
                }
            }
            
            Text(event.title)
                .font(.system(.title3, design: .default, weight: .bold))
                .foregroundStyle(CalColor.primaryText)
                .lineLimit(2)
            
            HStack(alignment: .bottom) {
                // Duration
                VStack(alignment: .leading, spacing: 2) {
                    Text(durationText(for: event))
                        .font(.system(size: 26, weight: .light, design: .default))
                        .foregroundStyle(CalColor.primaryText)
                    
                    Text("Minutes")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(CalColor.secondaryText)
                }
                
                Spacer()
                
                // Times
                HStack(spacing: CalSpacing.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start")
                            .font(.system(.caption2, design: .default))
                            .foregroundStyle(CalColor.secondaryText)
                        
                        Text(event.start.formatted(.dateTime.hour().minute()))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(CalColor.primaryText)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("End")
                            .font(.system(.caption2, design: .default))
                            .foregroundStyle(CalColor.secondaryText)
                        
                        Text(event.end.formatted(.dateTime.hour().minute()))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(CalColor.primaryText)
                    }
                }
            }
        }
        .padding(CalSpacing.l)
        .background(event.color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

#Preview {
    TodayView()
        .environment(CalendarStore(provider: MockEventProvider()))
        .environment(Navigator())
        .environment(WeatherStore())
}
