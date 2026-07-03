//
//  Navigator.swift
//  CalenderApp
//
//  Lightweight top-level navigation state shared across tabs. It lets Month and
//  Week hand a day off to the Day view and switch tabs in one gesture, keeping
//  the "tap a day → open that day" flow seamless.
//

import SwiftUI
import Observation

/// The app's primary destinations.
enum AppTab: Hashable {
    case today, day, week, month, search
}

@MainActor
@Observable
final class Navigator {
    /// The selected tab.
    var tab: AppTab = .today
    /// The day the Day view is focused on. Also the target for cross-tab jumps.
    var focusedDay: Date = Date().startOfDay

    /// Focus a day and reveal it in the Day view.
    func openDay(_ day: Date) {
        focusedDay = day.startOfDay
        withAnimation(.smooth) { tab = .day }
    }
}
