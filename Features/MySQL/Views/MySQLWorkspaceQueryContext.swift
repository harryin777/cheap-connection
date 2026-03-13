//
//  MySQLWorkspaceQueryContext.swift
//  cheap-connection
//
//  MySQL 工作区查询上下文切换
//

import Foundation

extension MySQLWorkspaceView {
    func switchQueryConnection(_ connectionId: UUID) {
        guard let connection = connectionManager.connections.first(where: { $0.id == connectionId }) else { return }

        if let tabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }) {
            var updatedTab = editorTabs[tabIndex]
            updatedTab.queryConnectionId = connectionId
            updatedTab.queryConnectionName = connection.name
            updatedTab.queryDatabaseName = nil
            editorTabs[tabIndex] = updatedTab
        } else {
            scratchQueryConnectionId = connectionId
            scratchQueryConnectionName = connection.name
            scratchQueryDatabaseName = nil
        }

        // 清除新连接的数据库缓存，确保 UI 显示加载中状态
        if connectionId != connectionConfig.id {
            connectionDatabaseCache.removeValue(forKey: connectionId)
        }

        Task {
            let databases = await fetchDatabasesForConnection(connectionId)
            await MainActor.run {
                let defaultDatabase = connection.defaultDatabase ?? databases.first

                if let currentTabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }),
                   editorTabs[currentTabIndex].queryConnectionId == connectionId {
                    var tabToUpdate = editorTabs[currentTabIndex]
                    tabToUpdate.queryDatabaseName = defaultDatabase
                    editorTabs[currentTabIndex] = tabToUpdate
                } else if activeEditorTabId == nil, currentQueryConnectionId == connectionId {
                    scratchQueryDatabaseName = defaultDatabase
                }
            }
        }
    }

    func updateQueryDatabase(_ database: String?) {
        if let tabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }) {
            editorTabs[tabIndex].queryDatabaseName = database
        } else {
            scratchQueryDatabaseName = database
        }
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

    func serviceForQueryConnection(_ connectionId: UUID) async throws -> (service: MySQLService, shouldDisconnect: Bool) {
        if connectionId == connectionConfig.id {
            guard let service else {
                throw AppError.connectionFailed("当前工作区连接未建立")
            }
            return (service, false)
        }

        guard let connection = connectionManager.connections.first(where: { $0.id == connectionId }) else {
            throw AppError.connectionFailed("未找到对应连接")
        }

        guard let password = try connectionManager.getPassword(for: connectionId), !password.isEmpty else {
            throw AppError.authenticationFailed("未找到保存的密码，请重新编辑连接")
        }

        let tempService = MySQLService(connectionConfig: connection)
        try await tempService.connect(config: connection, password: password)
        return (tempService, true)
    }
}
