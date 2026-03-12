//
//  MySQLErrorMapper.swift
//  cheap-connection
//
//  MySQL错误映射器 - 将驱动层错误转换为应用错误
//

import Foundation
import NIOCore

/// MySQL错误映射器
enum MySQLErrorMapper {

    /// 将原始错误映射为AppError
    /// - Parameter error: 原始错误
    /// - Returns: 应用统一错误
    nonisolated static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        // NIO ChannelError 直接映射为连接/网络错误，避免显示系统兜底 NSError 文案
        if error is ChannelError {
            return mapChannelError(error)
        }

        let combinedMessage = buildCombinedMessage(error)

        // 认证失败
        if isAuthenticationError(combinedMessage) {
            return .authenticationFailed("用户名或密码错误")
        }

        // 连接被拒绝
        if isConnectionRefusedError(combinedMessage) {
            return .connectionFailed("无法连接到服务器，请检查地址和端口")
        }

        // 超时
        if isTimeoutError(combinedMessage) {
            return .timeout("连接超时，请检查网络或服务器状态")
        }

        // 网络错误
        if isNetworkError(combinedMessage) {
            return .networkError("网络连接异常")
        }

        // 未选择数据库
        if isNoDatabaseSelectedError(combinedMessage) {
            return .queryError("未选择数据库，请先从左侧选择一个数据库")
        }

        // 数据库不存在
        if isDatabaseNotFoundError(combinedMessage) {
            return .queryError("数据库不存在")
        }

        // 表不存在
        if isTableNotFoundError(combinedMessage) {
            return .queryError("表不存在")
        }

        // 语法错误
        if isSyntaxError(combinedMessage) {
            return .queryError("SQL语法错误")
        }

        // 权限不足
        if isAccessDeniedError(combinedMessage) {
            return .authenticationFailed("权限不足")
        }

        // 默认：避免直接透出系统 "The operation couldn’t be completed..." 文案
        let sanitizedMessage = sanitizeFallbackMessage(error)
        return .internalError(sanitizedMessage)
    }

    // MARK: - Error Detection

    private nonisolated static func isNoDatabaseSelectedError(_ message: String) -> Bool {
        return message.contains("no database selected") ||
               message.contains("database not selected") ||
               message.contains("1046")  // MySQL error code for No database selected
    }

    private nonisolated static func mapChannelError(_ error: Error) -> AppError {
        if let channelError = error as? ChannelError {
            switch channelError {
            case .connectPending:
                return .connectionFailed("连接正在建立中，请稍后重试")
            case .connectTimeout:
                return .timeout("连接超时，请检查地址、端口或安全组设置")
            case .ioOnClosedChannel, .alreadyClosed, .inputClosed, .outputClosed, .eof:
                return .connectionFailed("服务器在握手阶段关闭连接，请检查用户名、密码、SSL 和默认数据库设置")
            case .writeHostUnreachable:
                return .networkError("目标主机不可达，请检查网络路由或服务器地址")
            case .writeMessageTooLarge:
                return .networkError("发送数据包过大，连接被拒绝")
            case .unknownLocalAddress:
                return .networkError("无法确定本地网络地址，请检查本机网络配置")
            case .operationUnsupported,
                 .badMulticastGroupAddressFamily,
                 .badInterfaceAddressFamily,
                 .illegalMulticastAddress,
                 .inappropriateOperationForState,
                 .unremovableHandler:
                return .internalError("连接通道状态异常，请重试")
            #if !os(WASI)
            case .multicastNotSupported:
                return .internalError("当前网络接口不支持该通道操作")
            #endif
            }
        }

        let message = buildCombinedMessage(error)
        if message.contains("connectpending") {
            return .connectionFailed("连接正在建立中，请稍后重试")
        }
        if message.contains("connecttimeout") {
            return .timeout("连接超时，请检查地址、端口或安全组设置")
        }
        if message.contains("ioonclosedchannel") ||
            message.contains("alreadyclosed") ||
            message.contains("inputclosed") ||
            message.contains("outputclosed") ||
            message.contains("eof") {
            return .connectionFailed("服务器在握手阶段关闭连接，请检查用户名、密码、SSL 和默认数据库设置")
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

        // Swift/NIO 未提供本地化描述时，NSError 桥接会生成该类系统兜底文案
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

    private nonisolated static func isAuthenticationError(_ message: String) -> Bool {
        return message.contains("access denied for user") ||
               message.contains("authentication") ||
               message.contains("password") && message.contains("denied") ||
               message.contains("using password: yes")
    }

    private nonisolated static func isConnectionRefusedError(_ message: String) -> Bool {
        return message.contains("connection refused") ||
               message.contains("connection reset") ||
               message.contains("could not connect") ||
               message.contains("no connection could be made") ||
               message.contains("econnrefused")
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

    private nonisolated static func isDatabaseNotFoundError(_ message: String) -> Bool {
        return message.contains("unknown database") ||
               message.contains("database") && message.contains("doesn't exist")
    }

    private nonisolated static func isTableNotFoundError(_ message: String) -> Bool {
        // MySQL 错误格式: "Table 'db.table' doesn't exist"
        return message.contains("doesn't exist") ||
               message.contains("unknown table")
    }

    private nonisolated static func isSyntaxError(_ message: String) -> Bool {
        return message.contains("syntax") ||
               message.contains("sql error") ||
               message.contains("near") && message.contains("at line")
    }

    private nonisolated static func isAccessDeniedError(_ message: String) -> Bool {
        return message.contains("access denied") && !message.contains("password") ||
               message.contains("command denied") ||
               message.contains("privilege")
    }
}
