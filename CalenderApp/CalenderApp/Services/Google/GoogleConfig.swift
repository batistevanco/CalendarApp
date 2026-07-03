//
//  GoogleConfig.swift
//  CalenderApp
//
//  Configuration for the Google Calendar integration. We use Google's OAuth
//  flow for *installed apps* (PKCE, no client secret) via
//  ASWebAuthenticationSession, and the Calendar REST API via URLSession — so
//  there are no third-party SDK dependencies.
//
//  SETUP (one-time, by the developer):
//   1. In Google Cloud Console, create an OAuth client of type "iOS".
//   2. Copy its Client ID into `clientID` below.
//   3. The redirect scheme is the reversed client id (Google provides it as the
//      "iOS URL scheme"); `callbackScheme` derives it automatically.
//   No Info.plist URL type is required — ASWebAuthenticationSession intercepts
//   the callback scheme directly.
//

import Foundation

nonisolated enum GoogleConfig {
    /// Your OAuth 2.0 iOS client id, e.g. "1234567890-abcxyz.apps.googleusercontent.com".
    /// Replace before shipping; `isConfigured` guards the UI until you do.
    static let clientID = "YOUR_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com"

    /// Read/write access to the user's calendars.
    static let scopes = ["https://www.googleapis.com/auth/calendar"]

    static let authEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let apiBase = URL(string: "https://www.googleapis.com/calendar/v3")!

    /// Whether a real client id has been supplied.
    static var isConfigured: Bool { !clientID.hasPrefix("YOUR_GOOGLE") }

    /// The reversed-client-id scheme Google expects for iOS OAuth callbacks.
    static var callbackScheme: String {
        // "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
        let base = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(base)"
    }

    /// Full redirect URI used in the auth + token requests.
    static var redirectURI: String { "\(callbackScheme):/oauth2redirect" }
}
