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
