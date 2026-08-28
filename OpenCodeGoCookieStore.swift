import Foundation
import Security

enum OpenCodeGoCookieStore {
    private static let service = "io.github.zhanglaojiu.codexquotamenu"
    static let primaryAccount = "opencode.go.manual"
    static let secondaryAccount = "opencode.go.manual.2"

    static func loadManualCookie() -> String? {
        load(account: primaryAccount)
    }

    static func saveManualCookie(_ header: String) -> Bool {
        save(header, account: primaryAccount)
    }

    static func clearManualCookie() {
        delete(account: primaryAccount)
    }

    static func loadManualCookie(account: String) -> String? {
        load(account: account)
    }

    static func saveManualCookie(_ header: String, account: String) -> Bool {
        save(header, account: account)
    }

    static func clearManualCookie(account: String) {
        delete(account: account)
    }

    static func clearAll() {
        clearManualCookie(account: primaryAccount)
        clearManualCookie(account: secondaryAccount)
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func save(_ header: String, account: String) -> Bool {
        guard let data = header.data(using: .utf8) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
