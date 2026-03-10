//
//  KeychainError.swift
//  cheap-connection
//
//  Keychain 操作错误类型
//

import Foundation
import Security

/// Keychain 操作错误
enum KeychainError: Error, LocalizedError, Equatable {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    case invalidData
    case unexpectedData

    var errorDescription: String? {
        localizedDescription
    }

    var localizedDescription: String {
        switch self {
        case .saveFailed(let status):
            return "保存密码失败 (错误码: \(status))"
        case .readFailed(let status):
            return "读取密码失败 (错误码: \(status))"
        case .deleteFailed(let status):
            return "删除密码失败 (错误码: \(status))"
        case .itemNotFound:
            return "未找到保存的密码"
        case .invalidData:
            return "密码数据无效"
        case .unexpectedData:
            return "密码数据格式异常"
        }
    }

    /// 用于日志的错误类别
    var category: String {
        "KEYCHAIN"
    }
}
