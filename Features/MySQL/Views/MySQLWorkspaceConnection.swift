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

        // 记录连接开始阶段
        let metadata = [
            "connectionId": connectionConfig.id.uuidString,
            "name": connectionConfig.name,
            "host": connectionConfig.host,
            "port": "\(connectionConfig.port)",
            "username": connectionConfig.username,
            "defaultDatabase": connectionConfig.defaultDatabase ?? "nil",
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "nil",
            "executablePath": Bundle.main.executablePath ?? "nil"
        ]
        let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        appLogDebug("MySQL 连接开始 | \(metaStr)", category: .connection)

        do {
            // 阶段1: Keychain 读取密码
            appLogDebug("MySQL 连接阶段1: 读取 Keychain 密码 | connectionId=\(connectionConfig.id.uuidString)", category: .connection)

            guard let password = try KeychainService.shared.getPassword(for: connectionConfig.id) else {
                appLogError("MySQL 连接失败: Keychain 未找到密码 | connectionId=\(connectionConfig.id.uuidString)", category: .connection)
                throw AppError.authenticationFailed("未找到保存的密码，请重新编辑连接")
            }

            appLogDebug("MySQL 连接阶段1完成: Keychain 密码读取成功 | connectionId=\(connectionConfig.id.uuidString)", category: .connection)

            // 阶段2: 驱动层连接
            let phase2Metadata = [
                "connectionId": connectionConfig.id.uuidString,
                "host": connectionConfig.host,
                "port": "\(connectionConfig.port)"
            ]
            appLogDebug("MySQL 连接阶段2: 开始驱动层连接 | \(phase2Metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))", category: .connection)

            let newService = MySQLService(connectionConfig: connectionConfig)
            try await newService.connect(config: connectionConfig, password: password)

            appLogDebug("MySQL 连接阶段2完成: 驱动层连接成功 | connectionId=\(connectionConfig.id.uuidString)", category: .connection)

            guard !Task.isCancelled, !isWorkspaceClosing else {
                await newService.disconnect()
                return
            }
            service = newService
            connectionManager.recordConnectionUsage(connectionConfig.id)

            appLogInfo("MySQL 连接成功 | connectionId=\(connectionConfig.id.uuidString), name=\(connectionConfig.name)", category: .connection)
        } catch {
            if Task.isCancelled || isWorkspaceClosing {
                await service?.disconnect()
                service = nil
                return
            }
            await service?.disconnect()
            service = nil

            let errorMetadata = [
                "connectionId": connectionConfig.id.uuidString,
                "error": error.localizedDescription,
                "errorType": String(describing: type(of: error))
            ]
            appLogError("MySQL 连接失败 | \(errorMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))", category: .connection)

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
