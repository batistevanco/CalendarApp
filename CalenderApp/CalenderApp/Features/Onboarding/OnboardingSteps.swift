//
//  OnboardingSteps.swift
//  CalenderApp
//
//  The individual onboarding stages. Each is a calm, centred composition with
//  a single idea and generous whitespace.
//

import SwiftUI

// MARK: - Welcome

struct WelcomeStep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("userDisplayName") private var userName = ""
    @FocusState private var nameFocused: Bool
    @State private var appeared = false

    var body: some View {
        VStack(spacing: CalSpacing.xl) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(CalColor.accent.gradient)
                    .frame(width: 132, height: 132)
                    .shadow(color: CalColor.accent.opacity(0.4), radius: 24, y: 10)
                    .rotationEffect(.degrees(appeared ? 0 : -8))
                    .scaleEffect(appeared ? 1 : 0.6)

                Image(systemName: "calendar")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: appeared)
            }

            VStack(spacing: CalSpacing.s) {
                Text("CalendarApp")
                    .font(CalFont.greeting)
                    .foregroundStyle(CalColor.primaryText)
                Text("A calm, beautiful home for the calendars you already have.")
                    .font(CalFont.body)
                    .foregroundStyle(CalColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            // A gentle, optional first-name prompt so the app can greet by name.
            VStack(spacing: CalSpacing.xs) {
                TextField("Your name", text: $userName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .multilineTextAlignment(.center)
                    .font(CalFont.headline)
                    .padding(.vertical, CalSpacing.m)
                    .padding(.horizontal, CalSpacing.l)
                    .background(CalColor.surface, in: .rect(cornerRadius: CalRadius.card))
                    .onSubmit { nameFocused = false }

                Text("We'll use this to greet you. You can change it later.")
                    .font(CalFont.caption)
                    .foregroundStyle(CalColor.tertiaryText)
            }
            .opacity(appeared ? 1 : 0)
            .frame(maxWidth: 320)

            Spacer()
        }
        .contentShape(.rect)
        .onTapGesture { nameFocused = false }
        .onAppear {
            if reduceMotion { appeared = true }
            else { withAnimation(.smooth(duration: 0.7)) { appeared = true } }
        }
    }
}

// MARK: - Choose calendars

struct ChooseCalendarsStep: View {
    var body: some View {
        VStack(spacing: CalSpacing.xl) {
            StepHeading(
                title: "Connect your calendars",
                subtitle: "CalendarApp never owns your data — it's a beautiful lens over the calendars you already keep."
            )

            VStack(spacing: CalSpacing.m) {
                ProviderCard(source: .apple, status: .connected)
                ProviderCard(source: .google, status: .comingSoon)
            }

            Spacer()
        }
    }
}

private enum ProviderStatus {
    case connected, comingSoon
}

private struct ProviderCard: View {
    let source: EventSource
    let status: ProviderStatus

    var body: some View {
        HStack(spacing: CalSpacing.l) {
            Image(systemName: source.symbolName)
                .font(.title2)
                .foregroundStyle(status == .connected ? CalColor.accent : CalColor.secondaryText)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .font(CalFont.headline)
                    .foregroundStyle(CalColor.primaryText)
                Text(status == .connected ? "Ready to connect" : "Coming soon")
                    .font(CalFont.caption)
                    .foregroundStyle(CalColor.secondaryText)
            }

            Spacer()

            Image(systemName: status == .connected ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(status == .connected ? CalColor.accent : CalColor.tertiaryText)
        }
        .padding(CalSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
        .opacity(status == .connected ? 1 : 0.6)
    }
}

// MARK: - Permission

struct PermissionStep: View {
    @Environment(CalendarStore.self) private var store
    @State private var requesting = false

    var body: some View {
        VStack(spacing: CalSpacing.xl) {
            StepHeading(
                title: "Your calendars, beautifully",
                subtitle: "Grant access so your events can appear here. Everything stays on your device — nothing is uploaded."
            )

            VStack(spacing: CalSpacing.m) {
                ReasonRow(symbol: "eye", text: "See your schedule at a glance")
                ReasonRow(symbol: "square.and.pencil", text: "Create and edit events in place")
                ReasonRow(symbol: "lock", text: "Private — read directly from your device")
            }

            statusOrButton

            Spacer()
        }
    }

    @ViewBuilder
    private var statusOrButton: some View {
        switch store.access {
        case .authorized:
            Label("Access granted", systemImage: "checkmark.circle.fill")
                .font(CalFont.headline)
                .foregroundStyle(CalColor.accent)
        case .denied:
            Text("You can enable calendar access later in Settings.")
                .font(CalFont.subheadline)
                .foregroundStyle(CalColor.secondaryText)
                .multilineTextAlignment(.center)
        case .notDetermined:
            Button {
                requesting = true
                Task {
                    await store.requestAccess()
                    requesting = false
                }
            } label: {
                Text("Allow Calendar Access")
                    .font(CalFont.headline)
                    .padding(.horizontal, CalSpacing.xl)
                    .padding(.vertical, CalSpacing.m)
            }
            .buttonStyle(.glass)
            .tint(CalColor.accent)
            .disabled(requesting)
        }
    }
}

private struct ReasonRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: CalSpacing.l) {
            Image(systemName: symbol)
                .foregroundStyle(CalColor.accent)
                .frame(width: 26)
            Text(text)
                .font(CalFont.body)
                .foregroundStyle(CalColor.primaryText)
            Spacer()
        }
        .padding(.horizontal, CalSpacing.s)
    }
}

// MARK: - Done

struct DoneStep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: CalSpacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96, weight: .semibold))
                .foregroundStyle(CalColor.accent)
                .symbolEffect(.bounce, value: appeared)
                .scaleEffect(appeared ? 1 : 0.5)

            VStack(spacing: CalSpacing.s) {
                Text("You're all set")
                    .font(CalFont.greeting)
                    .foregroundStyle(CalColor.primaryText)
                Text("Your day is waiting.")
                    .font(CalFont.body)
                    .foregroundStyle(CalColor.secondaryText)
            }
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .onAppear {
            if reduceMotion { appeared = true }
            else { withAnimation(.smooth(duration: 0.6)) { appeared = true } }
        }
    }
}

// MARK: - Shared heading

private struct StepHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: CalSpacing.s) {
            Text(title)
                .font(CalFont.title)
                .foregroundStyle(CalColor.primaryText)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(CalFont.body)
                .foregroundStyle(CalColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, CalSpacing.xxl)
        .padding(.horizontal, CalSpacing.s)
    }
}
