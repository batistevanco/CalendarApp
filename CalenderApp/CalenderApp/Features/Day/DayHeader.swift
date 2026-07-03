//
//  DayHeader.swift
//  CalenderApp
//
//  The Day View's title bar: a large, calm date with a quick "Today" return
//  when you've navigated away.
//

import SwiftUI

struct DayHeader: View {
    let day: Date
    var onToday: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.wide)))
                    .font(CalFont.greeting)
                    .foregroundStyle(day.isToday ? CalColor.accent : CalColor.primaryText)

                Text(day.formatted(.dateTime.day().month(.wide).year()))
                    .font(CalFont.subheadline)
                    .foregroundStyle(CalColor.secondaryText)
            }

            Spacer()

            if !day.isToday {
                Button(action: onToday) {
                    Text("Today")
                        .font(CalFont.caption)
                        .padding(.horizontal, CalSpacing.m)
                        .padding(.vertical, CalSpacing.s)
                }
                .buttonStyle(.glass)
                .tint(CalColor.accent)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, CalSpacing.screen)
        .padding(.top, CalSpacing.s)
        .padding(.bottom, CalSpacing.m)
        .animation(.smooth, value: day)
    }
}
