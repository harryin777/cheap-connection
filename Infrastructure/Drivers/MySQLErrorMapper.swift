//
//  MySQLErrorMapper.swift
//  cheap-connection
//
//  MySQL错误映射器 - 将驱动层错误转换为应用错误
//

import Foundation

/// MySQL错误映射器
enum MySQLErrorMapper {

    /// 将原始错误映射为AppError
    /// - Parameter error: 原始错误
    /// - Returns: 应用统一错误
    static func map(_ error: Error) -> AppError {
        let errorDescription = error.localizedDescription

        // 认证失败
        if isAuthenticationError(errorDescription) {
            return .authenticationFailed("用户名或密码错误")
        }

        // 连接被拒绝
        if isConnectionRefusedError(errorDescription) {
            return .connectionFailed("无法连接到服务器，请检查地址和端口")
        }

        // 超时
        if isTimeoutError(errorDescription) {
            return .timeout("连接超时，请检查网络或服务器状态")
        }

        // 网络错误
        if isNetworkError(errorDescription) {
            return .networkError("网络连接异常")
        }

        // 数据库不存在
        if isDatabaseNotFoundError(errorDescription) {
            return .queryError("数据库不存在")
        }

        // 表不存在
        if isTableNotFoundError(errorDescription) {
            return .queryError("表不存在")
        }

        // 语法错误
        if isSyntaxError(errorDescription) {
            return .queryError("SQL语法错误")
        }

        // 权限不足
        if isAccessDeniedError(errorDescription) {
            return .authenticationFailed("权限不足")
        }

        // 默认：内部错误
        return .internalError(errorDescription)
    }

    // MARK: - Error Detection

    private static func isAuthenticationError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("access denied for user") ||
               lowercased.contains("authentication") ||
               lowercased.contains("password") && lowercased.contains("denied") ||
               lowercased.contains("using password: yes")
    }

    private static func isConnectionRefusedError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("connection refused") ||
               lowercased.contains("connection reset") ||
               lowercased.contains("could not connect") ||
               lowercased.contains("no connection could be made") ||
               lowercased.contains("econnrefused")
    }

    private static func isTimeoutError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("timeout") ||
               lowercased.contains("timed out") ||
               lowercased.contains("etimedout")
    }

    private static func isNetworkError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("network") ||
               lowercased.contains("enetwork") ||
               lowercased.contains("socket") ||
               lowercased.contains("broken pipe")
    }

    private static func isDatabaseNotFoundError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("unknown database") ||
               lowercased.contains("database") && lowercased.contains("doesn't exist")
    }

    private static func isTableNotFoundError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("doesn't exist") && lowercased.contains("table") ||
               lowercased.contains("unknown table")
    }

    private static func isSyntaxError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("syntax") ||
               lowercased.contains("sql error") ||
               lowercased.contains("near") && lowercased.contains("at line")
    }

    private static func isAccessDeniedError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("access denied") && !lowercased.contains("password") ||
               lowercased.contains("command denied") ||
               lowercased.contains("privilege")
    }
}
