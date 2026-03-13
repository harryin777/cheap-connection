//
//  MySQLEscapeUtils.swift
//  cheap-connection
//
//  MySQL字符串转义工具
//

import Foundation

/// MySQL转义工具
enum MySQLEscapeUtils {
    /// 转义标识符（表名、列名等）
    /// 使用反引号包围，并转义内部的反引号
    static func escapeIdentifier(_ identifier: String) -> String {
        "`" + identifier.replacingOccurrences(of: "`", with: "``") + "`"
    }

    /// 转义字符串值（用于SQL语句中的字符串）
    /// 转义特殊字符以防止SQL注入
    static func escapeString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
