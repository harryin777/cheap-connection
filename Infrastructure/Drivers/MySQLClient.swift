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
/// 使用 actor 保证线程安全
actor MySQLClient: MySQLClientProtocol {
    // MARK: - Properties

    private var connection: MySQLConnection?
    private var eventLoopGroup: EventLoopGroup?

    // MARK: - Lifecycle

    deinit {
        // 注意：actor deinit 中不能调用 async 方法
        // 连接应该通过显式调用 disconnect() 来关闭
    }

    // MARK: - MySQLClientProtocol

    func checkConnected() async -> Bool {
        return connection != nil
    }

    func connect(config: MySQLConnectionConfig) async throws {
        // 如果已连接，先断开
        if connection != nil {
            await disconnect()
        }

        // 创建EventLoopGroup
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        guard let eventLoopGroup = eventLoopGroup else {
            throw AppError.internalError("无法创建EventLoopGroup")
        }

        let eventLoop = eventLoopGroup.next()

        // 解析地址 - 使用 POSIX getaddrinfo，支持 IPv4/IPv6 多地址
        let resolvedAddresses: [ResolvedSocketAddress]
        do {
            resolvedAddresses = try resolveSocketAddresses(host: config.host, port: config.port)

            if resolvedAddresses.isEmpty {
                throw AppError.connectionFailed("未解析到可用地址: \(config.host)")
            }
        } catch let error as AppError {
            await cleanupEventLoopGroupAfterFailedConnect()
            throw error
        } catch {
            await cleanupEventLoopGroupAfterFailedConnect()
            throw AppError.connectionFailed("地址解析失败: \(config.host):\(config.port) - \(error.localizedDescription)")
        }

        do {
            let initialDatabase = config.database?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            var attemptErrors: [Error] = []

            for resolved in resolvedAddresses {
                do {
                    let conn = try await MySQLConnection.connect(
                        to: resolved.socketAddress,
                        username: config.username,
                        database: initialDatabase,
                        password: config.password,
                        tlsConfiguration: config.sslEnabled ? .makeClientConfiguration() : nil,
                        serverHostname: config.host,
                        logger: Logger(label: "com.yzz.cheap-connection.mysql"),
                        on: eventLoop
                    ).get()

                    self.connection = conn
                    return
                } catch {
                    attemptErrors.append(error)
                }
            }

            throw buildFinalConnectionError(
                errors: attemptErrors,
                resolvedAddresses: resolvedAddresses,
                host: config.host,
                port: config.port
            )
        } catch let error as AppError {
            await cleanupEventLoopGroupAfterFailedConnect()
            throw error
        } catch {
            await cleanupEventLoopGroupAfterFailedConnect()
            throw MySQLErrorMapper.map(error)
        }
    }

    func disconnect() async {
        let conn = connection
        connection = nil
        let group = eventLoopGroup
        eventLoopGroup = nil

        if let conn = conn {
            try? await conn.close().get()
        }

        if let group = group {
            try? await group.shutdownGracefully()
        }
    }

    func ping() async throws -> Bool {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        do {
            _ = try await conn.query("SELECT 1").get()
            return true
        } catch {
            throw MySQLErrorMapper.map(error)
        }
    }

    func fetchDatabases() async throws -> [MySQLDatabaseSummary] {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

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
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

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
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

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
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        // 提取分页参数到局部变量，避免 actor 隔离问题
        let pageSize = pagination.pageSize
        let offset = (pagination.page - 1) * pageSize

        let escapedDB = escapeIdentifier(database)
        let escapedTable = escapeIdentifier(table)

        var sql = "SELECT * FROM \(escapedDB).\(escapedTable)"

        if let orderBy = orderBy, !orderBy.isEmpty {
            let escapedOrderBy = escapeIdentifier(orderBy)
            sql += " ORDER BY \(escapedOrderBy) \(orderDirection.rawValue)"
        }

        sql += " LIMIT \(pageSize) OFFSET \(offset)"

        return try await executeQueryInternal(conn: conn, sql: sql)
    }

    func executeQuery(sql: String) async throws -> MySQLQueryResult {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

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
            // Debug: 打印原始错误
            print("🔴 MySQL raw error: \(error)")
            print("🔴 Error type: \(type(of: error))")
            print("🔴 Error description: \(error.localizedDescription)")

            let appError = MySQLErrorMapper.map(error)
            print("🔴 Mapped appError: \(appError.localizedDescription)")

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

        // 日期时间类按 MySQL 原始字段格式输出，避免本地化日期展示造成格式变化
        if let mysqlTime = data.time {
            return .string(formatMySQLTime(mysqlTime, type: data.type))
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

    private func formatMySQLTime(_ value: MySQLTime, type: MySQLProtocol.DataType) -> String {
        let year = value.year.map(Int.init)
        let month = value.month.map(Int.init)
        let day = value.day.map(Int.init)
        let hour = value.hour.map(Int.init)
        let minute = value.minute.map(Int.init)
        let second = value.second.map(Int.init)
        let microsecond = value.microsecond.map(Int.init) ?? 0

        let hasDate = year != nil && month != nil && day != nil
        let hasTime = hour != nil && minute != nil && second != nil

        let microsecondPart: String = {
            guard microsecond > 0 else { return "" }
            return String(format: ".%06d", microsecond)
        }()

        switch type {
        case .date:
            if hasDate {
                return String(format: "%04d-%02d-%02d", year!, month!, day!)
            }
        case .time:
            if hasTime {
                return String(format: "%02d:%02d:%02d%@", hour!, minute!, second!, microsecondPart)
            }
        case .datetime, .timestamp:
            if hasDate && hasTime {
                return String(
                    format: "%04d-%02d-%02d %02d:%02d:%02d%@",
                    year!, month!, day!, hour!, minute!, second!, microsecondPart
                )
            }
        default:
            break
        }

        if hasDate && hasTime {
            return String(
                format: "%04d-%02d-%02d %02d:%02d:%02d%@",
                year!, month!, day!, hour!, minute!, second!, microsecondPart
            )
        }
        if hasDate {
            return String(format: "%04d-%02d-%02d", year!, month!, day!)
        }
        if hasTime {
            return String(format: "%02d:%02d:%02d%@", hour!, minute!, second!, microsecondPart)
        }

        return ""
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

    private func cleanupEventLoopGroupAfterFailedConnect() async {
        let group = eventLoopGroup
        eventLoopGroup = nil

        if let group = group {
            try? await group.shutdownGracefully()
        }
    }

    private func resolveSocketAddresses(host: String, port: Int) throws -> [ResolvedSocketAddress] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, String(port), &hints, &result)
        guard status == 0, let firstInfo = result else {
            let errorMsg = String(cString: gai_strerror(status))
            throw AppError.connectionFailed("DNS解析失败: \(host) - \(errorMsg)")
        }
        defer {
            freeaddrinfo(firstInfo)
        }

        var addresses: [ResolvedSocketAddress] = []
        var seen: Set<String> = []
        var cursor: UnsafeMutablePointer<addrinfo>? = firstInfo

        while let info = cursor {
            defer {
                cursor = info.pointee.ai_next
            }

            guard let rawAddress = info.pointee.ai_addr else {
                continue
            }

            let ip = numericHost(
                from: rawAddress,
                length: socklen_t(info.pointee.ai_addrlen)
            ) ?? host

            let key = "\(info.pointee.ai_family)-\(ip)-\(port)"
            if !seen.insert(key).inserted {
                continue
            }

            switch info.pointee.ai_family {
            case AF_INET:
                let addrIn = rawAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                addresses.append(ResolvedSocketAddress(
                    socketAddress: SocketAddress(addrIn, host: host),
                    ipAddress: ip
                ))
            case AF_INET6:
                let addrIn6 = rawAddress.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                addresses.append(ResolvedSocketAddress(
                    socketAddress: SocketAddress(addrIn6, host: host),
                    ipAddress: ip
                ))
            default:
                continue
            }
        }

        return addresses
    }

    private func numericHost(from address: UnsafePointer<sockaddr>, length: socklen_t) -> String? {
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            length,
            &hostBuffer,
            socklen_t(hostBuffer.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else {
            return nil
        }
        return String(cString: hostBuffer)
    }

    private func buildFinalConnectionError(
        errors: [Error],
        resolvedAddresses: [ResolvedSocketAddress],
        host: String,
        port: Int
    ) -> AppError {
        if errors.isEmpty {
            return .connectionFailed("连接失败: 未获取到底层错误")
        }

        if errors.allSatisfy({ isConnectTimeout($0) }) {
            let ipList = resolvedAddresses.map(\.ipAddress).joined(separator: ", ")
            let allPrivate = resolvedAddresses.allSatisfy { isPrivateIPAddress($0.ipAddress) }

            if allPrivate {
                return .timeout("连接超时，\(host):\(port) 解析为私网地址（\(ipList)），请确认已接入对应 VPC/VPN 或使用公网地址")
            }

            return .timeout("连接超时，目标 \(host):\(port)，解析地址：\(ipList)")
        }

        if let lastError = errors.last {
            return MySQLErrorMapper.map(lastError)
        }

        return .connectionFailed("连接失败: 未获取到底层错误")
    }

    private func isConnectTimeout(_ error: Error) -> Bool {
        if let channelError = error as? ChannelError, case .connectTimeout = channelError {
            return true
        }
        return String(describing: error).lowercased().contains("connecttimeout")
    }

    private func isPrivateIPAddress(_ ipAddress: String) -> Bool {
        if ipAddress.contains(".") {
            return isPrivateIPv4(ipAddress)
        }
        return isPrivateIPv6(ipAddress)
    }

    private func isPrivateIPv4(_ ipAddress: String) -> Bool {
        let parts = ipAddress.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else {
            return false
        }

        let first = parts[0]
        let second = parts[1]

        if first == 10 || first == 127 {
            return true
        }
        if first == 169 && second == 254 {
            return true
        }
        if first == 192 && second == 168 {
            return true
        }
        if first == 172 && (16...31).contains(second) {
            return true
        }

        return false
    }

    private func isPrivateIPv6(_ ipAddress: String) -> Bool {
        let normalized = ipAddress.lowercased()

        if normalized == "::1" {
            return true
        }
        if normalized.hasPrefix("fc") || normalized.hasPrefix("fd") {
            return true
        }
        if normalized.hasPrefix("fe8") ||
            normalized.hasPrefix("fe9") ||
            normalized.hasPrefix("fea") ||
            normalized.hasPrefix("feb") {
            return true
        }

        return false
    }
}

private struct ResolvedSocketAddress {
    let socketAddress: SocketAddress
    let ipAddress: String
}
