//
//  MySQLWorkspaceQueryContext.swift
//  cheap-connection
//
//  MySQL 工作区查询上下文切换
//

import Foundation

extension MySQLWorkspaceView {
    func switchQueryConnection(_ connectionId: UUID) {
        guard let tabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }),
              let connection = connectionManager.connections.first(where: { $0.id == connectionId }) else { return }

        // 同步清空旧数据，避免库名串连
        var updatedTab = editorTabs[tabIndex]
        updatedTab.queryConnectionId = connectionId
        updatedTab.queryConnectionName = connection.name
        updatedTab.queryDatabaseName = nil
        editorTabs[tabIndex] = updatedTab

        // 清除新连接的数据库缓存，确保 UI 显示加载中状态
        if connectionId != connectionConfig.id {
            connectionDatabaseCache.removeValue(forKey: connectionId)
        }

        Task {
            let databases = await fetchDatabasesForConnection(connectionId)
            await MainActor.run {
                // 再次检查当前 tab 是否还是原来的 tab
                guard let currentTabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }),
                      currentTabIndex == tabIndex,
                      editorTabs[currentTabIndex].queryConnectionId == connectionId else { return }

                let defaultDatabase = connection.defaultDatabase ?? databases.first
                var tabToUpdate = editorTabs[currentTabIndex]
                tabToUpdate.queryDatabaseName = defaultDatabase
                editorTabs[currentTabIndex] = tabToUpdate
            }
        }
    }

    func updateQueryDatabase(_ database: String?) {
        guard let tabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }) else { return }
        editorTabs[tabIndex].queryDatabaseName = database
    }

    func fetchDatabasesForConnection(_ connectionId: UUID) async -> [String] {
        if connectionId == connectionConfig.id {
            return databases.map(\.name)
        }

        if let cached = connectionDatabaseCache[connectionId] {
            return cached
        }

        guard let connection = connectionManager.connections.first(where: { $0.id == connectionId }) else {
            return []
        }

        do {
            guard let password = try connectionManager.getPassword(for: connectionId) else { return [] }

            let tempService = MySQLService(connectionConfig: connection)
            try await tempService.connect(config: connection, password: password)
            let databaseList = try await tempService.fetchDatabases()
            await tempService.disconnect()

            let databaseNames = databaseList.map(\.name)
            connectionDatabaseCache[connectionId] = databaseNames
            return databaseNames
        } catch {
            return []
        }
    }
}
