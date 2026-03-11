//
//  MySQLColumnDefinition.swift
//  cheap-connection
//
//  MySQL表列定义
//

import Foundation

/// MySQL列定义
/// 描述表结构中单个列的信息
struct MySQLColumnDefinition: Identifiable, Hashable, Sendable {
    /// 列名称（作为唯一标识）
    let name: String

    /// 数据类型（包含长度信息）
    let type: String

    /// 是否允许NULL
    let isNullable: Bool

    /// 是否为主键
    let isPrimaryKey: Bool

    /// 默认值
    let defaultValue: String?

    /// 额外属性（如 auto_increment）
    let extra: String?

    /// 列注释
    let comment: String?

    /// 字符集
    let charset: String?

    /// 排序规则
    let collation: String?

    // MARK: - Identifiable

    var id: String { name }

    // MARK: - Computed Properties

    /// 是否为自增列
    var isAutoIncrement: Bool {
        extra?.contains("auto_increment") ?? false
    }

    /// 显示用的类型描述
    var typeDescription: String {
        var desc = type
        if isNullable {
            desc += " NULL"
        } else {
            desc += " NOT NULL"
        }
        if isPrimaryKey {
            desc += " PK"
        }
        if isAutoIncrement {
            desc += " AUTO_INCREMENT"
        }
        return desc
    }

    /// 显示用的默认值描述
    var defaultValueDescription: String {
        if let value = defaultValue {
            return value.isEmpty ? "EMPTY" : value
        }
        return isNullable ? "NULL" : "-"
    }

    /// 显示用的完整类型信息
    var fullTypeDescription: String {
        var parts = [type]

        if let charset = charset {
            parts.append("CHARSET \(charset)")
        }

        if let collation = collation {
            parts.append("COLLATE \(collation)")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Preview Support

extension MySQLColumnDefinition {
    /// 预览用例数据
    static let previewData: [MySQLColumnDefinition] = [
        MySQLColumnDefinition(
            name: "id",
            type: "bigint(20) unsigned",
            isNullable: false,
            isPrimaryKey: true,
            defaultValue: nil,
            extra: "auto_increment",
            comment: "主键ID",
            charset: nil,
            collation: nil
        ),
        MySQLColumnDefinition(
            name: "username",
            type: "varchar(50)",
            isNullable: false,
            isPrimaryKey: false,
            defaultValue: nil,
            extra: nil,
            comment: "用户名",
            charset: "utf8mb4",
            collation: "utf8mb4_unicode_ci"
        ),
        MySQLColumnDefinition(
            name: "email",
            type: "varchar(100)",
            isNullable: false,
            isPrimaryKey: false,
            defaultValue: nil,
            extra: nil,
            comment: "邮箱地址",
            charset: "utf8mb4",
            collation: "utf8mb4_unicode_ci"
        ),
        MySQLColumnDefinition(
            name: "password_hash",
            type: "varchar(255)",
            isNullable: false,
            isPrimaryKey: false,
            defaultValue: nil,
            extra: nil,
            comment: "密码哈希",
            charset: "utf8mb4",
            collation: "utf8mb4_unicode_ci"
        ),
        MySQLColumnDefinition(
            name: "created_at",
            type: "timestamp",
            isNullable: false,
            isPrimaryKey: false,
            defaultValue: "CURRENT_TIMESTAMP",
            extra: nil,
            comment: "创建时间",
            charset: nil,
            collation: nil
        ),
        MySQLColumnDefinition(
            name: "updated_at",
            type: "timestamp",
            isNullable: true,
            isPrimaryKey: false,
            defaultValue: "CURRENT_TIMESTAMP",
            extra: "on update CURRENT_TIMESTAMP",
            comment: "更新时间",
            charset: nil,
            collation: nil
        ),
        MySQLColumnDefinition(
            name: "is_active",
            type: "tinyint(1)",
            isNullable: false,
            isPrimaryKey: false,
            defaultValue: "1",
            extra: nil,
            comment: "是否激活",
            charset: nil,
            collation: nil
        ),
    ]
}
