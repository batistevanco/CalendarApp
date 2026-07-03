//
//  OnboardingView.swift
//  CalenderApp
//
//  A calm, four-step welcome in the spirit of a first-party Apple app:
//  welcome → choose calendars → why we need access (and request it) → done.
//  Content cross-fades between steps; a quiet progress row tracks position.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onFinished: () -> Void

    @State private var step: OnboardingStep = .welcome

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(stepTransition)
                .id(step)

            footer
        }
        .padding(CalSpacing.xl)
        .background(CalColor.canvas)
        .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: step)
    }

    /// Slides between steps normally; a gentle cross-fade when Reduce Motion is on.
    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:    WelcomeStep()
        case .calendars:  ChooseCalendarsStep()
        case .permission: PermissionStep()
        case .done:       DoneStep()
        }
    }

    // MARK: Footer (progress + primary action)

    private var footer: some View {
        VStack(spacing: CalSpacing.l) {
            ProgressDots(count: OnboardingStep.allCases.count, index: step.index)

            Button(action: advance) {
                Text(step.actionTitle)
                    .font(CalFont.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CalSpacing.m)
            }
            .buttonStyle(.glassProminent)
            .tint(CalColor.accent)
        }
    }

    private func advance() {
        switch step {
        case .welcome:    step = .calendars
        case .calendars:  step = .permission
        case .permission: step = .done
        case .done:       onFinished()
        }
    }
}

/// The four onboarding stages.
enum OnboardingStep: Int, CaseIterable {
    case welcome, calendars, permission, done

    var index: Int { rawValue }

    var actionTitle: String {
        switch self {
        case .welcome:    return String(localized: "Get Started")
        case .calendars:  return String(localized: "Continue")
        case .permission: return String(localized: "Continue")
        case .done:       return String(localized: "Open CalendarApp")
        }
    }
}

/// A row of dots showing progress through onboarding.
private struct ProgressDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: CalSpacing.s) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? CalColor.accent : CalColor.hairline)
                    .frame(width: i == index ? 22 : 7, height: 7)
                    .animation(.smooth, value: index)
            }
        }
    }
}
