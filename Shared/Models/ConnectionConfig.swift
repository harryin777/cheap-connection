//
//  ConnectionConfig.swift
//  cheap-connection
//
//  连接配置模型
//

import Foundation

/// 保存的数据库连接配置
struct ConnectionConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var databaseKind: DatabaseKind
    var host: String
    var port: Int
    var username: String
    var defaultDatabase: String?
    var sslEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        databaseKind: DatabaseKind,
        host: String,
        port: Int? = nil,
        username: String = "",
        defaultDatabase: String? = nil,
        sslEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.databaseKind = databaseKind
        self.host = host
        self.port = port ?? databaseKind.defaultPort
        self.username = username
        self.defaultDatabase = defaultDatabase
        self.sslEnabled = sslEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastUsedAt = nil
    }

    /// 更新最后使用时间
    mutating func touch() {
        lastUsedAt = Date()
    }

    /// 更新修改时间
    mutating func updateTimestamp() {
        updatedAt = Date()
    }

    /// 获取连接地址描述（用于日志，不含密码）
    var connectionDescription: String {
        let db = defaultDatabase.map { "/\($0)" } ?? ""
        return "\(databaseKind.displayName): \(host):\(port)\(db)"
    }
}
