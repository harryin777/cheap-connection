//
//  AppError.swift
//  cheap-connection
//
//  应用错误类型定义
//

import Foundation

/// 应用统一错误类型
enum AppError: Error, Equatable, LocalizedError {
    case connectionFailed(String)
    case authenticationFailed(String)
    case timeout(String)
    case networkError(String)
    case queryError(String)
    case decodingError(String)
    case unsupportedOperation(String)
    case internalError(String)

    var errorDescription: String? {
        localizedDescription
    }

    var localizedDescription: String {
        switch self {
        case .connectionFailed(let msg):
            return "连接失败: \(msg)"
        case .authenticationFailed(let msg):
            return "认证失败: \(msg)"
        case .timeout(let msg):
            return "操作超时: \(msg)"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        case .queryError(let msg):
            return "查询错误: \(msg)"
        case .decodingError(let msg):
            return "数据解析错误: \(msg)"
        case .unsupportedOperation(let msg):
            return "不支持的操作: \(msg)"
        case .internalError(let msg):
            return "内部错误: \(msg)"
        }
    }

    /// 用于日志的错误类别
    var category: String {
        switch self {
        case .connectionFailed:
            return "CONNECTION"
        case .authenticationFailed:
            return "AUTH"
        case .timeout:
            return "TIMEOUT"
        case .networkError:
            return "NETWORK"
        case .queryError:
            return "QUERY"
        case .decodingError:
            return "DECODING"
        case .unsupportedOperation:
            return "UNSUPPORTED"
        case .internalError:
            return "INTERNAL"
        }
    }

    /// 是否可重试
    var isRetryable: Bool {
        switch self {
        case .connectionFailed, .timeout, .networkError:
            return true
        case .authenticationFailed, .queryError, .decodingError,
             .unsupportedOperation, .internalError:
            return false
        }
    }
}
