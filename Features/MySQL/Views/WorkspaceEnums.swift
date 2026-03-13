//
//  WorkspaceEnums.swift
//  cheap-connection
//
//  MySQL 工作区相关枚举定义
//

import Foundation

/// MySQL工作区标签页（只有结构和数据）
enum MySQLDetailTab: String, CaseIterable {
    case structure = "结构"
    case data = "数据"

    var icon: String {
        switch self {
        case .structure: return "tablecells"
        case .data: return "list.bullet"
        }
    }
}

/// 工作区显示模式 - 互斥状态
enum WorkspaceDisplayMode: Equatable {
    /// 默认编辑态：只展示 query 编辑内容
    case editorOnly
    /// SQL 结果态：执行 SQL 后显示结果面板
    case sqlResult
    /// 表详情态：点击左侧具体表后显示结构/数据
    case tableDetail(MySQLDetailTab)

    static func == (lhs: WorkspaceDisplayMode, rhs: WorkspaceDisplayMode) -> Bool {
        switch (lhs, rhs) {
        case (.editorOnly, .editorOnly):
            return true
        case (.sqlResult, .sqlResult):
            return true
        case (.tableDetail(let lTab), .tableDetail(let rTab)):
            return lTab == rTab
        default:
            return false
        }
    }
}
