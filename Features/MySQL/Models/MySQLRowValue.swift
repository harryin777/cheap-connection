//
//  MySQLRowValue.swift
//  cheap-connection
//
//  MySQL行值类型
//

import Foundation

/// MySQL行值
/// 表示查询结果中单个单元格的值
enum MySQLRowValue: Equatable, Sendable {
    /// 字符串类型
    case string(String)

    /// 整数类型
    case int(Int)

    /// 浮点数类型
    case double(Double)

    /// 日期时间类型
    case date(Date)

    /// 二进制数据
    case data(Data)

    /// NULL值
    case null

    // MARK: - Computed Properties

    /// 用于显示的字符串值
    var displayValue: String {
        switch self {
        case .string(let value):
            return value

        case .int(let value):
            return String(value)

        case .double(let value):
            return String(format: "%.6g", value)

        case .date(let value):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter.string(from: value)

        case .data(let value):
            if value.isEmpty {
                return "[空数据]"
            }
            // 显示十六进制预览
            let previewLength = min(value.count, 32)
            let preview = value.prefix(previewLength)
            let hex = preview.map { String(format: "%02X", $0) }.joined(separator: " ")
            return "[BINARY \(value.count) bytes] \(hex)\(value.count > 32 ? "..." : "")"

        case .null:
            return "NULL"
        }
    }

    /// 类型提示文本
    var typeHint: String? {
        switch self {
        case .string:
            return "TEXT"
        case .int:
            return "INT"
        case .double:
            return "DECIMAL"
        case .date:
            return "DATETIME"
        case .data:
            return "BINARY"
        case .null:
            return nil
        }
    }

    /// 是否为NULL
    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// 尝试获取字符串值
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// 尝试获取整数值
    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    /// 尝试获取浮点数值
    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }
}

// MARK: - Preview Support

extension MySQLRowValue {
    /// 预览用例数据
    static let previewRow: [MySQLRowValue] = [
        .int(1),
        .string("john_doe"),
        .string("john@example.com"),
        .date(Date().addingTimeInterval(-86400 * 30)),
        .int(1)
    ]

    static let previewRowWithNull: [MySQLRowValue] = [
        .int(2),
        .string("jane_smith"),
        .null,
        .date(Date().addingTimeInterval(-86400 * 15)),
        .int(0)
    ]
}
