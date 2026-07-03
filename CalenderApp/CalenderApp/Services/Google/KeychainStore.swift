//
//  KeychainStore.swift
//  CalenderApp
//
//  A tiny Keychain wrapper for securely storing OAuth tokens. Only the few
//  operations we need — get/set/delete a Data blob for a string key.
//

import Foundation
import Security

enum KeychainStore {
    private static let service = "be.vancoilliestudio.CalenderApp.google"

    static func set(_ data: Data, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func data(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: Codable convenience

    static func setValue<T: Encodable>(_ value: T, for key: String) {
        if let data = try? JSONEncoder().encode(value) {
            set(data, for: key)
        }
    }

    static func value<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = data(for: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
