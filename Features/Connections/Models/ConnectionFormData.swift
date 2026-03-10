//
//  ConnectionFormData.swift
//  cheap-connection
//
//  连接表单数据模型
//

import Foundation

/// 连接表单数据
struct ConnectionFormData {
    var name: String = ""
    var databaseKind: DatabaseKind = .mysql
    var host: String = "localhost"
    var port: Int = 3306
    var username: String = ""
    var password: String = ""
    var defaultDatabase: String = ""
    var sslEnabled: Bool = false

    /// 新建连接
    init() {
        // 使用默认值
    }

    /// 从现有配置初始化（编辑模式）
    init(config: ConnectionConfig) {
        name = config.name
        databaseKind = config.databaseKind
        host = config.host
        port = config.port
        username = config.username
        defaultDatabase = config.defaultDatabase ?? ""
        sslEnabled = config.sslEnabled
        // 密码需要单独获取，不在这里处理
    }

    /// 转换为连接配置
    /// - Parameter id: 现有 ID（编辑模式）或 nil（新建模式）
    /// - Returns: 连接配置对象
    func toConfig(id: UUID? = nil) -> ConnectionConfig {
        ConnectionConfig(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            databaseKind: databaseKind,
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultDatabase: defaultDatabase.isEmpty ? nil : defaultDatabase.trimmingCharacters(in: .whitespacesAndNewlines),
            sslEnabled: sslEnabled
        )
    }

    /// 验证表单数据
    /// - Returns: 验证错误信息（如果有的话）
    func validate() -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            return "请输入连接名称"
        }

        if trimmedHost.isEmpty {
            return "请输入主机地址"
        }

        if port <= 0 || port > 65535 {
            return "端口号必须在 1-65535 之间"
        }

        return nil
    }

    /// 当数据库类型变化时更新默认端口
    mutating func updatePortForDatabaseKind() {
        port = databaseKind.defaultPort
    }
}
