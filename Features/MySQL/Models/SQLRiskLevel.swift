//
//  SQLRiskLevel.swift
//  cheap-connection
//
//  SQL风险等级分析
//

import Foundation

/// SQL风险等级
/// 用于评估SQL语句的危险程度
enum SQLRiskLevel: Sendable {
    /// 安全 - 普通查询语句
    case safe

    /// 警告 - 可能影响较多数据
    case warning

    /// 危险 - 高风险操作
    case dangerous

    // MARK: - Analysis

    /// 分析SQL语句的风险等级
    /// - Parameter sql: SQL语句
    /// - Returns: 风险等级
    static func analyze(_ sql: String) -> SQLRiskLevel {
        let normalizedSQL = sql.uppercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)

        // 危险操作：DROP, TRUNCATE
        if normalizedSQL.hasPrefix("DROP ") ||
           normalizedSQL.contains(" DROP TABLE ") ||
           normalizedSQL.contains(" DROP DATABASE ") ||
           normalizedSQL.hasPrefix("TRUNCATE ") {
            return .dangerous
        }

        // 危险操作：FLUSH
        if normalizedSQL.hasPrefix("FLUSH ") {
            return .dangerous
        }

        // 检查DELETE语句
        if normalizedSQL.hasPrefix("DELETE ") {
            // 没有WHERE子句的DELETE是危险的
            if !normalizedSQL.contains("WHERE") {
                return .dangerous
            }
            // 有WHERE但没有LIMIT的DELETE是警告
            if !normalizedSQL.contains("LIMIT") {
                return .warning
            }
            return .safe
        }

        // 检查UPDATE语句
        if normalizedSQL.hasPrefix("UPDATE ") {
            // 没有WHERE子句的UPDATE是危险的
            if !normalizedSQL.contains("WHERE") {
                return .dangerous
            }
            // 有WHERE但没有LIMIT的UPDATE是警告
            if !normalizedSQL.contains("LIMIT") {
                return .warning
            }
            return .safe
        }

        // 检查ALTER语句
        if normalizedSQL.hasPrefix("ALTER ") {
            return .warning
        }

        // 检查INSERT ... SELECT（大量插入）
        if normalizedSQL.hasPrefix("INSERT ") && normalizedSQL.contains("SELECT") {
            return .warning
        }

        // 检查CREATE
        if normalizedSQL.hasPrefix("CREATE ") {
            return .warning
        }

        return .safe
    }

    // MARK: - Properties

    /// 警告消息
    var warningMessage: String? {
        switch self {
        case .safe:
            return nil
        case .warning:
            return "此操作可能会影响较多数据，是否继续？"
        case .dangerous:
            return "此操作具有高风险，可能导致数据丢失，是否确认执行？"
        }
    }

    /// 显示用的图标名称
    var iconName: String {
        switch self {
        case .safe:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .dangerous:
            return "xmark.octagon.fill"
        }
    }

    /// 颜色
    var color: String {
        switch self {
        case .safe:
            return "green"
        case .warning:
            return "orange"
        case .dangerous:
            return "red"
        }
    }
}

// MARK: - Preview Support

extension SQLRiskLevel {
    /// 预览用例SQL语句
    static let previewSafeSQL = "SELECT * FROM users WHERE id = 1"
    static let previewWarningSQL = "UPDATE users SET status = 'active' WHERE created_at > '2024-01-01'"
    static let previewDangerousSQL = "DROP TABLE users"
    static let previewNoWhereDelete = "DELETE FROM users"
}
