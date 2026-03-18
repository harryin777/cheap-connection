//
//  MySQLWorkspaceConnection.swift
//  cheap-connection
//
//  MySQL 工作区连接与元数据加载
//

import Foundation

extension MySQLWorkspaceView {
    func connectIfNeeded() async {
        guard !isWorkspaceClosing, service == nil else { return }
        await connect()
    }

    func connect() async {
        guard !isWorkspaceClosing else { return }
        isConnecting = true
        defer { isConnecting = false }
        isWorkspaceClosing = false
        await disconnect()

        do {
            guard let password = try KeychainService.shared.getPassword(for: connectionConfig.id) else {
                throw AppError.authenticationFailed("未找到保存的密码，请重新编辑连接")
            }

            let newService = MySQLService(connectionConfig: connectionConfig)
            try await newService.connect(config: connectionConfig, password: password)
            guard !Task.isCancelled, !isWorkspaceClosing else {
                await newService.disconnect()
                return
            }
            service = newService
            connectionManager.recordConnectionUsage(connectionConfig.id)
            if scratchQueryConnectionId == nil {
                scratchQueryConnectionId = connectionConfig.id
                scratchQueryConnectionName = connectionConfig.name
                scratchQueryDatabaseName = connectionConfig.defaultDatabase
            }
            await loadDatabases()
            guard !Task.isCancelled, !isWorkspaceClosing else { return }

            // 连接成功后，如果有默认查询数据库，加载元数据用于自动补全
            if let defaultDb = scratchQueryDatabaseName {
                await loadQueryMetadata(database: defaultDb)
            }
        } catch {
            if Task.isCancelled || isWorkspaceClosing {
                await service?.disconnect()
                service = nil
                return
            }
            await service?.disconnect()
            service = nil
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func disconnect() async {
        isConnecting = false
        isLoadingDatabases = false
        isLoadingStructure = false
        isLoadingData = false
        isLoadingSQL = false
        isLoadingQueryMetadata = false
        await service?.disconnect()
        service = nil
        databases = []
        columns = []
        sqlResult = nil
        tableDataResult = nil
        selectedDatabase = nil
        selectedTable = nil
        connectionDatabaseCache.removeAll()
        scratchQueryConnectionId = nil
        scratchQueryConnectionName = nil
        scratchQueryDatabaseName = nil
        queryTables = []
        queryAllColumns = []
    }

    func loadDatabases() async {
        guard !Task.isCancelled, !isWorkspaceClosing, let service else { return }
        isLoadingDatabases = true
        defer { isLoadingDatabases = false }

        do {
            let loadedDatabases = try await service.fetchDatabases()
            guard !Task.isCancelled, !isWorkspaceClosing else { return }
            databases = loadedDatabases
            connectionDatabaseCache[connectionConfig.id] = databases.map(\.name)
            if scratchQueryConnectionId == connectionConfig.id, scratchQueryDatabaseName == nil {
                scratchQueryDatabaseName = connectionConfig.defaultDatabase ?? databases.first?.name
                // 设置了默认查询数据库后，加载元数据用于自动补全
                if !Task.isCancelled, !isWorkspaceClosing, let defaultDb = scratchQueryDatabaseName {
                    await loadQueryMetadata(database: defaultDb)
                }
            }
            syncSelectionFromManager()
        } catch {
            guard !Task.isCancelled, !isWorkspaceClosing else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func loadTableStructure(database: String, table: String) async {
        guard !Task.isCancelled, !isWorkspaceClosing, let service else { return }
        isLoadingStructure = true
        defer { isLoadingStructure = false }

        do {
            let loadedColumns = try await service.fetchTableStructure(database: database, table: table)
            guard !Task.isCancelled, !isWorkspaceClosing else { return }
            columns = loadedColumns
        } catch {
            guard !Task.isCancelled, !isWorkspaceClosing else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func loadTableData(database: String, table: String) async {
        guard !Task.isCancelled, !isWorkspaceClosing, let service else { return }
        isLoadingData = true
        defer { isLoadingData = false }

        do {
            let result = try await service.fetchTableData(
                database: database,
                table: table,
                pagination: pagination,
                orderBy: orderBy,
                orderDirection: orderDirection
            )
            guard !Task.isCancelled, !isWorkspaceClosing else { return }
            tableDataResult = result
        } catch {
            guard !Task.isCancelled, !isWorkspaceClosing else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
