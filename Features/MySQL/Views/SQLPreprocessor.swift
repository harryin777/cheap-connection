//
//  SQLPreprocessor.swift
//  cheap-connection
//
//  SQL 预处理工具函数
//

import Foundation

/// SQL 预处理工具
enum SQLPreprocessor {

    /// 转义 MySQL 行值为 SQL 字面量
    static func escapeValueForSQL(_ value: MySQLRowValue) -> String {
        if value.isNull {
            return "NULL"
        }
        return escapeStringValue(value.displayValue)
    }

    /// 转义字符串值为 SQL 字符串字面量
    static func escapeStringValue(_ value: String) -> String {
        if value.isEmpty {
            return "''"
        }
        // 转义单引号和反斜杠
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "'\(escaped)'"
    }

    /// 预处理 SQL，为未指定数据库的表名添加当前数据库前缀
    static func preprocessSQL(_ sql: String, database: String) -> String {
        let escapedDB = "`" + database.replacingOccurrences(of: "`", with: "``") + "`"

        var result = sql

        // 匹配 FROM table_name 模式
        let fromPattern = #/(?i)\bFROM\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(fromPattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "FROM \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 JOIN table_name 模式
        let joinPattern = #/(?i)\bJOIN\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(joinPattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "JOIN \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 UPDATE table_name 模式
        let updatePattern = #/(?i)\bUPDATE\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(updatePattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "UPDATE \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 INSERT INTO table_name 模式
        let insertPattern = #/(?i)\bINSERT\s+INTO\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(insertPattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "INSERT INTO \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 DELETE FROM table_name 模式
        let deletePattern = #/(?i)\bDELETE\s+FROM\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(deletePattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "DELETE FROM \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        return result
    }
}
