//
//  ConnectionRepository.swift
//  cheap-connection
//
//  连接配置仓储 - 本地持久化
//

import Foundation

/// 连接配置仓储协议
protocol ConnectionRepositoryProtocol: Sendable {
    /// 获取所有连接配置
    func fetchAll() throws -> [ConnectionConfig]
    /// 获取单个连接配置
    func fetch(id: UUID) throws -> ConnectionConfig?
    /// 保存连接配置
    func save(_ config: ConnectionConfig) throws
    /// 删除连接配置
    func delete(id: UUID) throws
    /// 更新最后使用时间
    func updateLastUsed(id: UUID) throws
}

/// 连接配置仓储实现
final class ConnectionRepository: ConnectionRepositoryProtocol, @unchecked Sendable {
    /// 存储文件名
    private let fileName = "connections.json"

    /// 文件管理器
    private let fileManager = FileManager.default

    /// 存储目录
    private var storageDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // 在 macOS 上这个目录应该总是存在，但为了安全使用当前目录作为回退
            return URL(fileURLWithPath: NSTemporaryDirectory())
        }
        let bundleId = Bundle.main.bundleIdentifier ?? "com.yzz.cheap-connection"
        return appSupport.appendingPathComponent(bundleId)
    }

    /// 存储文件路径
    private var storageFile: URL {
        storageDirectory.appendingPathComponent(fileName)
    }

    private init() {
        ensureDirectoryExists()
    }

    static let shared = ConnectionRepository()

    // MARK: - ConnectionRepositoryProtocol

    func fetchAll() throws -> [ConnectionConfig] {
        guard fileManager.fileExists(atPath: storageFile.path) else {
            return []
        }

        let data = try Data(contentsOf: storageFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let configs = try decoder.decode([ConnectionConfig].self, from: data)
        // 按 lastUsedAt（回退 updatedAt）倒序排列，最近使用的连接在前
        // 如果 UI 需要其他排序方式（如按类型或名称分组），应由上层处理
        return configs.sorted { ($0.lastUsedAt ?? $0.updatedAt) > ($1.lastUsedAt ?? $1.updatedAt) }
    }

    func fetch(id: UUID) throws -> ConnectionConfig? {
        let configs = try fetchAll()
        return configs.first { $0.id == id }
    }

    func save(_ config: ConnectionConfig) throws {
        var configs = try fetchAll()

        // 查找是否已存在
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
        } else {
            configs.append(config)
        }

        try writeConfigs(configs)
    }

    func delete(id: UUID) throws {
        var configs = try fetchAll()
        configs.removeAll { $0.id == id }
        try writeConfigs(configs)
    }

    func updateLastUsed(id: UUID) throws {
        var configs = try fetchAll()
        if let index = configs.firstIndex(where: { $0.id == id }) {
            configs[index].touch()
            try writeConfigs(configs)
        }
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    private func writeConfigs(_ configs: [ConnectionConfig]) throws {
        ensureDirectoryExists()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(configs)
        try data.write(to: storageFile, options: .atomic)
    }
}
