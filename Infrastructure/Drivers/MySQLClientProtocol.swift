//
//  MySQLClientProtocol.swift
//  cheap-connection
//
//  MySQL客户端协议 - 驱动层抽象接口
//

import Foundation

/// MySQL客户端协议
/// 所有MySQL驱动实现都必须遵循此协议
protocol MySQLClientProtocol: Sendable {
    /// 检查是否已连接
    func checkConnected() async -> Bool

    /// 连接到MySQL服务器
    /// - Parameter config: MySQL连接配置
    func connect(config: MySQLConnectionConfig) async throws

    /// 断开连接
    func disconnect() async

    /// Ping服务器
    /// - Returns: 是否响应成功
    func ping() async throws -> Bool

    /// 获取数据库列表
    /// - Returns: 数据库摘要列表
    func fetchDatabases() async throws -> [MySQLDatabaseSummary]

    /// 获取表列表
    /// - Parameter database: 数据库名
    /// - Returns: 表摘要列表
    func fetchTables(database: String) async throws -> [MySQLTableSummary]

    /// 获取表结构
    /// - Parameters:
    ///   - database: 数据库名
    ///   - table: 表名
    /// - Returns: 列定义列表
    func fetchTableStructure(database: String, table: String) async throws -> [MySQLColumnDefinition]

    /// 获取表数据（分页）
    /// - Parameters:
    ///   - database: 数据库名
    ///   - table: 表名
    ///   - pagination: 分页状态
    ///   - orderBy: 排序列（可选）
    ///   - orderDirection: 排序方向
    /// - Returns: 查询结果
    func fetchTableData(
        database: String,
        table: String,
        pagination: PaginationState,
        orderBy: String?,
        orderDirection: OrderDirection
    ) async throws -> MySQLQueryResult

    /// 执行SQL查询
    /// - Parameter sql: SQL语句
    /// - Returns: 查询结果
    func executeQuery(sql: String) async throws -> MySQLQueryResult
}
