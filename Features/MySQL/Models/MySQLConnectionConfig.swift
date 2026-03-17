//
//  MySQLConnectionConfig.swift
//  cheap-connection
//
//  MySQL连接配置 - 运行时使用的连接参数
//

import Foundation

/// MySQL连接配置
/// 包含运行时连接所需的所有参数，包括从Keychain获取的密码
struct MySQLConnectionConfig: Sendable {
    /// 关联的连接配置ID
    let connectionId: UUID

    /// 主机地址
    let host: String

    /// 端口号
    let port: Int

    /// 用户名
    let username: String

    /// 密码
    let password: String

    /// 默认数据库
    let database: String?

    /// 是否启用SSL
    let sslEnabled: Bool

    /// 连接超时时间（秒）
    let timeout: TimeInterval

    /// 从ConnectionConfig创建MySQLConnectionConfig
    /// - Parameters:
    ///   - config: 连接配置
    ///   - password: 从Keychain获取的密码
    init(from config: ConnectionConfig, password: String) {
        self.connectionId = config.id
        self.host = config.host
        self.port = config.port
        self.username = config.username
        self.password = password
        self.database = config.defaultDatabase
        self.sslEnabled = config.sslEnabled
        self.timeout = 30.0
    }

    /// 用于日志的连接描述（不含密码）
    var connectionDescription: String {
        let db = database.map { "/\($0)" } ?? ""
        return "MySQL: \(username)@\(host):\(port)\(db)"
    }
}

// MARK: - Editor Query Tab

/// MySQL 编辑器 Query Tab 模型
/// 用于管理打开的 .sql 文件，每个 tab 拥有独立的执行上下文
struct EditorQueryTab: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL
    var title: String          // url.lastPathComponent
    var content: String        // SQL 文本
    var isDirty: Bool = false  // 内容是否被修改（暂不实现保存，仅预留）
    // GPT TODO: 2.8 最后一条“未保存圆点”当前还不工作，根因之一就是 isDirty 仍停留在占位字段，没有真正接入编辑/保存链路。
    // GPT TODO: glm5 需要把 isDirty 变成真实状态：打开文件/保存成功后为 false；编辑内容后为 true；保存成功后必须自动回到 false。

    // MARK: - Query Context (独立于左侧资源树选择)

    /// Query 执行连接 ID
    var queryConnectionId: UUID

    /// Query 执行连接名称（用于显示）
    var queryConnectionName: String

    /// Query 执行数据库名
    var queryDatabaseName: String?

    init(
        fileURL: URL,
        content: String,
        defaultConnectionId: UUID,
        defaultConnectionName: String,
        defaultDatabase: String? = nil
    ) {
        self.id = UUID()
        self.fileURL = fileURL
        self.title = fileURL.lastPathComponent
        self.content = content
        self.queryConnectionId = defaultConnectionId
        self.queryConnectionName = defaultConnectionName
        self.queryDatabaseName = defaultDatabase
    }

    static func == (lhs: EditorQueryTab, rhs: EditorQueryTab) -> Bool {
        lhs.id == rhs.id &&
        lhs.queryConnectionId == rhs.queryConnectionId &&
        lhs.queryConnectionName == rhs.queryConnectionName &&
        lhs.queryDatabaseName == rhs.queryDatabaseName
        // GPT TODO: 如果后续继续保留自定义 Equatable，这里不能长期忽略 content / isDirty。
        // GPT TODO: 否则与未保存状态相关的 UI 刷新有可能被值相等判断短路，导致圆点不出现或保存后不消失。
    }
}
