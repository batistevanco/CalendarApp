//
//  GoogleAuthService.swift
//  CalenderApp
//
//  OAuth 2.0 for installed apps, using only Apple frameworks:
//  ASWebAuthenticationSession for the consent flow (PKCE, no client secret) and
//  URLSession for the token exchange/refresh. Tokens live in the Keychain;
//  account metadata is observable so Settings updates live.
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
@Observable
final class GoogleAuthService: NSObject {
    /// Connected accounts (metadata only; tokens are in the Keychain).
    private(set) var accounts: [GoogleAccount] = []

    private let accountsKey = "google.accounts"
    private var currentSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        accounts = KeychainStore.value([GoogleAccount].self, for: accountsKey) ?? []
    }

    var isConfigured: Bool { GoogleConfig.isConfigured }

    // MARK: Sign in

    /// Runs the consent flow and stores the resulting account + tokens.
    @discardableResult
    func signIn() async throws -> GoogleAccount {
        guard GoogleConfig.isConfigured else { throw GoogleError.notConfigured }

        let verifier = Self.randomURLSafe(count: 64)
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomURLSafe(count: 16)
        let authURL = buildAuthURL(challenge: challenge, state: state)

        let callback = try await presentConsent(url: authURL)
        guard let code = queryItem("code", in: callback) else { throw GoogleError.authFailed }

        let response = try await exchangeCode(code, verifier: verifier)
        let account = try Self.account(fromIDToken: response.idToken)
        let tokens = GoogleTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? "",
            expiry: Date().addingTimeInterval(response.expiresIn)
        )

        KeychainStore.setValue(tokens, for: tokenKey(account.id))
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
            KeychainStore.setValue(accounts, for: accountsKey)
        }
        return account
    }

    func signOut(_ account: GoogleAccount) {
        accounts.removeAll { $0.id == account.id }
        KeychainStore.setValue(accounts, for: accountsKey)
        KeychainStore.delete(for: tokenKey(account.id))
    }

    /// A valid access token for `account`, refreshing if it has expired.
    func validAccessToken(for account: GoogleAccount) async throws -> String {
        guard var tokens = KeychainStore.value(GoogleTokens.self, for: tokenKey(account.id)) else {
            throw GoogleError.noRefreshToken
        }
        guard tokens.isExpired else { return tokens.accessToken }
        guard !tokens.refreshToken.isEmpty else { throw GoogleError.noRefreshToken }

        let refreshed = try await refresh(tokens.refreshToken)
        tokens.accessToken = refreshed.accessToken
        tokens.expiry = Date().addingTimeInterval(refreshed.expiresIn)
        KeychainStore.setValue(tokens, for: tokenKey(account.id))
        return tokens.accessToken
    }

    // MARK: URL building

    private func tokenKey(_ id: String) -> String { "tokens.\(id)" }

    private func buildAuthURL(challenge: String, state: String) -> URL {
        var components = URLComponents(url: GoogleConfig.authEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client_id", value: GoogleConfig.clientID),
            .init(name: "redirect_uri", value: GoogleConfig.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: GoogleConfig.scopes.joined(separator: " ")),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
        ]
        return components.url!
    }

    private func queryItem(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == name }?.value
    }

    // MARK: Consent presentation

    private func presentConsent(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: GoogleConfig.callbackScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? GoogleError.authFailed)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            currentSession = session
            session.start()
        }
    }

    // MARK: Token endpoints

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: TimeInterval
        let idToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case idToken = "id_token"
        }
    }

    private func exchangeCode(_ code: String, verifier: String) async throws -> TokenResponse {
        try await postToken([
            "code": code,
            "client_id": GoogleConfig.clientID,
            "redirect_uri": GoogleConfig.redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ])
    }

    private func refresh(_ refreshToken: String) async throws -> TokenResponse {
        try await postToken([
            "client_id": GoogleConfig.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ])
    }

    private func postToken(_ fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: GoogleConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { "\($0.key)=\(Self.formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw GoogleError.decoding
        }
        return decoded
    }

    // MARK: PKCE + JWT helpers

    private static func randomURLSafe(count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncoded()
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// Extracts identity (`sub`, `email`, `name`) from the id_token JWT payload.
    private static func account(fromIDToken idToken: String?) throws -> GoogleAccount {
        guard let idToken else { throw GoogleError.authFailed }
        let segments = idToken.split(separator: ".")
        guard segments.count >= 2,
              let payload = Data(base64URLEncoded: String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let sub = json["sub"] as? String,
              let email = json["email"] as? String
        else { throw GoogleError.decoding }
        return GoogleAccount(id: sub, email: email, name: json["name"] as? String)
    }
}

// MARK: - Presentation anchor

extension GoogleAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            if let window = scene?.keyWindow { return window }
            if let scene { return UIWindow(windowScene: scene) }
            // Unreachable: an app presenting web auth always has a window scene.
            preconditionFailure("No UIWindowScene available for web authentication.")
        }
    }
}

// MARK: - Base64URL

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        self.init(base64Encoded: s)
    }
}
