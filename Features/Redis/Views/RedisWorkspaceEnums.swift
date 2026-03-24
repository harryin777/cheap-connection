//
//  RedisWorkspaceEnums.swift
//  cheap-connection
//
//  Redis 工作区枚举
//

import Foundation

enum RedisDetailTab: String, CaseIterable {
    case keys = "Key 浏览"
    case result = "命令结果"

    var icon: String {
        switch self {
        case .keys: return "key"
        case .result: return "terminal"
        }
    }
}

enum RedisDisplayMode: Equatable {
    case editorOnly
    case commandResult
    case keyDetail(RedisDetailTab)
}
