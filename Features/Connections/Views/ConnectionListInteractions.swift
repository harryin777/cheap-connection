//
//  ConnectionListInteractions.swift
//  cheap-connection
//
//  左侧资源树选中、展开与生命周期协调
//

import Foundation

extension ConnectionListView {
    func isConnectionSelected(_ config: ConnectionConfig) -> Bool {
        browserSelectedConnectionId == config.id &&
        browserSelectedDatabaseName == nil &&
        browserSelectedTableName == nil
    }

    func isDatabaseSelected(_ database: String, in config: ConnectionConfig) -> Bool {
        browserSelectedConnectionId == config.id &&
        browserSelectedDatabaseName == database &&
        browserSelectedTableName == nil
    }

    func isTableSelected(database: String, table: String, in config: ConnectionConfig) -> Bool {
        browserSelectedConnectionId == config.id &&
        browserSelectedDatabaseName == database &&
        browserSelectedTableName == table
    }

    func selectConnection(_ config: ConnectionConfig) {
        // 更新左侧资源树选择（只影响高亮和展开，不创建右侧 workspace）
        updateBrowserSelection(connectionId: config.id, database: nil, table: nil)

        guard config.databaseKind == .mysql else { return }
        expandedConnectionIds.insert(config.id)

        Task {
            await dataLoader.ensureDatabasesLoaded(for: config, connectionManager: connectionManager)
        }
    }

    func toggleConnection(_ config: ConnectionConfig) {
        if expandedConnectionIds.contains(config.id) {
            expandedConnectionIds.remove(config.id)
            dataLoader.disconnectService(for: config.id)
            return
        }

        expandedConnectionIds.insert(config.id)
        Task {
            await dataLoader.ensureDatabasesLoaded(for: config, connectionManager: connectionManager)
        }
    }

    func toggleDatabase(_ databaseName: String, in config: ConnectionConfig) {
        let databaseKey = ConnectionListTreeKeys.databaseKey(connectionId: config.id, databaseName: databaseName)
        let folderKey = ConnectionListTreeKeys.tablesFolderKey(connectionId: config.id, databaseName: databaseName)

        if expandedDatabaseKeys.contains(databaseKey) {
            expandedDatabaseKeys.remove(databaseKey)
            expandedFolderKeys.remove(folderKey)
            return
        }

        expandedDatabaseKeys.insert(databaseKey)
        expandedFolderKeys.insert(folderKey)

        Task {
            await dataLoader.ensureTablesLoaded(
                for: databaseName,
                in: config,
                connectionManager: connectionManager
            )
        }
    }

    func toggleTablesFolder(for database: MySQLDatabaseSummary, in config: ConnectionConfig) {
        let folderKey = ConnectionListTreeKeys.tablesFolderKey(connectionId: config.id, databaseName: database.name)

        if expandedFolderKeys.contains(folderKey) {
            expandedFolderKeys.remove(folderKey)
            return
        }

        expandedFolderKeys.insert(folderKey)

        Task {
            await dataLoader.ensureTablesLoaded(
                for: database.name,
                in: config,
                connectionManager: connectionManager
            )
        }
    }

    func autoExpandSelectedConnection() {
        guard let selectedConnectionId = browserSelectedConnectionId,
              let config = connectionManager.connections.first(where: { $0.id == selectedConnectionId }),
              config.databaseKind == .mysql else {
            return
        }

        expandedConnectionIds.insert(selectedConnectionId)
        Task {
            await dataLoader.ensureDatabasesLoaded(for: config, connectionManager: connectionManager)
        }
    }

    func deleteConnection(_ config: ConnectionConfig) {
        dataLoader.disconnectService(for: config.id)
        dataLoader.clearData(for: config.id)
        expandedConnectionIds.remove(config.id)

        do {
            try connectionManager.deleteConnection(id: config.id)
        } catch {
            connectionManager.errorMessage = error.localizedDescription
        }
    }
}
