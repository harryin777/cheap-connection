//
//  RedisService.swift
//  cheap-connection
//
//  Redis服务层 - 管理Redis连接和操作
//

import Foundation

/// Redis服务协议
protocol RedisServiceProtocol: Sendable {
    /// 当前会话状态
    var session: RedisSession { get }

    /// 连接到Redis服务器
    /// - Parameters:
    ///   - config: 连接配置
    ///   - password: 密码（可选）
    func connect(config: ConnectionConfig, password: String?) async throws

    /// 断开连接
    func disconnect() async

    /// 扫描 key（增量式）
    func scanKeys(match: String?, count: Int?, cursor: Int, append: Bool) async throws -> RedisScanResult

    /// 搜索 key
    func searchKeys(pattern: String) async throws -> [String]

    /// 获取 key 详情
    func getKeyDetail(_ key: String) async throws -> RedisKeyDetail

    /// 删除 key
    func deleteKey(_ key: String) async throws -> Bool

    /// 获取 String 值
    func getString(_ key: String) async throws -> String?

    /// 获取 Hash 值
    func getHash(_ key: String) async throws -> [String: String]

    /// 获取 List 值
    func getList(_ key: String, start: Int, stop: Int) async throws -> [String]

    /// 获取 Set 值
    func getSet(_ key: String) async throws -> [String]

    /// 获取 ZSet 值
    func getZSet(_ key: String, start: Int, stop: Int, withScores: Bool) async throws -> [RedisZSetMember]

    /// 执行原始命令
    func executeCommand(_ commandString: String) async throws -> RedisCommandResult

    /// 切换数据库
    func selectDatabase(_ index: Int) async throws
}

/// Redis服务
/// 封装RedisClient，提供高级操作，供UI层使用
@MainActor
@Observable
final class RedisService: RedisServiceProtocol {
    // MARK: - Dependencies

    private(set) var client: RedisClientProtocol
    private(set) var session: RedisSession

    private var connectionConfig: ConnectionConfig?

    // MARK: - Initialization

    init(connectionConfig: ConnectionConfig) {
        self.connectionConfig = connectionConfig
        self.client = RedisClient()
        self.session = RedisSession(connectionConfigId: connectionConfig.id)
    }

    // MARK: - RedisServiceProtocol

    func connect(config: ConnectionConfig, password: String?) async throws {
        session.setConnecting()

        do {
            let redisConfig = RedisConnectionConfig(from: config, password: password)
            try await client.connect(config: redisConfig)

            // 获取服务器信息
            let serverInfo = try await fetchServerInfo()

            session.setConnected(
                version: serverInfo.version,
                mode: serverInfo.mode
            )

            // 设置当前数据库
            session.selectedDatabase = redisConfig.database ?? 0
        } catch {
            session.setError(error.localizedDescription)
            throw error
        }
    }

    func disconnect() async {
        await client.disconnect()
        session.setDisconnected()
    }

    func scanKeys(match: String?, count: Int?, cursor: Int, append: Bool) async throws -> RedisScanResult {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let result = try await client.scanKeys(match: match, count: count, cursor: cursor)

        // 转换为 KeySummary
        let summaries = result.keys.map { key in
            RedisKeySummary(key: key, type: .unknown)
        }

        session.updateKeyList(summaries, cursor: result.nextCursor, append: append)

        return result
    }

    func searchKeys(pattern: String) async throws -> [String] {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let keys = try await client.searchKeys(pattern: pattern)
        return keys
    }

    func getKeyDetail(_ key: String) async throws -> RedisKeyDetail {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let detail = try await client.getKeyDetail(key)
        return detail
    }

    func deleteKey(_ key: String) async throws -> Bool {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let deleted = try await client.deleteKey(key)

        // 从列表中移除
        if deleted {
            session.keyList.removeAll { $0.key == key }
        }

        return deleted
    }

    func getString(_ key: String) async throws -> String? {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        return try await client.getString(key)
    }

    func getHash(_ key: String) async throws -> [String: String] {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        return try await client.getHash(key)
    }

    func getList(_ key: String, start: Int, stop: Int) async throws -> [String] {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        return try await client.getList(key, start: start, stop: stop)
    }

    func getSet(_ key: String) async throws -> [String] {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        return try await client.getSet(key)
    }

    func getZSet(_ key: String, start: Int, stop: Int, withScores: Bool) async throws -> [RedisZSetMember] {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        return try await client.getZSet(key, start: start, stop: stop, withScores: withScores)
    }

    func executeCommand(_ commandString: String) async throws -> RedisCommandResult {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let result = try await client.executeCommandString(commandString)

        // 添加到历史
        session.addToHistory(commandString)
        session.currentResult = result

        return result
    }

    func selectDatabase(_ index: Int) async throws {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        try await client.selectDatabase(index)
        session.selectDatabase(index)
    }

    /// 检查连接状态
    func checkConnection() async -> Bool {
        await client.checkConnected()
    }

    /// Ping 服务器
    func ping() async throws -> TimeInterval {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        return try await client.ping()
    }

    // MARK: - Private Methods

    private func fetchServerInfo() async throws -> (version: String?, mode: String?) {
        guard session.connectionState.isConnected else { return (nil, nil) }

        do {
            let info = try await client.getServerInfo(section: "server")

            let version = info["redis_version"]
            let mode = info["redis_mode"]

            // 更新内存信息
            let memoryInfo = try? await client.getServerInfo(section: "memory")
            session.usedMemory = memoryInfo?["used_memory_human"]

            // 更新客户端信息
            let clientsInfo = try? await client.getServerInfo(section: "clients")
            session.connectedClients = clientsInfo?["connected_clients"].flatMap { Int($0) }

            return (version: version, mode: mode)
        } catch {
            return (nil, nil)
        }
    }
}
