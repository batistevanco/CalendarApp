//
//  GoogleAccount.swift
//  CalenderApp
//
//  Value types for a connected Google account and its OAuth tokens.
//

import Foundation

/// A connected Google account. Identified by the OAuth subject id; the email is
/// shown in the UI.
nonisolated struct GoogleAccount: Codable, Identifiable, Hashable, Sendable {
    let id: String        // OAuth `sub`
    let email: String
    var name: String?
}

/// OAuth tokens for one account. Stored in the Keychain, never in plain prefs.
nonisolated struct GoogleTokens: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiry: Date

    /// A minute of slack so we refresh slightly early.
    var isExpired: Bool { Date() >= expiry.addingTimeInterval(-60) }
}

/// Errors surfaced by the Google integration.
nonisolated enum GoogleError: LocalizedError {
    case notConfigured
    case authFailed
    case noRefreshToken
    case http(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Google isn't configured yet."
        case .authFailed:    return "Google sign-in was cancelled or failed."
        case .noRefreshToken: return "Please sign in to Google again."
        case .http(let code): return "Google request failed (\(code))."
        case .decoding:      return "Couldn't read Google's response."
        }
    }
}
