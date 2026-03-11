//
//  OrderDirection.swift
//  cheap-connection
//
//  排序方向
//

import Foundation

/// 排序方向
enum OrderDirection: String, Sendable, CaseIterable {
    case ascending = "ASC"
    case descending = "DESC"

    var displayName: String {
        switch self {
        case .ascending: return "升序"
        case .descending: return "降序"
        }
    }

    var iconName: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }

    /// 切换排序方向
    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}
