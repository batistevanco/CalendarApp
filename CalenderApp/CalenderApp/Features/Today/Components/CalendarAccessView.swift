//
//  CalendarAccessView.swift
//  CalenderApp
//
//  A calm, on-brand prompt shown when calendar access is unavailable. No alarm,
//  no clutter — just a clear reason and a single path to Settings.
//

import SwiftUI
import UIKit   // For the Settings deep-link constant only.

struct CalendarAccessView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: CalSpacing.l) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(CalColor.accent)

            VStack(spacing: CalSpacing.s) {
                Text("Calendar access is off")
                    .font(CalFont.title)
                    .foregroundStyle(CalColor.primaryText)

                Text("CalendarApp only shows the calendars you already have. Turn access on to see your day.")
                    .font(CalFont.body)
                    .foregroundStyle(CalColor.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(CalFont.headline)
                    .padding(.horizontal, CalSpacing.xl)
                    .padding(.vertical, CalSpacing.m)
            }
            .buttonStyle(.glass)
            .tint(CalColor.accent)
        }
        .padding(CalSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    CalendarAccessView()
}
