//
//  MySQLService.swift
//  cheap-connection
//
//  MySQL服务层 - 管理MySQL连接和查询操作
//

import Foundation

/// MySQL服务协议
protocol MySQLServiceProtocol: Sendable {
    /// 当前会话状态
    var session: MySQLSession { get }

    /// 连接到MySQL服务器
    /// - Parameters:
    ///   - config: 连接配置
    ///   - password: 密码
    func connect(config: ConnectionConfig, password: String) async throws

    /// 断开连接
    func disconnect() async

    /// 获取数据库列表
    func fetchDatabases() async throws -> [MySQLDatabaseSummary]

    /// 获取表列表
    /// - Parameter database: 数据库名
    func fetchTables(database: String) async throws -> [MySQLTableSummary]

    /// 获取表结构
    /// - Parameters:
    ///   - database: 数据库名
    ///   - table: 表名
    func fetchTableStructure(database: String, table: String) async throws -> [MySQLColumnDefinition]

    /// 获取表数据（分页）
    /// - Parameters:
    ///   - database: 数据库名
    ///   - table: 表名
    ///   - pagination: 分页状态
    ///   - orderBy: 排序列
    ///   - orderDirection: 排序方向
    func fetchTableData(
        database: String,
        table: String,
        pagination: PaginationState,
        orderBy: String?,
        orderDirection: OrderDirection
    ) async throws -> MySQLQueryResult

    /// 执行SQL查询
    /// - Parameter sql: SQL语句
    func executeSQL(_ sql: String) async throws -> MySQLQueryResult
}

/// MySQL服务
/// 封装MySQLClient，高级操作，供UI层使用
@MainActor
@Observable
final class MySQLService: MySQLServiceProtocol {
    // MARK: - Dependencies

    private(set) var client: MySQLClientProtocol
    private(set) var session: MySQLSession

    private var connectionConfig: ConnectionConfig?

    // MARK: - Initialization

    init(connectionConfig: ConnectionConfig) {
        self.connectionConfig = connectionConfig
        self.client = MySQLClient()
        self.session = MySQLSession(connectionConfigId: connectionConfig.id)
    }

    // MARK: - MySQLServiceProtocol

    func connect(config: ConnectionConfig, password: String) async throws {
        session.setConnecting()

        do {
            let mysqlConfig = MySQLConnectionConfig(from: config, password: password)
            try await client.connect(config: mysqlConfig)

            // 获取服务器信息
            let serverInfo = try await fetchServerInfo()

            session.setConnected(
                version: serverInfo.version,
                charset: serverInfo.charset
            )
        } catch {
            session.setError(error.localizedDescription)
            throw error
        }
    }

    func disconnect() async {
        await client.disconnect()
        session.setDisconnected()
    }

    func fetchDatabases() async throws -> [MySQLDatabaseSummary] {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let databases = try await client.fetchDatabases()
        return databases
    }

    func fetchTables(database: String) async throws -> [MySQLTableSummary] {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let tables = try await client.fetchTables(database: database)
        return tables
    }

    func fetchTableStructure(database: String, table: String) async throws -> [MySQLColumnDefinition] {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let columns = try await client.fetchTableStructure(database: database, table: table)
        return columns
    }

    func fetchTableData(
        database: String,
        table: String,
        pagination: PaginationState,
        orderBy: String?,
        orderDirection: OrderDirection
    ) async throws -> MySQLQueryResult {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let result = try await client.fetchTableData(
            database: database,
            table: table,
            pagination: pagination,
            orderBy: orderBy,
            orderDirection: orderDirection
        )

        session.currentResult = result
        return result
    }

    func executeSQL(_ sql: String) async throws -> MySQLQueryResult {
        guard session.connectionState.isConnected else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        session.isLoading = true
        defer { session.isLoading = false }

        let result = try await client.executeQuery(sql: sql)
        session.currentResult = result
        return result
    }

    // MARK: - Private Methods

    private func fetchServerInfo() async throws -> (version: String?, charset: String?) {
        guard session.connectionState.isConnected else { return (nil, nil) }

        do {
            let result = try await client.executeQuery(sql: "SELECT VERSION() as version, @@version_comment as charset")
            if let row = result.rows.first {
                let version = row.count > 0 ? row[0].displayValue : nil
                let charset = row.count > 1 ? row[1].displayValue : nil
                return (version: version, charset: charset)
            }
            return (nil, nil)
        } catch {
            // 如果查询失败，尝试简单版本查询
            do {
                let result = try await client.executeQuery(sql: "SHOW VARIABLES LIKE 'version%'")
                if let row = result.rows.first {
                    return (version: row.count > 0 ? row[0].displayValue : nil, charset: nil)
                }
                return (nil, nil)
            } catch {
                return (nil, nil)
            }
        }
    }
}
