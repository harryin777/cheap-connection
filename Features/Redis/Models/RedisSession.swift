//
//  RedisSession.swift
//  cheap-connection
//
//  Redis运行时会话状态
//

import Foundation

/// Redis会话状态
/// 管理单个Redis连接的运行时状态
@MainActor
@Observable
final class RedisSession {
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

    /// 当前选中的数据库索引
    var selectedDatabase: Int = 0

    /// 当前选中的 key
    var selectedKey: String?

    /// 当前扫描的 key 列表
    var keyList: [RedisKeySummary] = []

    /// 当前扫描游标（0 表示扫描结束）
    var scanCursor: Int = 0

    /// 是否还有更多 key 可以加载
    var hasMoreKeys: Bool = false

    /// 当前搜索模式
    var searchPattern: String?

    // MARK: - Server Info

    /// 服务器版本信息
    var serverVersion: String?

    /// 服务器运行模式（standalone/cluster/sentinel）
    var serverMode: String?

    /// 已用内存
    var usedMemory: String?

    /// 连接的客户端数
    var connectedClients: Int?

    // MARK: - Command State

    /// 当前命令执行结果
    var currentResult: RedisCommandResult?

    /// 是否正在加载
    var isLoading: Bool = false

    /// 最近错误信息
    var recentError: String?

    /// 命令历史
    var commandHistory: [String] = []

    // MARK: - Initialization

    init(connectionConfigId: UUID) {
        self.connectionConfigId = connectionConfigId
    }

    // MARK: - State Management

    /// 重置会话状态
    func reset() {
        connectionState = .disconnected
        selectedDatabase = 0
        selectedKey = nil
        keyList = []
        scanCursor = 0
        hasMoreKeys = false
        searchPattern = nil
        serverVersion = nil
        serverMode = nil
        usedMemory = nil
        connectedClients = nil
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
    func setConnected(version: String? = nil, mode: String? = nil) {
        connectionState = .connected
        serverVersion = version
        serverMode = mode
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
        selectedDatabase = 0
        selectedKey = nil
        keyList = []
        scanCursor = 0
        hasMoreKeys = false
        serverVersion = nil
        serverMode = nil
        isLoading = false
    }

    /// 清除错误
    func clearError() {
        recentError = nil
        if case .error = connectionState {
            connectionState = .disconnected
        }
    }

    /// 选择数据库
    func selectDatabase(_ index: Int) {
        selectedDatabase = index
        selectedKey = nil
        keyList = []
        scanCursor = 0
        hasMoreKeys = false
    }

    /// 选择 key
    func selectKey(_ key: String?) {
        selectedKey = key
    }

    /// 添加命令到历史
    func addToHistory(_ command: String) {
        // 避免重复
        if commandHistory.first == command {
            return
        }
        commandHistory.insert(command, at: 0)
        // 限制历史长度
        if commandHistory.count > 100 {
            commandHistory.removeLast()
        }
    }

    /// 更新 key 列表
    func updateKeyList(_ keys: [RedisKeySummary], cursor: Int, append: Bool = false) {
        if append {
            keyList.append(contentsOf: keys)
        } else {
            keyList = keys
        }
        scanCursor = cursor
        hasMoreKeys = cursor != 0
    }

    /// 清空 key 列表
    func clearKeyList() {
        keyList = []
        scanCursor = 0
        hasMoreKeys = false
    }
}
