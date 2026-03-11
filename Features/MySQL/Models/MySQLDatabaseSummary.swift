//
//  MySQLDatabaseSummary.swift
//  cheap-connection
//
//  MySQL数据库摘要信息
//

import Foundation

/// MySQL数据库摘要
/// 展示数据库列表时使用的基本信息
struct MySQLDatabaseSummary: Identifiable, Hashable, Sendable {
    /// 数据库名称（作为唯一标识）
    let name: String

    /// 默认字符集
    let charset: String?

    /// 默认排序规则
    let collation: String?

    /// 表数量
    let tableCount: Int?

    /// 表列表（可选，用于树形结构缓存）
    var tables: [MySQLTableSummary]?

    // MARK: - Identifiable

    var id: String { name }

    // MARK: - Computed Properties

    /// 是否为系统数据库
    var isSystemDatabase: Bool {
        ["information_schema", "mysql", "performance_schema", "sys"].contains(name.lowercased())
    }

    /// 显示用的表数量描述
    var tableCountDescription: String {
        guard let count = tableCount else { return "-" }
        return "\(count) 表"
    }

    /// 显示用的字符集描述
    var charsetDescription: String {
        charset ?? "-"
    }
}

// MARK: - Preview Support

extension MySQLDatabaseSummary {
    /// 预览用例数据
    static let previewData: [MySQLDatabaseSummary] = [
        MySQLDatabaseSummary(name: "myapp_production", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", tableCount: 15),
        MySQLDatabaseSummary(name: "myapp_staging", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", tableCount: 15),
        MySQLDatabaseSummary(name: "users_db", charset: "utf8mb4", collation: "utf8mb4_general_ci", tableCount: 5),
        MySQLDatabaseSummary(name: "logs", charset: "latin1", collation: "latin1_swedish_ci", tableCount: 3),
        MySQLDatabaseSummary(name: "information_schema", charset: "utf8", collation: "utf8_general_ci", tableCount: 61),
        MySQLDatabaseSummary(name: "mysql", charset: "utf8mb4", collation: "utf8mb4_general_ci", tableCount: 37),
    ]
}
