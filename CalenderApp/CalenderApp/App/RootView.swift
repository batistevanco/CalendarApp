//
//  RootView.swift
//  CalenderApp
//
//  The app's root. A native iOS 26 Liquid-Glass tab bar hosts the primary
//  views, all sharing one `CalendarStore`. Week and Month join here as they're
//  built, so this stays the single top-level composition point.
//

import SwiftUI

struct RootView: View {
    @Environment(Navigator.self) private var navigator
    @State private var composing = false

    var body: some View {
        @Bindable var navigator = navigator

        TabView(selection: $navigator.tab) {
            Tab("Today", systemImage: "sun.max.fill", value: AppTab.today) {
                TodayView()
            }
            Tab("Day", systemImage: "calendar.day.timeline.left", value: AppTab.day) {
                DayView()
            }
            Tab("Week", systemImage: "calendar.day.timeline.leading", value: AppTab.week) {
                WeekView()
            }
            Tab("Month", systemImage: "calendar", value: AppTab.month) {
                MonthView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            ComposeButton { composing = true }
                .padding(.trailing, CalSpacing.screen)
                .padding(.bottom, 96) // clear the floating tab bar
        }
        .sheet(isPresented: $composing) {
            EventEditor(mode: .create(EventDraft(day: navigator.focusedDay)))
        }
    }
}

private struct ComposeButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("Add Event")
                    .font(.system(.body, design: .default, weight: .bold))
                Image(systemName: "plus")
                    .font(.system(.subheadline, weight: .bold))
                    .padding(6)
                    .background(Color.white)
                    .clipShape(Circle())
                    .foregroundStyle(.black)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .background(Color.black)
            .clipShape(Capsule())
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .accessibilityLabel("New Event")
    }
}

#Preview {
    RootView()
        .environment(CalendarStore(provider: MockEventProvider()))
        .environment(Navigator())
        .environment(ThemeManager())
        .environment(NotificationManager())
        .environment(WeatherStore())
}
