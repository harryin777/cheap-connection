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
    /// 服务标识符
    private let service = "com.yzz.cheap-connection"

    private init() {}

    static let shared = KeychainService()

    // MARK: - 诊断日志辅助

    private func logKeychainContext() {
        let metadata = [
            "service": service,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "nil",
            "executablePath": Bundle.main.executablePath ?? "nil"
        ]
        let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        appLogDebug("Keychain 上下文信息 | \(metaStr)", category: .storage)
    }

    private func osStatusDescription(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "errSecSuccess"
        case errSecItemNotFound:
            return "errSecItemNotFound"
        case errSecMissingEntitlement:
            return "errSecMissingEntitlement"
        case errSecAuthFailed:
            return "errSecAuthFailed"
        case errSecDuplicateItem:
            return "errSecDuplicateItem"
        case errSecNoSuchKeychain:
            return "errSecNoSuchKeychain"
        case errSecInvalidKeychain:
            return "errSecInvalidKeychain"
        default:
            return "OSStatus(\(status))"
        }
    }

    private func logDebug(_ message: String, metadata: [String: String] = [:]) {
        let metaStr = metadata.isEmpty ? "" : " | " + metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        appLogDebug("\(message)\(metaStr)", category: .storage)
    }

    private func logWarning(_ message: String, metadata: [String: String] = [:]) {
        let metaStr = metadata.isEmpty ? "" : " | " + metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        appLogWarning("\(message)\(metaStr)", category: .storage)
    }

    private func logError(_ message: String, metadata: [String: String] = [:]) {
        let metaStr = metadata.isEmpty ? "" : " | " + metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        appLogError("\(message)\(metaStr)", category: .storage)
    }

    // MARK: - KeychainServiceProtocol

    func savePassword(_ password: String, for connectionId: UUID) throws {
        logKeychainContext()

        guard let passwordData = password.data(using: .utf8) else {
            logError("Keychain savePassword: 无效数据", metadata: ["connectionId": connectionId.uuidString])
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
            logError("Keychain savePassword 失败", metadata: [
                "connectionId": account,
                "osStatus": osStatusDescription(status),
                "osStatusValue": "\(status)"
            ])
            throw KeychainError.saveFailed(status)
        }

        logDebug("Keychain savePassword 成功", metadata: ["connectionId": account])
    }

    func getPassword(for connectionId: UUID) throws -> String? {
        let account = connectionId.uuidString

        logKeychainContext()
        logDebug("Keychain getPassword 开始查询", metadata: [
            "connectionId": account,
            "service": service
        ])

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
                logWarning("Keychain getPassword: 未找到密码条目", metadata: [
                    "connectionId": account,
                    "osStatus": osStatusDescription(status)
                ])
                return nil
            }
            logError("Keychain getPassword 失败", metadata: [
                "connectionId": account,
                "osStatus": osStatusDescription(status),
                "osStatusValue": "\(status)"
            ])
            throw KeychainError.readFailed(status)
        }

        guard let data = result as? Data else {
            logError("Keychain getPassword: 数据类型异常", metadata: ["connectionId": account])
            throw KeychainError.unexpectedData
        }

        guard let password = String(data: data, encoding: .utf8) else {
            logError("Keychain getPassword: 数据解码失败", metadata: ["connectionId": account])
            throw KeychainError.invalidData
        }

        logDebug("Keychain getPassword 成功", metadata: ["connectionId": account])
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
            logError("Keychain deletePassword 失败", metadata: [
                "connectionId": account,
                "osStatus": osStatusDescription(status),
                "osStatusValue": "\(status)"
            ])
            throw KeychainError.deleteFailed(status)
        }

        logDebug("Keychain deletePassword 完成", metadata: [
            "connectionId": account,
            "osStatus": osStatusDescription(status)
        ])
    }
}
