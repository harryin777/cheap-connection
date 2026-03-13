//
//  MySQLWorkspaceConnection.swift
//  cheap-connection
//
//  MySQL 工作区连接与元数据加载
//

import Foundation

extension MySQLWorkspaceView {
    func connectIfNeeded() async {
        guard service == nil else { return }
        await connect()
    }

    func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        await disconnect()

        do {
            guard let password = try KeychainService.shared.getPassword(for: connectionConfig.id) else {
                throw AppError.authenticationFailed("未找到保存的密码，请重新编辑连接")
            }

            let newService = MySQLService(connectionConfig: connectionConfig)
            try await newService.connect(config: connectionConfig, password: password)
            service = newService
            connectionManager.recordConnectionUsage(connectionConfig.id)
            await loadDatabases()
        } catch {
            await service?.disconnect()
            service = nil
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func disconnect() async {
        await service?.disconnect()
        service = nil
        databases = []
        columns = []
        sqlResult = nil
        tableDataResult = nil
        selectedDatabase = nil
        selectedTable = nil
        connectionDatabaseCache.removeAll()
    }

    func loadDatabases() async {
        guard let service else { return }
        isLoadingDatabases = true
        defer { isLoadingDatabases = false }

        do {
            databases = try await service.fetchDatabases()
            connectionDatabaseCache[connectionConfig.id] = databases.map(\.name)
            syncSelectionFromManager()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func loadTableStructure(database: String, table: String) async {
        guard let service else { return }
        isLoadingStructure = true
        defer { isLoadingStructure = false }

        do {
            columns = try await service.fetchTableStructure(database: database, table: table)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func loadTableData(database: String, table: String) async {
        guard let service else { return }
        isLoadingData = true
        defer { isLoadingData = false }

        do {
            tableDataResult = try await service.fetchTableData(
                database: database,
                table: table,
                pagination: pagination,
                orderBy: orderBy,
                orderDirection: orderDirection
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
