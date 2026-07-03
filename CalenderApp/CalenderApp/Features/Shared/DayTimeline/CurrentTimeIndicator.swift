//
//  CurrentTimeIndicator.swift
//  CalenderApp
//
//  The live "now" line that sweeps down the timeline. A soft knob in the gutter
//  and a hairline across the day, tinted with the accent colour.
//

import SwiftUI

struct CurrentTimeIndicator: View {
    /// Width of the hour-label gutter, so the knob aligns with the labels.
    var gutterWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(CalColor.accent)
                    .frame(width: 9, height: 9)
                Circle()
                    .stroke(CalColor.accent.opacity(0.25), lineWidth: 5)
                    .frame(width: 9, height: 9)
            }
            .frame(width: gutterWidth, alignment: .trailing)
            .padding(.trailing, -4)

            Rectangle()
                .fill(CalColor.accent)
                .frame(height: 1.5)
        }
        .shadow(color: CalColor.accent.opacity(0.4), radius: 4, y: 0)
    }
}
