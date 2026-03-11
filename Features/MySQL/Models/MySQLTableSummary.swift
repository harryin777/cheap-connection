//
//  MySQLTableSummary.swift
//  cheap-connection
//
//  MySQL表摘要信息
//

import Foundation

/// MySQL表摘要
/// 展示表列表时使用的基本信息
struct MySQLTableSummary: Identifiable, Hashable, Sendable {
    /// 表名称（作为唯一标识）
    let name: String

    /// 存储引擎
    let engine: String?

    /// 行数（估算值）
    let rowCount: Int?

    /// 数据大小（字节）
    let dataSize: Int64?

    /// 创建时间
    let createTime: Date?

    /// 表注释
    let tableComment: String?

    // MARK: - Identifiable

    var id: String { name }

    // MARK: - Computed Properties

    /// 显示用的行数描述
    var rowCountDescription: String {
        guard let count = rowCount else { return "-" }
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    /// 显示用的数据大小描述
    var dataSizeDescription: String {
        guard let size = dataSize else { return "-" }
        if size >= 1_073_741_824 { // 1GB
            return String(format: "%.2f GB", Double(size) / 1_073_741_824.0)
        } else if size >= 1_048_576 { // 1MB
            return String(format: "%.2f MB", Double(size) / 1_048_576.0)
        } else if size >= 1024 { // 1KB
            return String(format: "%.2f KB", Double(size) / 1024.0)
        }
        return "\(size) B"
    }

    /// 显示用的引擎描述
    var engineDescription: String {
        engine ?? "-"
    }

    /// 显示用的创建时间描述
    var createTimeDescription: String {
        guard let date = createTime else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview Support

extension MySQLTableSummary {
    /// 预览用例数据
    static let previewData: [MySQLTableSummary] = [
        MySQLTableSummary(
            name: "users",
            engine: "InnoDB",
            rowCount: 125000,
            dataSize: 52428800,
            createTime: Date().addingTimeInterval(-86400 * 30),
            tableComment: "用户表"
        ),
        MySQLTableSummary(
            name: "orders",
            engine: "InnoDB",
            rowCount: 3500000,
            dataSize: 524288000,
            createTime: Date().addingTimeInterval(-86400 * 60),
            tableComment: "订单表"
        ),
        MySQLTableSummary(
            name: "products",
            engine: "InnoDB",
            rowCount: 5000,
            dataSize: 1048576,
            createTime: Date().addingTimeInterval(-86400 * 90),
            tableComment: "商品表"
        ),
        MySQLTableSummary(
            name: "sessions",
            engine: "MEMORY",
            rowCount: 500,
            dataSize: 10240,
            createTime: nil,
            tableComment: "会话缓存表"
        ),
    ]
}
