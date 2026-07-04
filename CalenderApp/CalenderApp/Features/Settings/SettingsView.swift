//
//  SettingsView.swift
//  CalenderApp
//
//  Minimal settings. Calendar visibility (which flows through every view),
//  appearance (accent + light/dark), the connected accounts, and about.
//  A grouped list here is the native, expected shape — calm and familiar.
//

import SwiftUI

struct SettingsView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(ThemeManager.self) private var theme
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userDisplayName") private var userName = ""

    var body: some View {
        @Bindable var theme = theme

        NavigationStack {
            List {
                profileSection
                calendarsSection
                notificationsSection
                appearanceSection(theme: theme)
                googleSection
                accountsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await store.loadCalendarsIfNeeded() }
        }
    }

    // MARK: Profile

    private var profileSection: some View {
        Section {
            HStack(spacing: CalSpacing.m) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundStyle(CalColor.accent)
                TextField("Your name", text: $userName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }
        } header: {
            Text("Profile")
        } footer: {
            Text("Used to greet you on the Today screen.")
        }
    }

    // MARK: Calendars

    private var calendarsSection: some View {
        Section {
            ForEach(store.calendars) { calendar in
                Toggle(isOn: visibilityBinding(for: calendar)) {
                    HStack(spacing: CalSpacing.m) {
                        Circle().fill(calendar.color).frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(calendar.title)
                            if let account = calendar.accountName {
                                Text(account)
                                    .font(CalFont.caption)
                                    .foregroundStyle(CalColor.secondaryText)
                            }
                        }
                    }
                }
                .tint(CalColor.accent)
            }
        } header: {
            Text("Calendars")
        } footer: {
            Text("Hidden calendars are removed from every view and from search.")
        }
    }

    private func visibilityBinding(for calendar: EventCalendar) -> Binding<Bool> {
        Binding(
            get: { store.isVisible(calendar.id) },
            set: { store.setCalendar(calendar.id, visible: $0) }
        )
    }

    // MARK: Appearance

    private func appearanceSection(theme: ThemeManager) -> some View {
        Section("Appearance") {
            Picker("Theme", selection: Bindable(theme).appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: CalSpacing.m) {
                Text("Accent")
                    .foregroundStyle(CalColor.primaryText)
                AccentPicker(selection: Bindable(theme).accent)
            }
            .padding(.vertical, CalSpacing.xs)
        }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        @Bindable var notifications = notifications
        return Section {
            Toggle(isOn: $notifications.isEnabled) {
                Label("Event reminders", systemImage: "bell")
            }
            .tint(CalColor.accent)
            .onChange(of: notifications.isEnabled) { _, enabled in
                Task {
                    if enabled { await notifications.requestAuthorization() }
                    await resyncNotifications()
                }
            }

            if notifications.isEnabled {
                Picker(selection: $notifications.leadMinutes) {
                    ForEach(NotificationManager.leadOptions, id: \.self) { minutes in
                        Text(leadLabel(minutes)).tag(minutes)
                    }
                } label: {
                    Label("Remind me", systemImage: "clock")
                }
                .onChange(of: notifications.leadMinutes) { _, _ in
                    Task { await resyncNotifications() }
                }

                Toggle(isOn: $notifications.travelEnabled) {
                    Label("Travel-time reminders", systemImage: "car")
                }
                .tint(CalColor.accent)
                .onChange(of: notifications.travelEnabled) { _, _ in
                    Task { await resyncNotifications() }
                }

                if !notifications.isAuthorized {
                    Text("Turn on notifications for CalendarApp in iOS Settings to receive reminders.")
                        .font(CalFont.caption)
                        .foregroundStyle(CalColor.secondaryText)
                }
            }
        } header: {
            Text("Notifications")
        }
    }

    private func leadLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0:  return String(localized: "At start time")
        case 60: return String(localized: "1 hour before")
        default: return String(localized: "\(minutes) min before")
        }
    }

    private func resyncNotifications() async {
        await notifications.refreshAuthorization()
        await notifications.sync(events: store.upcomingEvents(withinDays: 7))
    }

    // MARK: Google

    @State private var connectingGoogle = false

    private var googleSection: some View {
        Section {
            ForEach(store.googleAuth.accounts) { account in
                Label {
                    Text(account.email)
                } icon: {
                    Image(systemName: "g.circle.fill").foregroundStyle(CalColor.accent)
                }
                .swipeActions {
                    Button("Disconnect", role: .destructive) {
                        Task { await store.disconnectGoogle(account) }
                    }
                }
            }

            if GoogleConfig.isConfigured {
                Button {
                    connectingGoogle = true
                    Task {
                        try? await store.connectGoogle()
                        connectingGoogle = false
                    }
                } label: {
                    Label("Add Google Account", systemImage: "plus.circle")
                }
                .disabled(connectingGoogle)
            } else {
                Text("Add your Google OAuth client id in GoogleConfig.swift to enable Google Calendar.")
                    .font(CalFont.caption)
                    .foregroundStyle(CalColor.secondaryText)
            }
        } header: {
            Text("Google Calendar")
        }
    }

    // MARK: Accounts

    private var accountsSection: some View {
        Section("Accounts") {
            if accounts.isEmpty {
                Text("No accounts connected")
                    .foregroundStyle(CalColor.secondaryText)
            } else {
                ForEach(accounts, id: \.name) { account in
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(account.name)
                            Text(account.source.displayName)
                                .font(CalFont.caption)
                                .foregroundStyle(CalColor.secondaryText)
                        }
                    } icon: {
                        Image(systemName: account.source.symbolName)
                            .foregroundStyle(CalColor.accent)
                    }
                }
            }
        }
    }

    /// Distinct accounts derived from the connected calendars.
    private var accounts: [(name: String, source: EventSource)] {
        var seen = Set<String>()
        var result: [(name: String, source: EventSource)] = []
        for calendar in store.calendars {
            let name = calendar.accountName ?? calendar.source.displayName
            if seen.insert(name).inserted {
                result.append((name, calendar.source))
            }
        }
        return result
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Made by", value: "Vancoillie Studio")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// A row of accent swatches; the selected one gets a ring.
private struct AccentPicker: View {
    @Binding var selection: CalPalette

    private let columns = [GridItem(.adaptive(minimum: 40), spacing: CalSpacing.m)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: CalSpacing.m) {
            ForEach(CalPalette.allCases, id: \.self) { palette in
                Circle()
                    .fill(palette.color)
                    .frame(width: 32, height: 32)
                    .overlay {
                        if palette == selection {
                            Circle().strokeBorder(.primary.opacity(0.9), lineWidth: 2)
                                .padding(-4)
                        }
                    }
                    .contentShape(Circle())
                    .onTapGesture {
                        Haptics.tick()
                        withAnimation(.smooth) { selection = palette }
                    }
                    .accessibilityLabel(palette.rawValue.capitalized)
            }
        }
    }
}
