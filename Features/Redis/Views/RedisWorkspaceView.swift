//
//  RedisWorkspaceView.swift
//  cheap-connection
//
//  Redis 工作区视图 - DataGrip 风格布局（与 MySQL 一致）
//

import SwiftUI
import AppKit

// MARK: - Redis Workspace Enums

/// Redis 工作区标签页（Key 浏览 和 命令结果）
enum RedisDetailTab: String, CaseIterable {
    case keys = "Key 浏览"
    case result = "命令结果"

    var icon: String {
        switch self {
        case .keys: return "key"
        case .result: return "terminal"
        }
    }
}

/// 工作区显示模式 - 互斥状态
enum RedisDisplayMode: Equatable {
    /// 默认编辑态：只展示命令编辑内容
    case editorOnly
    /// 命令结果态：执行命令后显示结果面板
    case commandResult
    /// Key 详情态：选择 Key 后显示 Key 浏览面板
    case keyDetail(RedisDetailTab)
}

/// Redis 工作区视图
struct RedisWorkspaceView: View {
    let connectionConfig: ConnectionConfig
    let workspaceId: UUID
    @Environment(ConnectionManager.self) var connectionManager

    // State - Service
    @State var service: RedisService?

    // State - Key List
    @State var keys: [RedisKeySummary] = []
    @State var searchPattern: String = ""
    @State var scanCursor: Int = 0
    @State var hasMoreKeys: Bool = false
    @State var isLoadingKeys: Bool = false

    // State - Key Detail
    @State var selectedKey: String?
    @State var selectedKeyDetail: RedisKeyDetail?
    @State var isLoadingDetail: Bool = false

    // State - Value
    @State var stringValue: String?
    @State var hashValue: [String: String] = [:]
    @State var listValue: [String] = []
    @State var setValue: [String] = []
    @State var zsetValue: [RedisZSetMember] = []
    @State var isLoadingValue: Bool = false

    // State - Command
    @State var commandText = ""
    @State var commandResult: RedisCommandResult?
    @State var isLoadingCommand = false

    // State - Connection
    @State var isConnecting: Bool = false

    // State - Display Mode
    @State var displayMode: RedisDisplayMode = .editorOnly
    @State var selectedTab: RedisDetailTab = .keys

    // State - Splitter
    @State var editorHeight: CGFloat = WindowStateRepository.shared.load().editorHeight ?? 200

    // State - Error
    @State var showError: Bool = false
    @State var errorMessage: String = ""

    // State - Sidebar Width (for key browser)
    @State var sidebarWidth: CGFloat = 280

    var body: some View {
        Group {
            if let service, service.session.connectionState.isConnected {
                connectedView
            } else if isConnecting {
                ConnectingView(connectionName: connectionConfig.name)
            } else {
                DisconnectedView(connectionName: connectionConfig.name) {
                    await connect()
                }
            }
        }
        .onAppear {
            Task { await connectIfNeeded() }
        }
        // 监听工作区关闭通知
        .onReceive(NotificationCenter.default.publisher(for: .workspaceWillClose)) { notification in
            guard let closingWorkspaceId = notification.object as? UUID,
                  closingWorkspaceId == workspaceId else { return }
            Task {
                await disconnect()
                await MainActor.run {
                    connectionManager.workspaceManager.notifyDisconnectComplete(workspaceId)
                }
            }
        }
        .onChange(of: editorHeight) { _, newHeight in
            var state = WindowStateRepository.shared.load()
            state.editorHeight = newHeight
            WindowStateRepository.shared.save(state)
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Connected View

    @ViewBuilder
    var connectedView: some View {
        if displayMode == .editorOnly {
            // 纯编辑器模式 - 不需要分割
            RedisEditorView(
                commandText: $commandText,
                history: service?.session.commandHistory ?? [],
                serverVersion: service?.session.serverVersion,
                selectedDatabase: service?.session.selectedDatabase,
                onExecute: { command in
                    await executeCommand(command)
                },
                onSelectHistory: { commandText = $0 },
                isExecuting: isLoadingCommand,
                activeWorkspaceTab: nil,
                onSelectWorkspaceTab: { tab in
                    selectedTab = tab
                    displayMode = .keyDetail(tab)
                }
            )
        } else {
            // 使用原生 NSSplitView 避免拖拽闪烁
            SplitView(
                topView: AnyView(
                    RedisEditorView(
                        commandText: $commandText,
                        history: service?.session.commandHistory ?? [],
                        serverVersion: service?.session.serverVersion,
                        selectedDatabase: service?.session.selectedDatabase,
                        onExecute: { command in
                            await executeCommand(command)
                        },
                        onSelectHistory: { commandText = $0 },
                        isExecuting: isLoadingCommand,
                        activeWorkspaceTab: selectedTab,
                        onSelectWorkspaceTab: { tab in
                            selectedTab = tab
                            displayMode = .keyDetail(tab)
                        }
                    )
                ),
                bottomView: AnyView(
                    bottomContentView
                ),
                topHeight: $editorHeight,
                minTopHeight: 120,
                minBottomHeight: 100
            )
        }
    }

    @ViewBuilder
    private var bottomContentView: some View {
        switch displayMode {
        case .editorOnly:
            EmptyView()
        case .commandResult:
            commandResultView
        case .keyDetail:
            keyDetailView
        }
    }

    // MARK: - Command Result View

    @ViewBuilder
    private var commandResultView: some View {
        if isLoadingCommand {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("执行中...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let result = commandResult {
            RedisCommandResultView(result: result)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "terminal")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)

                Text("命令结果")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("输入命令后点击执行查看结果")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Key Detail View

    @ViewBuilder
    private var keyDetailView: some View {
        switch selectedTab {
        case .keys:
            keyBrowserView
        case .result:
            commandResultView
        }
    }

    @ViewBuilder
    private var keyBrowserView: some View {
        HSplitView {
            // 左侧: Key 列表
            RedisKeyListView(
                keys: keys,
                selectedKey: selectedKey,
                searchPattern: $searchPattern,
                hasMoreKeys: hasMoreKeys,
                isLoading: isLoadingKeys,
                onSelectKey: { key in selectKey(key) },
                onLoadMore: { await loadMoreKeys() },
                onRefresh: { await refreshKeys() },
                onSearch: { await searchKeys($0) }
            )
            .frame(minWidth: 200, idealWidth: sidebarWidth, maxWidth: 400)

            // 右侧: Key 详情和值展示
            keyValueDetailView
                .frame(minWidth: 400)
        }
    }

    // MARK: - Key Value Detail View

    @ViewBuilder
    private var keyValueDetailView: some View {
        if selectedKey != nil {
            VStack(spacing: 0) {
                // Key 详情头部
                if let detail = selectedKeyDetail {
                    RedisKeyDetailHeaderView(detail: detail)
                    Divider()
                }

                // 值展示区域
                valueView
            }
        } else if isLoadingDetail {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("加载中...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // 空状态
            VStack(spacing: 16) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)

                Text("选择一个 Key")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("从左侧列表选择一个 key 查看详情")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Value View

    @ViewBuilder
    private var valueView: some View {
        if isLoadingValue {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("加载值...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail = selectedKeyDetail {
            switch detail.type {
            case .string:
                RedisStringValueView(value: stringValue)
            case .hash:
                RedisHashValueView(value: hashValue)
            case .list:
                RedisListValueView(value: listValue)
            case .set:
                RedisSetValueView(value: setValue)
            case .zset:
                RedisZSetValueView(value: zsetValue)
            case .none:
                Text("Key 不存在")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                Text("不支持的类型: \(detail.type.displayName)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Actions

    private func connectIfNeeded() async {
        if service?.session.connectionState.isConnected != true {
            await connect()
        }
    }

    private func connect() async {
        isConnecting = true

        let newService = RedisService(connectionConfig: connectionConfig)
        service = newService

        do {
            let password = try? ConnectionManager.shared.getPassword(for: connectionConfig.id)
            try await newService.connect(config: connectionConfig, password: password)
            await loadInitialKeys()
        } catch {
            showError(message: error.localizedDescription)
        }

        isConnecting = false
    }

    private func disconnect() async {
        await service?.disconnect()
        service = nil
    }

    private func loadInitialKeys() async {
        guard let service else { return }

        isLoadingKeys = true

        do {
            let result = try await service.scanKeys(match: nil, count: 100, cursor: 0, append: false)
            keys = result.keys.map { RedisKeySummary(key: $0, type: .unknown) }
            scanCursor = result.nextCursor
            hasMoreKeys = result.nextCursor != 0
        } catch {
            showError(message: error.localizedDescription)
        }

        isLoadingKeys = false
    }

    private func loadMoreKeys() async {
        guard let service, hasMoreKeys, !isLoadingKeys else { return }

        isLoadingKeys = true

        do {
            let result = try await service.scanKeys(
                match: searchPattern.isEmpty ? nil : searchPattern,
                count: 100,
                cursor: scanCursor,
                append: true
            )
            let newKeys = result.keys.map { RedisKeySummary(key: $0, type: .unknown) }
            keys.append(contentsOf: newKeys)
            scanCursor = result.nextCursor
            hasMoreKeys = result.nextCursor != 0
        } catch {
            showError(message: error.localizedDescription)
        }

        isLoadingKeys = false
    }

    private func refreshKeys() async {
        keys = []
        scanCursor = 0
        hasMoreKeys = false
        selectedKey = nil
        selectedKeyDetail = nil
        await loadInitialKeys()
    }

    private func searchKeys(_ pattern: String) async {
        guard let service else { return }

        if pattern.isEmpty {
            await refreshKeys()
            return
        }

        isLoadingKeys = true

        do {
            let foundKeys = try await service.searchKeys(pattern: pattern)
            keys = foundKeys.map { RedisKeySummary(key: $0, type: .unknown) }
            scanCursor = 0
            hasMoreKeys = false
        } catch {
            showError(message: error.localizedDescription)
        }

        isLoadingKeys = false
    }

    private func selectKey(_ key: String) {
        selectedKey = key
        Task {
            await loadKeyDetail(key)
            await loadKeyValue(key)
        }
    }

    private func loadKeyDetail(_ key: String) async {
        guard let service else { return }

        isLoadingDetail = true

        do {
            selectedKeyDetail = try await service.getKeyDetail(key)
        } catch {
            showError(message: error.localizedDescription)
        }

        isLoadingDetail = false
    }

    private func loadKeyValue(_ key: String) async {
        guard let service, let detail = selectedKeyDetail else { return }

        isLoadingValue = true

        // 重置所有值
        stringValue = nil
        hashValue = [:]
        listValue = []
        setValue = []
        zsetValue = []

        do {
            switch detail.type {
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

        isLoadingValue = false
    }

    private func executeCommand(_ command: String) async {
        guard let service else { return }

        isLoadingCommand = true
        displayMode = .commandResult

        do {
            let result = try await service.executeCommand(command)
            commandResult = result
        } catch {
            commandResult = RedisCommandResult.error(error.localizedDescription)
        }

        isLoadingCommand = false
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

#Preview {
    let config = ConnectionConfig(
        name: "Test Redis",
        databaseKind: .redis,
        host: "localhost",
        port: 6379,
        username: "",
        defaultDatabase: nil
    )

    RedisWorkspaceView(connectionConfig: config, workspaceId: UUID())
        .frame(width: 900, height: 600)
}
