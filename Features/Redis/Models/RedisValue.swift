//
//  RedisValue.swift
//  cheap-connection
//
//  Redis值封装 - 表示 Redis 返回的各种数据类型
//

import Foundation

/// Redis值封装
/// 用于统一表示 Redis 命令返回的各种数据类型
enum RedisValue: Sendable, Equatable {
    /// 简单字符串
    case string(String)

    /// 整数
    case int(Int)

    /// 浮点数
    case double(Double)

    /// 二进制数据
    case data(Data)

    /// 空值（Redis 的 nil）
    case null

    /// 错误消息
    case error(String)

    /// 简单状态（如 OK, QUEUED）
    case status(String)

    /// 数组
    case array([RedisValue])

    /// Map/字典（RESP3）
    case map([String: RedisValue])
}

// MARK: - Convenience Initializers

extension RedisValue {
    /// 从字符串创建
    init(_ string: String) {
        self = .string(string)
    }

    /// 从整数创建
    init(_ int: Int) {
        self = .int(int)
    }

    /// 从可选字符串创建
    init?(_ string: String?) {
        guard let string = string else { return nil }
        self = .string(string)
    }
}

// MARK: - Value Extraction

extension RedisValue {
    /// 获取字符串值
    var stringValue: String? {
        switch self {
        case .string(let s):
            return s
        case .int(let i):
            return String(i)
        case .double(let d):
            return String(d)
        case .status(let s):
            return s
        default:
            return nil
        }
    }

    /// 获取整数值
    var intValue: Int? {
        switch self {
        case .int(let i):
            return i
        case .string(let s):
            return Int(s)
        default:
            return nil
        }
    }

    /// 获取浮点数值
    var doubleValue: Double? {
        switch self {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        case .string(let s):
            return Double(s)
        default:
            return nil
        }
    }

    /// 获取数组值
    var arrayValue: [RedisValue]? {
        if case .array(let arr) = self {
            return arr
        }
        return nil
    }

    /// 获取 Map 值
    var mapValue: [String: RedisValue]? {
        if case .map(let dict) = self {
            return dict
        }
        return nil
    }

    /// 是否为空
    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// 是否为错误
    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    /// 获取错误消息
    var errorMessage: String? {
        if case .error(let msg) = self {
            return msg
        }
        return nil
    }
}

// MARK: - Description

extension RedisValue: CustomStringConvertible {
    var description: String {
        switch self {
        case .string(let s):
            return s
        case .int(let i):
            return String(i)
        case .double(let d):
            return String(d)
        case .data(let data):
            return "<data: \(data.count) bytes>"
        case .null:
            return "(nil)"
        case .error(let msg):
            return "(error) \(msg)"
        case .status(let s):
            return s
        case .array(let arr):
            let elements = arr.enumerated().map { "\($0.offset + 1) \($0.element)" }
            return elements.joined(separator: "\n")
        case .map(let dict):
            return dict.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        }
    }
}
