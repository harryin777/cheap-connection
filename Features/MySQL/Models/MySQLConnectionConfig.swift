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
/// 用于管理打开的 .sql 文件
struct EditorQueryTab: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL
    var title: String          // url.lastPathComponent
    var content: String        // SQL 文本
    var isDirty: Bool = false  // 内容是否被修改（暂不实现保存，仅预留）
    // GPT TODO: 当前 tab 模型只存文件名和文本，没有存“这个 query 文件当前绑定哪个连接/数据库”的上下文。
    // GPT TODO: 这正是右上角 context pill 与左侧资源树串状态的根因之一。
    // GPT TODO: glm5 需要给 EditorQueryTab 增加独立上下文字段，至少包括：
    // GPT TODO: - queryConnectionId: UUID
    // GPT TODO: - queryConnectionName: String（如 UI 直接展示需要）
    // GPT TODO: - queryDatabaseName: String?
    // GPT TODO: 并且这些字段必须随 tab 切换一起切换，不能再挂在 MySQLWorkspaceView 的单一 @State 上。

    init(fileURL: URL, content: String) {
        self.id = UUID()
        self.fileURL = fileURL
        self.title = fileURL.lastPathComponent
        self.content = content
    }

    static func == (lhs: EditorQueryTab, rhs: EditorQueryTab) -> Bool {
        lhs.id == rhs.id
    }
}
