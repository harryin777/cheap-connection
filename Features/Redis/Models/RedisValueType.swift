//
//  RedisValueType.swift
//  cheap-connection
//
//  Redis值类型枚举
//

import Foundation

/// Redis值类型
enum RedisValueType: String, Sendable, Codable, Equatable {
    /// 字符串类型
    case string = "string"

    /// 哈希表类型
    case hash = "hash"

    /// 列表类型
    case list = "list"

    /// 集合类型
    case set = "set"

    /// 有序集合类型
    case zset = "zset"

    /// 流类型（Redis 5.0+）
    case stream = "stream"

    /// key不存在
    case none = "none"

    /// 未知类型
    case unknown = "unknown"

    /// 从 TYPE 命令返回值解析
    nonisolated init(fromResponseType response: String) {
        switch response.lowercased() {
        case "string":
            self = .string
        case "hash":
            self = .hash
        case "list":
            self = .list
        case "set":
            self = .set
        case "zset":
            self = .zset
        case "stream":
            self = .stream
        case "none":
            self = .none
        default:
            self = .unknown
        }
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .string: return "String"
        case .hash: return "Hash"
        case .list: return "List"
        case .set: return "Set"
        case .zset: return "ZSet"
        case .stream: return "Stream"
        case .none: return "None"
        case .unknown: return "Unknown"
        }
    }

    /// 系统图标名称
    var iconName: String {
        switch self {
        case .string: return "textformat"
        case .hash: return "list.bullet.rectangle"
        case .list: return "list.bullet"
        case .set: return "circle.dotted"
        case .zset: return "list.number"
        case .stream: return "flow.fill"
        case .none: return "questionmark.circle"
        case .unknown: return "questionmark.diamond"
        }
    }

    /// 颜色（用于 UI 显示）
    var color: String {
        switch self {
        case .string: return "blue"
        case .hash: return "purple"
        case .list: return "green"
        case .set: return "orange"
        case .zset: return "red"
        case .stream: return "cyan"
        case .none: return "gray"
        case .unknown: return "gray"
        }
    }
}
