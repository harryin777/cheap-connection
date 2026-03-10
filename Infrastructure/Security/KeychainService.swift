//
//  KeychainService.swift
//  cheap-connection
//
//  Keychain 服务 - 安全存储密码
//

import Foundation
import Security

/// Keychain 服务协议 - 便于测试时 mock
protocol KeychainServiceProtocol: Sendable {
    /// 保存密码
    func savePassword(_ password: String, for connectionId: UUID) throws
    /// 获取密码
    func getPassword(for connectionId: UUID) throws -> String?
    /// 删除密码
    func deletePassword(for connectionId: UUID) throws
}

/// Keychain 服务实现
final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    nonisolated(unsafe) static let shared = KeychainService()

    /// 服务标识符
    private let service = "com.yzz.cheap-connection"

    private init() {}

    // MARK: - KeychainServiceProtocol

    func savePassword(_ password: String, for connectionId: UUID) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let account = connectionId.uuidString

        // 先尝试删除已存在的条目
        try? deletePassword(for: connectionId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func getPassword(for connectionId: UUID) throws -> String? {
        let account = connectionId.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.readFailed(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }

        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return password
    }

    func deletePassword(for connectionId: UUID) throws {
        let account = connectionId.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
