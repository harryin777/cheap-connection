//
//  MySQLClientQueries.swift
//  cheap-connection
//
//  MySQL 客户端查询与结果映射
//

import Foundation
import MySQLKit

extension MySQLClient {
    func fetchDatabases() async throws -> [MySQLDatabaseSummary] {
        guard let connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        do {
            let rows = try await connection.query(MySQLQueries.fetchDatabases).get()
            return rows.map(makeDatabaseSummary(from:))
        } catch {
            throw MySQLErrorMapper.map(error)
        }
    }

    func fetchTables(database: String) async throws -> [MySQLTableSummary] {
        guard let connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        do {
            let rows = try await connection.query(MySQLQueries.fetchTables(database: database)).get()
            return rows.compactMap(makeTableSummary(from:))
        } catch {
            throw MySQLErrorMapper.map(error)
        }
    }

    func fetchTableStructure(database: String, table: String) async throws -> [MySQLColumnDefinition] {
        guard let connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        do {
            let sql = MySQLQueries.fetchTableStructure(database: database, table: table)
            let rows = try await connection.query(sql).get()
            return rows.compactMap(makeColumnDefinition(from:))
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
        guard let connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        let pageSize = pagination.pageSize
        let offset = (pagination.page - 1) * pageSize
        let sql = MySQLQueries.fetchTableData(
            database: database,
            table: table,
            pageSize: pageSize,
            offset: offset,
            orderBy: orderBy,
            orderDirection: orderDirection.rawValue
        )

        return try await executeQueryInternal(conn: connection, sql: sql)
    }

    func executeQuery(sql: String) async throws -> MySQLQueryResult {
        guard let connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        return try await executeQueryInternal(conn: connection, sql: sql)
    }

    func executeQueryInternal(conn: MySQLConnection, sql: String) async throws -> MySQLQueryResult {
        let startTime = Date()
        var affectedRows: UInt64?
        var columnNames: [String] = []

        do {
            let rows = try await conn.query(sql) { metadata in
                affectedRows = metadata.affectedRows
            }.get()

            if let firstRow = rows.first {
                columnNames = firstRow.columnDefinitions.map(\.name)
            }

            let resultRows = rows.map { row in
                columnNames.map { columnName in
                    MySQLValueConverter.convertRowValue(row.column(columnName))
                }
            }

            return MySQLQueryResult(
                columns: columnNames,
                rows: resultRows,
                executionInfo: makeExecutionInfo(
                    startedAt: startTime,
                    affectedRows: affectedRows
                ),
                error: nil
            )
        } catch {
            return MySQLQueryResult(
                columns: columnNames,
                rows: [],
                executionInfo: makeExecutionInfo(
                    startedAt: startTime,
                    affectedRows: affectedRows
                ),
                error: MySQLErrorMapper.map(error)
            )
        }
    }

    private func makeDatabaseSummary(from row: MySQLRow) -> MySQLDatabaseSummary {
        MySQLDatabaseSummary(
            name: row.column("name")?.string ?? "",
            charset: row.column("charset")?.string,
            collation: row.column("collation")?.string,
            tableCount: row.column("table_count")?.int
        )
    }

    private func makeTableSummary(from row: MySQLRow) -> MySQLTableSummary? {
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

    private func makeColumnDefinition(from row: MySQLRow) -> MySQLColumnDefinition? {
        guard let name = row.column("name")?.string else { return nil }

        return MySQLColumnDefinition(
            name: name,
            type: row.column("type")?.string ?? "",
            isNullable: row.column("is_nullable")?.string == "YES",
            isPrimaryKey: row.column("column_key")?.string == "PRI",
            defaultValue: row.column("default_value")?.string,
            extra: row.column("extra")?.string,
            comment: row.column("comment")?.string,
            charset: row.column("charset")?.string,
            collation: row.column("collation")?.string
        )
    }

    private func makeExecutionInfo(startedAt: Date, affectedRows: UInt64?) -> MySQLExecutionInfo {
        MySQLExecutionInfo(
            executedAt: startedAt,
            duration: Date().timeIntervalSince(startedAt),
            affectedRows: affectedRows.flatMap(Int.init),
            isQuery: true
        )
    }
}
