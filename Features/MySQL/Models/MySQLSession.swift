//
//  MySQLSession.swift
//  cheap-connection
//
//  MySQL运行时会话状态
//

import Foundation

/// MySQL会话状态
/// 管理单个MySQL连接的运行时状态
@MainActor
@Observable
final class MySQLSession {
    // MARK: - Connection State

    /// 关联的连接配置ID
    let connectionConfigId: UUID

    /// 连接状态
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)

        var isDisconnected: Bool {
            if case .disconnected = self { return true }
            return false
        }

        var isConnecting: Bool {
            if case .connecting = self { return true }
            return false
        }

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    /// 当前连接状态
    var connectionState: ConnectionState = .disconnected

    // MARK: - Database Navigation State

    /// 当前选中的数据库
    var selectedDatabase: String?

    /// 当前选中的表
    var selectedTable: String?

    /// 展开的数据库列表
    var expandedDatabases: Set<String> = []

    // MARK: - Server Info

    /// 服务器版本信息
    var serverVersion: String?

    /// 服务器字符集
    var serverCharset: String?

    // MARK: - Query State

    /// 当前查询结果
    var currentResult: MySQLQueryResult?

    /// 是否正在加载
    var isLoading: Bool = false

    /// 最近错误信息
    var recentError: String?

    // MARK: - Initialization

    init(connectionConfigId: UUID) {
        self.connectionConfigId = connectionConfigId
    }

    // MARK: - State Management

    /// 重置会话状态
    func reset() {
        connectionState = .disconnected
        selectedDatabase = nil
        selectedTable = nil
        expandedDatabases = []
        serverVersion = nil
        serverCharset = nil
        currentResult = nil
        isLoading = false
        recentError = nil
    }

    /// 设置连接中状态
    func setConnecting() {
        connectionState = .connecting
        isLoading = true
        recentError = nil
    }

    /// 设置连接成功状态
    func setConnected(version: String? = nil, charset: String? = nil) {
        connectionState = .connected
        serverVersion = version
        serverCharset = charset
        isLoading = false
        recentError = nil
    }

    /// 设置连接错误状态
    func setError(_ message: String) {
        connectionState = .error(message)
        isLoading = false
        recentError = message
    }

    /// 设置断开连接状态
    func setDisconnected() {
        connectionState = .disconnected
        selectedDatabase = nil
        selectedTable = nil
        serverVersion = nil
        serverCharset = nil
        isLoading = false
    }

    /// 清除错误
    func clearError() {
        recentError = nil
        if case .error = connectionState {
            connectionState = .disconnected
        }
    }

    /// 展开或收起数据库
    func toggleDatabaseExpansion(_ database: String) {
        if expandedDatabases.contains(database) {
            expandedDatabases.remove(database)
        } else {
            expandedDatabases.insert(database)
        }
    }

    /// 选择数据库
    func selectDatabase(_ database: String?) {
        selectedDatabase = database
        selectedTable = nil
    }

    /// 选择表
    func selectTable(_ table: String?) {
        selectedTable = table
    }
}
