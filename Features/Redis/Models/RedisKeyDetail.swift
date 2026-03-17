//
//  RedisKeyDetail.swift
//  cheap-connection
//
//  Redis Key 详细信息
//

import Foundation

/// Redis Key 详情
/// 包含 key 的完整信息和值预览
struct RedisKeyDetail: Sendable, Equatable {
    /// Key 名称
    let key: String

    /// 值类型
    let type: RedisValueType

    /// TTL（秒），nil 表示永不过期
    let ttl: Int?

    /// 内存大小（字节）
    let memorySize: Int?

    /// 值预览（截断后的字符串表示）
    let valuePreview: String?

    /// 值长度（元素数量或字符串长度）
    let valueLength: Int?

    /// 编码类型（如 embstr, raw, hashtable 等）
    let encoding: String?

    nonisolated init(
        key: String,
        type: RedisValueType,
        ttl: Int? = nil,
        memorySize: Int? = nil,
        valuePreview: String? = nil,
        valueLength: Int? = nil,
        encoding: String? = nil
    ) {
        self.key = key
        self.type = type
        self.ttl = ttl
        self.memorySize = memorySize
        self.valuePreview = valuePreview
        self.valueLength = valueLength
        self.encoding = encoding
    }

    /// 格式化的值长度显示
    var formattedLength: String {
        guard let length = valueLength else {
            return "-"
        }
        switch type {
        case .string:
            return "\(length) 字符"
        case .hash:
            return "\(length) 字段"
        case .list:
            return "\(length) 元素"
        case .set, .zset:
            return "\(length) 成员"
        case .stream:
            return "\(length) 条消息"
        default:
            return "\(length)"
        }
    }

    /// 是否有 TTL
    var hasExpiry: Bool {
        guard let ttl = ttl else { return false }
        return ttl > 0
    }
}
