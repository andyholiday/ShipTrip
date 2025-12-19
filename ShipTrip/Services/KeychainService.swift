//
//  KeychainService.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import Foundation
import Security

/// Service für sichere Speicherung von Secrets in der Keychain
enum KeychainService {
    
    private static let service = "com.shiptrip.app"
    
    enum Key: String {
        case geminiApiKey = "gemini_api_key"
    }
    
    // MARK: - Save
    
    /// Speichert einen String-Wert sicher in der Keychain
    @discardableResult
    static func save(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Erst löschen falls vorhanden
        delete(key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Read
    
    /// Liest einen String-Wert aus der Keychain
    static func read(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    // MARK: - Delete
    
    /// Löscht einen Wert aus der Keychain
    @discardableResult
    static func delete(_ key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Exists
    
    /// Prüft ob ein Schlüssel in der Keychain existiert
    static func exists(_ key: Key) -> Bool {
        read(key) != nil
    }
}
