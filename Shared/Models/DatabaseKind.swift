//
//  DatabaseKind.swift
//  cheap-connection
//
//  数据库类型枚举定义
//

import Foundation

/// 支持的数据库类型
enum DatabaseKind: String, Codable, CaseIterable, Identifiable {
    case mysql
    case redis

    var id: String { rawValue }

    /// 用于界面显示的名称
    var displayName: String {
        switch self {
        case .mysql: return "MySQL"
        case .redis: return "Redis"
        }
    }

    /// 默认端口号
    var defaultPort: Int {
        switch self {
        case .mysql: return 3306
        case .redis: return 6379
        }
    }

    /// 连接协议图标名称（SF Symbols）
    var iconName: String {
        switch self {
        case .mysql: return "cylinder.split.1x2"
        case .redis: return "memorychip"
        }
    }
}
