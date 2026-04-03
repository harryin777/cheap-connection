//
//  RedisWorkspaceActions.swift
//  cheap-connection
//
//  Redis 工作区连接与数据加载动作
//

import Foundation

extension RedisWorkspaceView {
    func connectIfNeeded() async {
        if service?.session.connectionState.isConnected != true {
            await connect()
        }
    }

    func connect() async {
        isConnecting = true
        defer { isConnecting = false }

        // 记录连接开始阶段
        let metadata = [
            "connectionId": connectionConfig.id.uuidString,
            "name": connectionConfig.name,
            "host": connectionConfig.host,
            "port": "\(connectionConfig.port)",
            "defaultDatabase": connectionConfig.defaultDatabase ?? "nil",
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "nil",
            "executablePath": Bundle.main.executablePath ?? "nil"
        ]
        let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        appLogDebug("Redis 连接开始 | \(metaStr)", category: .connection)

        let newService = RedisService(connectionConfig: connectionConfig)
        service = newService

        do {
            // 阶段1: 获取密码（如果有）
            appLogDebug("Redis 连接阶段1: 获取密码 | connectionId=\(connectionConfig.id.uuidString)", category: .connection)

            let password = try? ConnectionManager.shared.getPassword(for: connectionConfig.id)

            appLogDebug("Redis 连接阶段1完成: 密码获取完成 | connectionId=\(connectionConfig.id.uuidString), hasPassword=\(password != nil ? "true" : "false")", category: .connection)

            // 阶段2: 驱动层连接
            let phase2Meta = [
                "connectionId": connectionConfig.id.uuidString,
                "host": connectionConfig.host,
                "port": "\(connectionConfig.port)"
            ]
            appLogDebug("Redis 连接阶段2: 开始驱动层连接 | \(phase2Meta.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))", category: .connection)

            try await newService.connect(config: connectionConfig, password: password)

            appLogDebug("Redis 连接阶段2完成: 驱动层连接成功 | connectionId=\(connectionConfig.id.uuidString)", category: .connection)

            await loadInitialKeys()

            appLogInfo("Redis 连接成功 | connectionId=\(connectionConfig.id.uuidString), name=\(connectionConfig.name)", category: .connection)
        } catch {
            let errorMeta = [
                "connectionId": connectionConfig.id.uuidString,
                "error": error.localizedDescription,
                "errorType": String(describing: type(of: error))
            ]
            appLogError("Redis 连接失败 | \(errorMeta.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))", category: .connection)
            showError(message: error.localizedDescription)
        }
    }

    func disconnect() async {
        await service?.disconnect()
        service = nil
    }

    func loadInitialKeys() async {
        guard let service else { return }
        isLoadingKeys = true
        defer { isLoadingKeys = false }

        do {
            let result = try await service.scanKeys(match: nil, count: 100, cursor: 0, append: false)
            keys = result.keys.map { RedisKeySummary(key: $0, type: .unknown) }
            scanCursor = result.nextCursor
            hasMoreKeys = result.nextCursor != 0
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    func loadMoreKeys() async {
        guard let service, hasMoreKeys, !isLoadingKeys else { return }
        isLoadingKeys = true
        defer { isLoadingKeys = false }

        do {
            let result = try await service.scanKeys(
                match: searchPattern.isEmpty ? nil : searchPattern,
                count: 100,
                cursor: scanCursor,
                append: true
            )
            keys.append(contentsOf: result.keys.map { RedisKeySummary(key: $0, type: .unknown) })
            scanCursor = result.nextCursor
            hasMoreKeys = result.nextCursor != 0
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    func refreshKeys() async {
        keys = []
        scanCursor = 0
        hasMoreKeys = false
        selectedKey = nil
        selectedKeyDetail = nil
        await loadInitialKeys()
    }

    func searchKeys(_ pattern: String) async {
        guard let service else { return }

        if pattern.isEmpty {
            await refreshKeys()
            return
        }

        isLoadingKeys = true
        defer { isLoadingKeys = false }

        do {
            let foundKeys = try await service.searchKeys(pattern: pattern)
            keys = foundKeys.map { RedisKeySummary(key: $0, type: .unknown) }
            scanCursor = 0
            hasMoreKeys = false
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    func selectKey(_ key: String) {
        selectedKey = key
        Task {
            await loadKeyDetail(key)
            await loadKeyValue(key)
        }
    }

    func loadKeyDetail(_ key: String) async {
        guard let service else { return }
        isLoadingDetail = true
        defer { isLoadingDetail = false }

        do {
            selectedKeyDetail = try await service.getKeyDetail(key)
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    func loadKeyValue(_ key: String) async {
        guard let service, let selectedKeyDetail else { return }
        isLoadingValue = true
        defer { isLoadingValue = false }

        stringValue = nil
        hashValue = [:]
        listValue = []
        setValue = []
        zsetValue = []

        do {
            switch selectedKeyDetail.type {
            case .string:
                stringValue = try await service.getString(key)
            case .hash:
                hashValue = try await service.getHash(key)
            case .list:
                listValue = try await service.getList(key, start: 0, stop: 99)
            case .set:
                setValue = try await service.getSet(key)
            case .zset:
                zsetValue = try await service.getZSet(key, start: 0, stop: 99, withScores: true)
            default:
                break
            }
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    func executeCommand(_ command: String) async {
        guard let service else { return }
        isLoadingCommand = true
        defer { isLoadingCommand = false }

        displayMode = .commandResult

        do {
            commandResult = try await service.executeCommand(command)
        } catch {
            commandResult = RedisCommandResult.error(error.localizedDescription)
        }
    }

    func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
