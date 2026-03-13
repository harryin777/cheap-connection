//
//  MySQLQueries.swift
//  cheap-connection
//
//  MySQL 查询语句常量
//

import Foundation

/// MySQL 查询语句常量
enum MySQLQueries {
    /// 获取数据库列表
    static let fetchDatabases = """
        SELECT
            SCHEMA_NAME as name,
            DEFAULT_CHARACTER_SET_NAME as charset,
            DEFAULT_COLLATION_NAME as collation,
            (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = s.SCHEMA_NAME) as table_count
        FROM information_schema.SCHEMATA s
        ORDER BY SCHEMA_NAME
        """

    /// 获取表列表
    static func fetchTables(database: String) -> String {
        let escapedDB = MySQLEscapeUtils.escapeString(database)
        return """
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
    }

    /// 获取表结构
    static func fetchTableStructure(database: String, table: String) -> String {
        let escapedDB = MySQLEscapeUtils.escapeString(database)
        let escapedTable = MySQLEscapeUtils.escapeString(table)
        return """
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
    }

    /// 获取表数据（分页）
    static func fetchTableData(
        database: String,
        table: String,
        pageSize: Int,
        offset: Int,
        orderBy: String?,
        orderDirection: String
    ) -> String {
        let escapedDB = MySQLEscapeUtils.escapeIdentifier(database)
        let escapedTable = MySQLEscapeUtils.escapeIdentifier(table)

        var sql = "SELECT * FROM \(escapedDB).\(escapedTable)"

        if let orderBy = orderBy, !orderBy.isEmpty {
            let escapedOrderBy = MySQLEscapeUtils.escapeIdentifier(orderBy)
            sql += " ORDER BY \(escapedOrderBy) \(orderDirection)"
        }

        sql += " LIMIT \(pageSize) OFFSET \(offset)"
        return sql
    }
}
