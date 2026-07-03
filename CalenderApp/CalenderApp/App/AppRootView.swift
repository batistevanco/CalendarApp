//
//  AppRootView.swift
//  CalenderApp
//
//  The true entry point. Owns the app-wide state (store, navigator, theme),
//  applies the chosen accent and appearance, and gates first launch behind
//  onboarding. Everything below it shares one environment.
//

import SwiftUI

struct AppRootView: View {
    @State private var store = CalendarStore()
    @State private var navigator = Navigator()
    @State private var theme = ThemeManager()
    @State private var notifications = NotificationManager()
    @State private var liveActivity = LiveActivityController()
    @State private var weather = WeatherStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        Group {
            if hasOnboarded {
                RootView()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.smooth) { hasOnboarded = true }
                }
                .transition(.opacity)
            }
        }
        .tint(theme.accentColor)
        .preferredColorScheme(theme.appearance.colorScheme)
        .environment(store)
        .environment(navigator)
        .environment(theme)
        .environment(notifications)
        .environment(weather)
        .task(id: hasOnboarded) { await syncNotifications() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await syncNotifications() } }
        }
    }

    /// Refreshes reminders for the next week whenever the app opens or resumes.
    private func syncNotifications() async {
        guard hasOnboarded else { return }
        await notifications.refreshAuthorization()
        let today = Date().startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        await store.loadRange(from: today, to: end)
        await notifications.sync(events: store.upcomingEvents(withinDays: 7))

        // Feed the widgets and the Live Activity.
        WidgetBridge.publish(store.upcomingEvents(withinDays: 7))
        let todaysEvents = store.events(on: Date())
        liveActivity.update(
            current: todaysEvents.current(at: .now),
            next: todaysEvents.next(at: .now)
        )

        await weather.refresh()
    }
}
