//
//  RedisConnectionConfig.swift
//  cheap-connection
//
//  Redis连接配置 - 运行时使用的连接参数
//

import Foundation

/// Redis连接配置
/// 包含运行时连接所需的所有参数，包括从Keychain获取的密码
struct RedisConnectionConfig: Sendable {
    /// 关联的连接配置ID
    let connectionId: UUID

    /// 主机地址
    let host: String

    /// 端口号
    let port: Int

    /// 用户名（Redis 6.0+ ACL）
    let username: String?

    /// 密码
    let password: String?

    /// 默认数据库索引（0-15）
    let database: Int?

    /// 是否启用TLS
    let tlsEnabled: Bool

    /// 连接超时时间（秒）
    let timeout: TimeInterval

    /// 从ConnectionConfig创建RedisConnectionConfig
    /// - Parameters:
    ///   - config: 连接配置
    ///   - password: 从Keychain获取的密码（可选）
    init(from config: ConnectionConfig, password: String?) {
        self.connectionId = config.id
        self.host = config.host
        self.port = config.port
        self.username = config.username.isEmpty ? nil : config.username
        self.password = password?.isEmpty == false ? password : nil

        // 解析默认数据库索引
        if let dbStr = config.defaultDatabase, let db = Int(dbStr) {
            self.database = db
        } else {
            self.database = nil
        }

        self.tlsEnabled = config.sslEnabled
        self.timeout = 30.0
    }

    /// 用于日志的连接描述（不含密码）
    var connectionDescription: String {
        let auth = username != nil ? "\(username!)@" : ""
        let db = database.map { "/\($0)" } ?? ""
        return "Redis: \(auth)\(host):\(port)\(db)"
    }
}
