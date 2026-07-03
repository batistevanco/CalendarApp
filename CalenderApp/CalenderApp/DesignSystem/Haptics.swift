//
//  Haptics.swift
//  CalenderApp
//
//  A tiny wrapper over the system feedback generators. UIKit is used here
//  because imperative haptics during continuous gestures (pick-up, per-step
//  ticks, commit) have no first-class SwiftUI equivalent — this is the
//  "absolutely necessary" exception to our SwiftUI-only rule.
//

import UIKit

/// Semantic haptics tuned for the timeline's direct-manipulation gestures.
enum Haptics {
    /// The moment an event is "lifted" for dragging.
    static func pickup() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// A light tick as a drag snaps to the next time increment.
    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A crisp confirmation when a change is committed.
    static func commit() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
}
