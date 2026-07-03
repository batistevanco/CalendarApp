//
//  LocationProvider.swift
//  CalenderApp
//
//  A tiny one-shot location helper built on the modern async
//  `CLLocationUpdate.liveUpdates()` sequence, which requests When-In-Use
//  authorisation for us. Used only to anchor the weather forecast.
//

import Foundation
import CoreLocation

nonisolated enum LocationProvider {
    /// Returns the first fix, or `nil` if denied/unavailable. Never throws to the
    /// caller — weather is a nicety, not a requirement.
    static func current() async -> CLLocation? {
        do {
            for try await update in CLLocationUpdate.liveUpdates(.default) {
                if let location = update.location { return location }
                if update.authorizationDenied || update.authorizationDeniedGlobally {
                    return nil
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
