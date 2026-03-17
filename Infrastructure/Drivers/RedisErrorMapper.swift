//
//  RedisErrorMapper.swift
//  cheap-connection
//
//  Redis错误映射器 - 将驱动层错误转换为应用错误
//

import Foundation
import NIOCore

/// Redis错误映射器
enum RedisErrorMapper {

    /// 将原始错误映射为AppError
    /// - Parameter error: 原始错误
    /// - Returns: 应用统一错误
    nonisolated static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        // NIO ChannelError 直接映射为连接/网络错误
        if error is ChannelError {
            return mapChannelError(error)
        }

        let combinedMessage = buildCombinedMessage(error)

        // 认证失败
        if isAuthenticationError(combinedMessage) {
            return .authenticationFailed("Redis 认证失败，请检查密码")
        }

        // 连接被拒绝
        if isConnectionRefusedError(combinedMessage) {
            return .connectionFailed("无法连接到 Redis 服务器，请检查地址和端口")
        }

        // 超时
        if isTimeoutError(combinedMessage) {
            return .timeout("连接超时，请检查网络或服务器状态")
        }

        // 网络错误
        if isNetworkError(combinedMessage) {
            return .networkError("网络连接异常")
        }

        // WRONGTYPE 操作
        if isWrongTypeError(combinedMessage) {
            return .queryError("key 类型不匹配，无法执行该操作")
        }

        // 语法错误
        if isSyntaxError(combinedMessage) {
            return .queryError("命令语法错误")
        }

        // 权限不足（Redis 6.0+ ACL）
        if isAccessDeniedError(combinedMessage) {
            return .authenticationFailed("权限不足，当前用户无权执行该命令")
        }

        // key 不存在（某些需要 key 存在的命令）
        if isKeyNotFoundError(combinedMessage) {
            return .queryError("key 不存在")
        }

        // 数据库索引越界
        if isDatabaseIndexError(combinedMessage) {
            return .queryError("数据库索引无效，有效范围为 0-15")
        }

        // 默认
        let sanitizedMessage = sanitizeFallbackMessage(error)
        return .internalError(sanitizedMessage)
    }

    // MARK: - Error Detection

    private nonisolated static func isAuthenticationError(_ message: String) -> Bool {
        return message.contains("auth") ||
               message.contains("noauth") ||
               message.contains("wrongpass") ||
               message.contains("invalid password") ||
               message.contains("authentication") ||
               message.contains("not allowed")
    }

    private nonisolated static func isConnectionRefusedError(_ message: String) -> Bool {
        return message.contains("connection refused") ||
               message.contains("connection reset") ||
               message.contains("could not connect") ||
               message.contains("no connection could be made") ||
               message.contains("econnrefused") ||
               message.contains("eof")
    }

    private nonisolated static func isTimeoutError(_ message: String) -> Bool {
        return message.contains("timeout") ||
               message.contains("timed out") ||
               message.contains("etimedout")
    }

    private nonisolated static func isNetworkError(_ message: String) -> Bool {
        return message.contains("network") ||
               message.contains("enetwork") ||
               message.contains("socket") ||
               message.contains("broken pipe")
    }

    private nonisolated static func isWrongTypeError(_ message: String) -> Bool {
        return message.contains("wrongtype") ||
               message.contains("wrong type") ||
               message.contains("operation against a key holding the wrong kind of value")
    }

    private nonisolated static func isSyntaxError(_ message: String) -> Bool {
        return message.contains("syntax") ||
               message.contains("wrong number of arguments") ||
               message.contains("invalid") && message.contains("argument") ||
               message.contains("unknown command")
    }

    private nonisolated static func isAccessDeniedError(_ message: String) -> Bool {
        return message.contains("noperm") ||
               message.contains("permission") ||
               message.contains("denied") ||
               message.contains("not allowed")
    }

    private nonisolated static func isKeyNotFoundError(_ message: String) -> Bool {
        return message.contains("no such key") ||
               message.contains("key doesn't exist")
    }

    private nonisolated static func isDatabaseIndexError(_ message: String) -> Bool {
        return message.contains("db index is out of range") ||
               message.contains("invalid db index")
    }

    private nonisolated static func mapChannelError(_ error: Error) -> AppError {
        if let channelError = error as? ChannelError {
            switch channelError {
            case .connectPending:
                return .connectionFailed("连接正在建立中，请稍后重试")
            case .connectTimeout:
                return .timeout("连接超时，请检查地址、端口或防火墙设置")
            case .ioOnClosedChannel, .alreadyClosed, .inputClosed, .outputClosed, .eof:
                return .connectionFailed("服务器关闭了连接，请检查 Redis 是否正在运行")
            case .writeHostUnreachable:
                return .networkError("目标主机不可达，请检查网络路由或服务器地址")
            case .writeMessageTooLarge:
                return .networkError("发送数据包过大，连接被拒绝")
            case .unknownLocalAddress:
                return .networkError("无法确定本地网络地址，请检查本机网络配置")
            default:
                return .internalError("连接通道状态异常，请重试")
            }
        }

        return .networkError("网络通道异常，请重试连接")
    }

    private nonisolated static func buildCombinedMessage(_ error: Error) -> String {
        let localized = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let described = String(describing: error).trimmingCharacters(in: .whitespacesAndNewlines)
        let reflected = String(reflecting: error).trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !localized.isEmpty {
            parts.append(localized)
        }
        if !described.isEmpty && described != localized {
            parts.append(described)
        }
        if !reflected.isEmpty && reflected != described && reflected != localized {
            parts.append(reflected)
        }

        return parts.joined(separator: " | ").lowercased()
    }

    private nonisolated static func sanitizeFallbackMessage(_ error: Error) -> String {
        let localized = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = localized.lowercased()

        // Swift/NIO 未提供本地化描述时的系统兜底文案
        if normalized.contains("the operation couldn") ||
            normalized.contains("the operation couldn't be completed") ||
            normalized.contains("(niocore.channelerror error 0)") {
            return "网络通道异常，请检查连接参数和网络后重试"
        }

        if !localized.isEmpty {
            return localized
        }

        return "发生未知内部错误，请重试"
    }
}
