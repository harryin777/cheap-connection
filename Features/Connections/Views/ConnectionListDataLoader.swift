//
//  ConnectionListDataLoader.swift
//  cheap-connection
//
//  ConnectionListView 数据加载辅助方法
//

import Foundation
import Combine

/// 连接列表树形结构的 Key 生成器
enum ConnectionListTreeKeys {
    /// 生成数据库节点 Key
    static func databaseKey(connectionId: UUID, databaseName: String) -> String {
        "\(connectionId.uuidString)::\(databaseName)"
    }

    /// 生成表文件夹节点 Key
    static func tablesFolderKey(connectionId: UUID, databaseName: String) -> String {
        "\(connectionId.uuidString)::\(databaseName)::tables"
    }
}

/// 连接列表数据加载器
/// 管理 MySQL 服务连接和数据加载
@MainActor
final class ConnectionListDataLoader: ObservableObject {
    /// 按连接 ID 存储的数据库列表
    @Published var databasesByConnection: [UUID: [MySQLDatabaseSummary]] = [:]

    /// 按连接 ID 存储的 MySQL 服务
    var mysqlServices: [UUID: MySQLService] = [:]

    /// 正在加载的连接 ID
    @Published var loadingConnectionIds: Set<UUID> = []

    /// 正在加载的数据库 Key
    @Published var loadingDatabaseKeys: Set<String> = []

    /// 确保数据库列表已加载
    func ensureDatabasesLoaded(
        for config: ConnectionConfig,
        connectionManager: ConnectionManager
    ) async {
        guard config.databaseKind == .mysql else { return }

        // 防止重复加载（如果正在加载中则跳过）
        if loadingConnectionIds.contains(config.id) { return }

        loadingConnectionIds.insert(config.id)

        do {
            let service = try await mysqlService(for: config, connectionManager: connectionManager)
            let newDatabases = try await service.fetchDatabases()
                .sorted {
                    if $0.isSystemDatabase != $1.isSystemDatabase {
                        return !$0.isSystemDatabase
                    }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }

            // Merge with existing data to preserve tables cache
            let oldDatabases = databasesByConnection[config.id]
            var mergedDatabases: [MySQLDatabaseSummary] = []

            for newDB in newDatabases {
                if let oldDB = oldDatabases?.first(where: { $0.name == newDB.name }),
                   oldDB.tables != nil {
                    // Preserve existing tables cache
                    var merged = newDB
                    merged.tables = oldDB.tables
                    mergedDatabases.append(merged)
                } else {
                    mergedDatabases.append(newDB)
                }
            }

            databasesByConnection[config.id] = mergedDatabases
        } catch {
            connectionManager.errorMessage = "加载数据库失败: \(error.localizedDescription)"
        }

        loadingConnectionIds.remove(config.id)
    }

    /// 确保表列表已加载
    func ensureTablesLoaded(
        for databaseName: String,
        in config: ConnectionConfig,
        connectionManager: ConnectionManager
    ) async {
        guard config.databaseKind == .mysql else { return }

        let databaseKey = ConnectionListTreeKeys.databaseKey(connectionId: config.id, databaseName: databaseName)
        if loadingDatabaseKeys.contains(databaseKey) { return }

        if let databases = databasesByConnection[config.id],
           let database = databases.first(where: { $0.name == databaseName }),
           database.tables != nil {
            return
        }

        loadingDatabaseKeys.insert(databaseKey)
        defer { loadingDatabaseKeys.remove(databaseKey) }

        do {
            let service = try await mysqlService(for: config, connectionManager: connectionManager)
            let tables = try await service.fetchTables(database: databaseName)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            updateTables(tables, for: databaseName, connectionId: config.id)
        } catch {
            connectionManager.errorMessage = "Failed to load tables: \(error.localizedDescription)"
        }
    }

    /// 获取或创建 MySQL 服务
    func mysqlService(
        for config: ConnectionConfig,
        connectionManager: ConnectionManager
    ) async throws -> MySQLService {
        if let service = mysqlServices[config.id], service.session.connectionState.isConnected {
            return service
        }

        guard let password = try connectionManager.getPassword(for: config.id), !password.isEmpty else {
            throw AppError.authenticationFailed("未找到保存的密码，请重新编辑连接")
        }

        let service = mysqlServices[config.id] ?? MySQLService(connectionConfig: config)
        try await service.connect(config: config, password: password)
        mysqlServices[config.id] = service
        return service
    }

    /// 更新数据库中的表列表
    func updateTables(_ tables: [MySQLTableSummary], for databaseName: String, connectionId: UUID) {
        guard var databases = databasesByConnection[connectionId],
              let index = databases.firstIndex(where: { $0.name == databaseName }) else {
            return
        }

        // 保护机制：当 tableCount > 0 但 tables 为空时，不覆盖缓存
        // 避免"拉取表列表失败/异常返回空"被误认为是真实空库
        let existingTableCount = databases[index].tableCount ?? 0
        if existingTableCount > 0 && tables.isEmpty {
            print("[DataLoader] Warning: database \(databaseName) expected \(existingTableCount) tables but got empty, keeping original state")
            return
        }

        databases[index].tables = tables
        databasesByConnection[connectionId] = databases
    }

    /// 断开指定连接的服务
    func disconnectService(for connectionId: UUID) {
        guard let service = mysqlServices.removeValue(forKey: connectionId) else { return }

        Task {
            await service.disconnect()
        }
    }

    /// 断开所有服务
    func disconnectAllServices() {
        let services = Array(mysqlServices.values)
        mysqlServices.removeAll()

        Task {
            for service in services {
                await service.disconnect()
            }
        }
    }

    /// 清除指定连接的数据
    func clearData(for connectionId: UUID) {
        databasesByConnection.removeValue(forKey: connectionId)
    }
}
