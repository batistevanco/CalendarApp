//
//  Surfaces.swift
//  CalenderApp
//
//  Reusable surface treatments. Two families:
//   • `glassCard`   — floating controls that adopt iOS 26 Liquid Glass.
//   • `surfaceCard` — quiet content cards that sit calmly on the canvas.
//

import SwiftUI

extension View {
    /// A floating Liquid Glass surface for controls that hover above content
    /// (the Now hero, the compose button, toolbars).
    func glassCard(cornerRadius: CGFloat = CalRadius.card) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    /// A quiet, grouped content card. Uses a thin material with a hairline
    /// stroke so it reads as a distinct surface without shouting.
    func surfaceCard(cornerRadius: CGFloat = CalRadius.card) -> some View {
        self
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(CalColor.hairline.opacity(0.6), lineWidth: 0.5)
            )
    }
}
