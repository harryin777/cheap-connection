//
//  SQLExecutionScope.swift
//  cheap-connection
//
//  SQL 执行范围定义
//

import Foundation

/// SQL 执行范围
struct SQLExecutionScope {
    /// 要执行的 SQL 文本
    let sql: String
    /// 范围类型
    let scopeType: ScopeType

    enum ScopeType {
        case selected      // 用户选中的文本
        case current       // 光标所在的语句
        case entire        // 整个 buffer
    }
}
