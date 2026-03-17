//
//  RedisKeySummary.swift
//  cheap-connection
//
//  Redis Key 摘要信息
//

import Foundation

/// Redis Key 摘要
/// 用于在列表中展示 key 的基本信息
struct RedisKeySummary: Identifiable, Sendable, Equatable {
    /// 使用 key 名称作为 ID
    var id: String { key }

    /// Key 名称
    let key: String

    /// 值类型
    let type: RedisValueType

    /// TTL（秒），nil 表示永不过期，-2 表示 key 不存在
    let ttl: Int?

    /// 内存大小（字节），可能无法获取
    let memorySize: Int?

    /// 创建时间（用于排序）
    let createdAt: Date

    nonisolated init(
        key: String,
        type: RedisValueType,
        ttl: Int? = nil,
        memorySize: Int? = nil
    ) {
        self.key = key
        self.type = type
        self.ttl = ttl
        self.memorySize = memorySize
        self.createdAt = Date()
    }

    /// 格式化的 TTL 显示
    var formattedTTL: String {
        guard let ttl = ttl else {
            return "永不过期"
        }
        if ttl < 0 {
            return "已过期"
        }
        if ttl < 60 {
            return "\(ttl) 秒"
        }
        if ttl < 3600 {
            return "\(ttl / 60) 分钟"
        }
        if ttl < 86400 {
            return "\(ttl / 3600) 小时"
        }
        return "\(ttl / 86400) 天"
    }

    /// 格式化的内存大小显示
    var formattedMemorySize: String {
        guard let size = memorySize else {
            return "-"
        }
        if size < 1024 {
            return "\(size) B"
        }
        if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        }
        return String(format: "%.1f MB", Double(size) / 1024.0 / 1024.0)
    }
}
