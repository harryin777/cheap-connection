//
//  MySQLEditorModels.swift
//  cheap-connection
//
//  MySQL SQL 编辑器相关模型
//

import Foundation

/// SQL 自动补全建议
struct SQLCompletionSuggestion: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    var displayText: String { text }

    enum SuggestionType: String {
        case table = "表"
        case column = "列"
        case keyword = "关键字"

        var icon: String {
            switch self {
            case .table: return "tablecells"
            case .column: return "rectangle.split.3x1"
            case .keyword: return "textformat.abc"
            }
        }

        /// 左侧缩略词标识，用于快速识别类型
        var badge: String {
            switch self {
            case .table: return "T"
            case .column: return "C"
            case .keyword: return "K"
            }
        }
    }

    static func == (lhs: SQLCompletionSuggestion, rhs: SQLCompletionSuggestion) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 导入结果
struct SQLImportResult {
    let success: Bool
    let totalStatements: Int
    let successStatements: Int
    let failedStatements: Int
    let errors: [String]
    let duration: TimeInterval

    var summary: String {
        if success {
            return "成功执行 \(successStatements) 条语句，耗时 \(String(format: "%.2f", duration))s"
        } else {
            return "执行完成：成功 \(successStatements)/\(totalStatements)，失败 \(failedStatements)"
        }
    }
}

/// SQL 关键字列表
enum SQLKeywords {
    static let all = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN",
        "ORDER", "BY", "ASC", "DESC", "GROUP", "HAVING", "LIMIT", "OFFSET",
        "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "AS", "DISTINCT",
        "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "DROP",
        "ALTER", "TABLE", "INDEX", "VIEW", "NULL", "IS", "COUNT", "SUM", "AVG",
        "MAX", "MIN", "CASE", "WHEN", "THEN", "ELSE", "END", "UNION", "ALL", "SHOW"
    ]
}
