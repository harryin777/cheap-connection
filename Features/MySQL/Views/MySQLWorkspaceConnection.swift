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
        await service?.disconnect()
        service = nil
        databases = []
    }
}
