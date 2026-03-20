//
//  MySQLWorkspaceQueryContext.swift
//  cheap-connection
//
//  MySQL 工作区查询上下文切换
//

import Foundation

extension MySQLRightPanelView {
    // MARK: - 安全的临时 Service 执行辅助函数

    /// 使用临时或现有 service 执行操作，确保临时 service 在操作完成后正确断连
    /// - Parameters:
    ///   - connectionId: 连接 ID
    ///   - operation: 要执行的操作
    /// - Returns: 操作的返回值
    /// - Note: 此函数解决 defer + Task 的 fire-and-forget 问题，确保 disconnect 被等待
    func withQueryService<T>(
        _ connectionId: UUID,
        operation: (MySQLService) async throws -> T
    ) async throws -> T {
        try Task.checkCancellation()
        guard !isPanelClosing else {
            throw CancellationError()
        }
        let (queryService, shouldDisconnect) = try await serviceForQueryConnection(connectionId)

        do {
            let result = try await operation(queryService)
            try Task.checkCancellation()
            if shouldDisconnect {
                await queryService.disconnect()
            }
            return result
        } catch {
            if shouldDisconnect {
                await queryService.disconnect()
            }
            throw error
        }
    }

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

        // 使用可取消的 Task 拉取数据库列表并加载元数据
        enqueuePendingTask {
            let databases = await fetchDatabasesForConnection(connectionId)

            // 检查任务是否被取消
            guard !Task.isCancelled else { return }

            let defaultDatabase = connection.defaultDatabase ?? databases.first

            await MainActor.run {
                if let currentTabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }),
                   editorTabs[currentTabIndex].queryConnectionId == connectionId {
                    var tabToUpdate = editorTabs[currentTabIndex]
                    tabToUpdate.queryDatabaseName = defaultDatabase
                    editorTabs[currentTabIndex] = tabToUpdate
                } else if activeEditorTabId == nil, currentQueryConnectionId == connectionId {
                    scratchQueryDatabaseName = defaultDatabase
                }
            }

            // 检查任务是否被取消
            guard !Task.isCancelled, let defaultDb = defaultDatabase else { return }

            // 设置默认数据库后，加载元数据用于自动补全
            await loadQueryMetadata(database: defaultDb)
        }
    }

    func updateQueryDatabase(_ database: String?) {
        if let tabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }) {
            editorTabs[tabIndex].queryDatabaseName = database
        } else {
            scratchQueryDatabaseName = database
        }

        // 加载该数据库的表和列信息，用于 SQL 自动补全
        // 使用可取消的 Task，在 workspace 关闭时可以被正确取消
        enqueuePendingTask {
            await loadQueryMetadata(database: database)
        }
    }

    /// 加载查询数据库的元数据（表和列），用于 SQL 自动补全
    func loadQueryMetadata(database: String?) async {
        guard let database = database else {
            queryTables = []
            queryAllColumns = []
            print("[Autocomplete] 清空元数据：数据库为 nil")
            return
        }

        print("[Autocomplete] 开始加载元数据，数据库: \(database)")
        isLoadingQueryMetadata = true
        defer { isLoadingQueryMetadata = false }

        do {
            // 检查任务是否被取消
            guard !Task.isCancelled else {
                print("[Autocomplete] 任务已取消")
                return
            }

            // 使用 withQueryService 确保 disconnect 被正确等待
            let tables = try await withQueryService(currentQueryConnectionId) { queryService in
                try await queryService.fetchTables(database: database)
            }
            print("[Autocomplete] 获取到 \(tables.count) 个表")

            // 检查任务是否被取消
            guard !Task.isCancelled else {
                print("[Autocomplete] 任务已取消")
                return
            }

            await MainActor.run {
                queryTables = tables
            }

            // 第二步：获取所有表的列信息（单独处理，失败不影响表名候选）
            var allColumns: [MySQLColumnDefinition] = []
            for table in tables {
                // 检查任务是否被取消
                guard !Task.isCancelled else {
                    print("[Autocomplete] 任务已取消")
                    return
                }

                do {
                    let tableColumns = try await withQueryService(currentQueryConnectionId) { queryService in
                        try await queryService.fetchTableStructure(database: database, table: table.name)
                    }
                    allColumns.append(contentsOf: tableColumns)
                } catch {
                    // 单张表列结构失败只打印日志，不影响其他表
                    print("[Autocomplete] 获取表 \(table.name) 列信息失败: \(error.localizedDescription)")
                }
            }

            print("[Autocomplete] 获取到 \(allColumns.count) 个列")

            // 检查任务是否被取消
            guard !Task.isCancelled else { return }

            await MainActor.run {
                queryAllColumns = allColumns
            }
        } catch {
            // 只有表列表获取失败时才清空，并打印错误
            print("[Autocomplete] 加载元数据失败: \(error.localizedDescription)")
            await MainActor.run {
                queryTables = []
                queryAllColumns = []
            }
        }
    }

    func fetchDatabasesForConnection(_ connectionId: UUID) async -> [String] {
        guard !Task.isCancelled, !isPanelClosing else { return [] }
        if connectionId == connectionConfig.id {
            // 对于当前工作区连接，直接通过 service 获取
            if let cached = connectionDatabaseCache[connectionId] {
                return cached
            }
        }

        if let cached = connectionDatabaseCache[connectionId] {
            return cached
        }

        do {
            let databaseList = try await withQueryService(connectionId) { queryService in
                try await queryService.fetchDatabases()
            }
            guard !Task.isCancelled, !isPanelClosing else {
                return []
            }

            let databaseNames = databaseList.map(\.name)
            connectionDatabaseCache[connectionId] = databaseNames
            return databaseNames
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return [] }
            return []
        }
    }

    /// 获取查询连接的 service
    /// - Parameter connectionId: 连接 ID
    /// - Returns: (service, shouldDisconnect) 元组
    /// - Note: 优先使用 `withQueryService` 辅助函数，它能自动管理临时 service 的断连
    func serviceForQueryConnection(_ connectionId: UUID) async throws -> (service: MySQLService, shouldDisconnect: Bool) {
        if connectionId == connectionConfig.id {
            // 当前工作区连接，使用传入的 service
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
