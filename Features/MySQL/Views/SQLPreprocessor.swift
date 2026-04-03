//
//  SQLPreprocessor.swift
//  cheap-connection
//
//  SQL 预处理工具函数
//

import Foundation

/// SQL 预处理工具
enum SQLPreprocessor {

    struct SingleTableTarget {
        let database: String
        let table: String
    }

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

        // 匹配 SHOW CREATE TABLE table_name 模式
        let showCreatePattern = #/(?i)\bSHOW\s+CREATE\s+TABLE\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(showCreatePattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "SHOW CREATE TABLE \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 DESC/DESCRIBE table_name 模式
        let describePattern = #/(?i)\b(DESC|DESCRIBE)\s+(`?)(\w+)\2(?!\s*\.)/#
        result = result.replacing(describePattern) { match in
            let keyword = match.output.1
            let quote = match.output.2
            let tableName = match.output.3
            return "\(keyword) \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 SHOW COLUMNS FROM table_name 模式
        let showColumnsPattern = #/(?i)\bSHOW\s+COLUMNS\s+FROM\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(showColumnsPattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "SHOW COLUMNS FROM \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        return result
    }

    static func isShowCreateTable(_ sql: String) -> Bool {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(
            of: #"(?i)^show\s+create\s+table\b"#,
            options: .regularExpression
        ) != nil
    }

    static func formatCreateTableSQL(_ sql: String) -> String {
        var result = sql
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        result = result.replacingOccurrences(
            of: #"(?i)(CREATE\s+TABLE\s+.+?)\s*\("#,
            with: "$1 (\n  ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: ",`", with: ",\n  `")
        result = result.replacingOccurrences(of: ", `", with: ",\n  `")
        result = result.replacingOccurrences(of: "),\n", with: ")\n")
        result = result.replacingOccurrences(of: ", PRIMARY KEY", with: ",\n  PRIMARY KEY")
        result = result.replacingOccurrences(of: ", UNIQUE KEY", with: ",\n  UNIQUE KEY")
        result = result.replacingOccurrences(of: ", KEY", with: ",\n  KEY")
        result = result.replacingOccurrences(of: ", CONSTRAINT", with: ",\n  CONSTRAINT")
        result = result.replacingOccurrences(of: ") ENGINE=", with: "\n) ENGINE=")
        result = result.replacingOccurrences(of: " DEFAULT CHARSET=", with: "\nDEFAULT CHARSET=")
        result = result.replacingOccurrences(of: " COLLATE=", with: "\nCOLLATE=")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 解析可直接编辑的单表 SELECT 目标。
    /// 仅支持简单单表查询；JOIN / 子查询 / 聚合 / DISTINCT / GROUP BY / UNION 等结果继续只读。
    static func extractSingleTableSelectTarget(_ sql: String, defaultDatabase: String?) -> SingleTableTarget? {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        guard lowered.hasPrefix("select") else { return nil }
        guard !lowered.contains(" join "),
              !lowered.contains(" group by "),
              !lowered.contains(" union "),
              !lowered.contains(" distinct "),
              !lowered.contains(" having "),
              !lowered.contains(" into "),
              !lowered.contains(" from (") else {
            return nil
        }

        let pattern = #"(?i)\bfrom\s+(?:(`?)(\w+)\1\.)?(`?)(\w+)\3"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else { return nil }

        let explicitDatabase: String
        if let dbRange = Range(match.range(at: 2), in: trimmed) {
            explicitDatabase = String(trimmed[dbRange])
        } else {
            explicitDatabase = ""
        }

        guard let tableRange = Range(match.range(at: 4), in: trimmed) else { return nil }
        let table = String(trimmed[tableRange])

        let database: String
        if !explicitDatabase.isEmpty {
            database = explicitDatabase
        } else if let defaultDatabase, !defaultDatabase.isEmpty {
            database = defaultDatabase
        } else {
            return nil
        }

        return SingleTableTarget(database: database, table: table)
    }
}
