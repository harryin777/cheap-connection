//
//  RecentHistoryRepository.swift
//  cheap-connection
//
//  最近连接记录仓储
//

import Foundation

/// 最近连接记录
struct RecentConnection: Codable, Identifiable, Equatable {
    let connectionId: UUID
    let connectedAt: Date

    var id: UUID { connectionId }
}

/// 最近连接记录仓储协议
protocol RecentHistoryRepositoryProtocol: Sendable {
    /// 获取最近连接记录
    func fetchRecent(limit: Int) throws -> [RecentConnection]
    /// 记录一次连接
    func recordConnection(_ connectionId: UUID) throws
    /// 清除所有记录
    func clear() throws
}

/// 最近连接记录仓储实现
final class RecentHistoryRepository: RecentHistoryRepositoryProtocol, @unchecked Sendable {
    /// 存储文件名
    private let fileName = "recent_connections.json"

    /// 最大记录数量
    private let maxRecords = 10

    /// 文件管理器
    private let fileManager = FileManager.default

    /// 存储目录
    private var storageDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // 在 macOS 上这个目录应该总是存在，但为了安全使用临时目录作为回退
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

    static let shared = RecentHistoryRepository()

    // MARK: - RecentHistoryRepositoryProtocol

    func fetchRecent(limit: Int) throws -> [RecentConnection] {
        guard fileManager.fileExists(atPath: storageFile.path) else {
            return []
        }

        let data = try Data(contentsOf: storageFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let records = try decoder.decode([RecentConnection].self, from: data)
        return Array(records.sorted { $0.connectedAt > $1.connectedAt }.prefix(limit))
    }

    func recordConnection(_ connectionId: UUID) throws {
        var records = (try? fetchRecent(limit: maxRecords)) ?? []

        // 移除已存在的记录
        records.removeAll { $0.connectionId == connectionId }

        // 添加新记录到开头
        let newRecord = RecentConnection(connectionId: connectionId, connectedAt: Date())
        records.insert(newRecord, at: 0)

        // 保持最大数量限制
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }

        try writeRecords(records)
    }

    func clear() throws {
        try writeRecords([])
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    private func writeRecords(_ records: [RecentConnection]) throws {
        ensureDirectoryExists()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(records)
        try data.write(to: storageFile, options: .atomic)
    }
}
