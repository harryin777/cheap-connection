//
//  MySQLClient.swift
//  cheap-connection
//
//  MySQL客户端实现 - 基于MySQLKit
//

import Foundation
import MySQLKit
import MySQLNIO
import NIOCore
import NIOPosix
import Logging

/// MySQL客户端
/// 使用MySQLKit实现MySQLClientProtocol
final class MySQLClient: MySQLClientProtocol, @unchecked Sendable {
    // MARK: - Properties

    private var connection: MySQLConnection?
    private var eventLoopGroup: EventLoopGroup?
    private let lock = NSLock()

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return connection != nil
    }

    // MARK: - Lifecycle

    deinit {
        // 使用 Task 异步关闭连接，避免阻塞 deinit
        Task {
            if let connection = connection {
                try? await connection.close().get()
            }
            try? await eventLoopGroup?.shutdownGracefully()
        }
        // 不等待 Task 完成，因为对象即将销毁
    }

    // MARK: - MySQLClientProtocol

    func connect(config: MySQLConnectionConfig) async throws {
        lock.lock()
        defer { lock.unlock() }

        // 如果已连接，先断开
        if connection != nil {
            lock.unlock()
            await disconnect()
            lock.lock()
        }

        // 创建EventLoopGroup
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        guard let eventLoopGroup = eventLoopGroup else {
            throw AppError.internalError("无法创建EventLoopGroup")
        }

        let eventLoop = eventLoopGroup.next()

        // 解析地址
        let address: SocketAddress
        do {
            address = try SocketAddress.makeAddressResolvingHost(config.host, port: config.port)
        } catch {
            throw AppError.connectionFailed("无法解析主机地址: \(config.host):\(config.port)")
        }

        do {
            let conn = try await MySQLConnection.connect(
                to: address,
                username: config.username,
                database: config.database ?? config.username,
                password: config.password,
                tlsConfiguration: config.sslEnabled ? .makeClientConfiguration() : nil,
                serverHostname: config.host,
                logger: Logger(label: "com.yzz.cheap-connection.mysql"),
                on: eventLoop
            ).get()

            self.connection = conn
        } catch {
            throw MySQLErrorMapper.map(error)
        }
    }

    func disconnect() async {
        lock.lock()
        let conn = connection
        connection = nil
        let group = eventLoopGroup
        eventLoopGroup = nil
        lock.unlock()

        if let conn = conn {
            try? await conn.close().get()
        }

        if let group = group {
            try? await group.shutdownGracefully()
        }
    }

    func ping() async throws -> Bool {
        lock.lock()
        guard let conn = connection else {
            lock.unlock()
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }
        lock.unlock()

        do {
            _ = try await conn.query("SELECT 1").get()
            return true
        } catch {
            throw MySQLErrorMapper.map(error)
        }
    }

    func fetchDatabases() async throws -> [MySQLDatabaseSummary] {
        lock.lock()
        guard let conn = connection else {
            lock.unlock()
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }
        lock.unlock()

        let sql = """
            SELECT
                SCHEMA_NAME as name,
                DEFAULT_CHARACTER_SET_NAME as charset,
                DEFAULT_COLLATION_NAME as collation,
                (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = s.SCHEMA_NAME) as table_count
            FROM information_schema.SCHEMATA s
            ORDER BY SCHEMA_NAME
            """

        do {
            let rows = try await conn.query(sql).get()

            return rows.map { row in
                MySQLDatabaseSummary(
                    name: row.column("name")?.string ?? "",
                    charset: row.column("charset")?.string,
                    collation: row.column("collation")?.string,
                    tableCount: row.column("table_count")?.int
                )
            }
        } catch {
            throw MySQLErrorMapper.map(error)
        }
    }

    func fetchTables(database: String) async throws -> [MySQLTableSummary] {
        lock.lock()
        guard let conn = connection else {
            lock.unlock()
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }
        lock.unlock()

        let escapedDB = escapeString(database)
        let sql = """
            SELECT
                TABLE_NAME as name,
                ENGINE as engine,
                TABLE_ROWS as row_count,
                DATA_LENGTH as data_size,
                CREATE_TIME as create_time,
                TABLE_COMMENT as table_comment
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = '\(escapedDB)'
            ORDER BY TABLE_NAME
            """

        do {
            let rows = try await conn.query(sql).get()

            return rows.compactMap { row -> MySQLTableSummary? in
                guard let name = row.column("name")?.string else { return nil }

                return MySQLTableSummary(
                    name: name,
                    engine: row.column("engine")?.string,
                    rowCount: row.column("row_count")?.int,
                    dataSize: row.column("data_size")?.int.flatMap { Int64($0) },
                    createTime: row.column("create_time")?.date,
                    tableComment: row.column("table_comment")?.string
                )
            }
        } catch {
            throw MySQLErrorMapper.map(error)
        }
    }

    func fetchTableStructure(database: String, table: String) async throws -> [MySQLColumnDefinition] {
        lock.lock()
        guard let conn = connection else {
            lock.unlock()
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }
        lock.unlock()

        let escapedDB = escapeString(database)
        let escapedTable = escapeString(table)

        let sql = """
            SELECT
                COLUMN_NAME as name,
                COLUMN_TYPE as type,
                IS_NULLABLE as is_nullable,
                COLUMN_KEY as column_key,
                COLUMN_DEFAULT as default_value,
                EXTRA as extra,
                COLUMN_COMMENT as comment,
                CHARACTER_SET_NAME as charset,
                COLLATION_NAME as collation
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = '\(escapedDB)' AND TABLE_NAME = '\(escapedTable)'
            ORDER BY ORDINAL_POSITION
            """

        do {
            let rows = try await conn.query(sql).get()

            return rows.compactMap { row -> MySQLColumnDefinition? in
                guard let name = row.column("name")?.string else { return nil }

                let isPrimaryKey = row.column("column_key")?.string == "PRI"
                let isNullable = row.column("is_nullable")?.string == "YES"

                return MySQLColumnDefinition(
                    name: name,
                    type: row.column("type")?.string ?? "",
                    isNullable: isNullable,
                    isPrimaryKey: isPrimaryKey,
                    defaultValue: row.column("default_value")?.string,
                    extra: row.column("extra")?.string,
                    comment: row.column("comment")?.string,
                    charset: row.column("charset")?.string,
                    collation: row.column("collation")?.string
                )
            }
        } catch {
            throw MySQLErrorMapper.map(error)
        }
    }

    func fetchTableData(
        database: String,
        table: String,
        pagination: PaginationState,
        orderBy: String?,
        orderDirection: OrderDirection
    ) async throws -> MySQLQueryResult {
        lock.lock()
        guard let conn = connection else {
            lock.unlock()
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }
        lock.unlock()

        let escapedDB = escapeIdentifier(database)
        let escapedTable = escapeIdentifier(table)

        var sql = "SELECT * FROM \(escapedDB).\(escapedTable)"

        if let orderBy = orderBy, !orderBy.isEmpty {
            let escapedOrderBy = escapeIdentifier(orderBy)
            sql += " ORDER BY \(escapedOrderBy) \(orderDirection.rawValue)"
        }

        sql += " LIMIT \(pagination.pageSize) OFFSET \(pagination.offset)"

        return try await executeQueryInternal(conn: conn, sql: sql)
    }

    func executeQuery(sql: String) async throws -> MySQLQueryResult {
        lock.lock()
        guard let conn = connection else {
            lock.unlock()
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }
        lock.unlock()

        return try await executeQueryInternal(conn: conn, sql: sql)
    }

    // MARK: - Private Methods

    private func executeQueryInternal(conn: MySQLConnection, sql: String) async throws -> MySQLQueryResult {
        let startTime = Date()
        var affectedRows: UInt64?
        var columnNames: [String] = []

        do {
            // 使用 onMetadata 回调获取 affectedRows
            let rows = try await conn.query(sql) { metadata in
                affectedRows = metadata.affectedRows
            }.get()

            // 从第一行获取列名（如果有行的话）
            if let firstRow = rows.first {
                columnNames = firstRow.columnDefinitions.map { $0.name }
            }

            var resultRows: [[MySQLRowValue]] = []

            for row in rows {
                var values: [MySQLRowValue] = []
                for columnName in columnNames {
                    let value = convertRowValue(row.column(columnName))
                    values.append(value)
                }
                resultRows.append(values)
            }

            let duration = Date().timeIntervalSince(startTime)
            let executionInfo = MySQLExecutionInfo(
                executedAt: startTime,
                duration: duration,
                affectedRows: affectedRows.flatMap { Int($0) },
                isQuery: true
            )

            return MySQLQueryResult(
                columns: columnNames,
                rows: resultRows,
                executionInfo: executionInfo,
                error: nil
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let executionInfo = MySQLExecutionInfo(
                executedAt: startTime,
                duration: duration,
                affectedRows: affectedRows.flatMap { Int($0) },
                isQuery: true
            )
            let appError = MySQLErrorMapper.map(error)

            return MySQLQueryResult(
                columns: columnNames,
                rows: [],
                executionInfo: executionInfo,
                error: appError
            )
        }
    }

    private func convertRowValue(_ data: MySQLData?) -> MySQLRowValue {
        guard let data = data else { return .null }

        // 检查是否为 null (buffer 为 nil)
        if data.buffer == nil {
            return .null
        }

        if let stringValue = data.string {
            return .string(stringValue)
        }

        if let intValue = data.int {
            return .int(intValue)
        }

        if let doubleValue = data.double {
            return .double(doubleValue)
        }

        if let dateValue = data.date {
            return .date(dateValue)
        }

        // 对于 binary data，尝试获取 buffer
        if let buffer = data.buffer {
            let bytes = buffer.readableBytesView
            return .data(Data(bytes))
        }

        return .null
    }

    private func escapeIdentifier(_ identifier: String) -> String {
        "`" + identifier.replacingOccurrences(of: "`", with: "``") + "`"
    }

    private func escapeString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
