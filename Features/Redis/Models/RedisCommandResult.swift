//
//  RedisCommandResult.swift
//  cheap-connection
//
//  Redis 命令执行结果
//

import Foundation

/// Redis 命令执行结果
struct RedisCommandResult: Sendable, Equatable {
    /// 执行是否成功
    let success: Bool

    /// 返回值
    let value: RedisValue?

    /// 错误消息（如果有）
    let errorMessage: String?

    /// 执行耗时（秒）
    let duration: TimeInterval

    /// 受影响的 key 数量（对于删除等操作）
    let affectedKeys: Int?

    nonisolated init(
        success: Bool,
        value: RedisValue? = nil,
        errorMessage: String? = nil,
        duration: TimeInterval = 0,
        affectedKeys: Int? = nil
    ) {
        self.success = success
        self.value = value
        self.errorMessage = errorMessage
        self.duration = duration
        self.affectedKeys = affectedKeys
    }

    /// 成功结果（带值）
    static func success(_ value: RedisValue, duration: TimeInterval = 0) -> RedisCommandResult {
        RedisCommandResult(success: true, value: value, duration: duration)
    }

    /// 成功结果（空）
    static func success(duration: TimeInterval = 0) -> RedisCommandResult {
        RedisCommandResult(success: true, value: .null, duration: duration)
    }

    /// 成功结果（带状态字符串）
    static func status(_ status: String, duration: TimeInterval = 0) -> RedisCommandResult {
        RedisCommandResult(success: true, value: .status(status), duration: duration)
    }

    /// 成功结果（带整数）
    static func int(_ value: Int, duration: TimeInterval = 0, affectedKeys: Int? = nil) -> RedisCommandResult {
        RedisCommandResult(success: true, value: .int(value), duration: duration, affectedKeys: affectedKeys)
    }

    /// 错误结果
    nonisolated static func error(_ message: String, duration: TimeInterval = 0) -> RedisCommandResult {
        RedisCommandResult(success: false, errorMessage: message, duration: duration)
    }

    /// 格式化的执行耗时显示
    var formattedDuration: String {
        let ms = duration * 1000
        if ms < 1 {
            return "< 1 ms"
        }
        if ms < 1000 {
            return String(format: "%.2f ms", ms)
        }
        return String(format: "%.2f s", duration)
    }

    /// 格式化的结果预览
    var resultPreview: String {
        guard success else {
            return errorMessage ?? "未知错误"
        }

        guard let value = value else {
            return "OK"
        }

        switch value {
        case .null:
            return "(nil)"
        case .string(let s):
            if s.count > 100 {
                return String(s.prefix(100)) + "..."
            }
            return s
        case .int(let i):
            return "\(i)"
        case .double(let d):
            return String(format: "%.6g", d)
        case .status(let s):
            return s
        case .error(let msg):
            return "(error) \(msg)"
        case .array(let arr):
            return "[\(arr.count) 个元素]"
        case .data(let data):
            return "<\(data.count) 字节数据>"
        case .map(let dict):
            return "{\(dict.count) 个字段}"
        }
    }
}
