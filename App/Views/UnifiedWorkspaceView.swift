//
//  UnifiedWorkspaceView.swift
//  cheap-connection
//
//  统一工作区视图 - 提供一致的工作区壳层，支持 MySQL 和 Redis
//

import SwiftUI

/// 统一工作区视图
/// 提供一致的编辑器 + 结果布局，支持 MySQL 和 Redis
/// 对于 MySQL，直接委托给 MySQLWorkspaceView
/// 对于 Redis，使用相同的 SplitView 布局（上下分割）
struct UnifiedWorkspaceView: View {
    let connectionConfig: ConnectionConfig
    let workspaceId: UUID
    @Environment(ConnectionManager.self) var connectionManager

    var body: some View {
        switch connectionConfig.databaseKind {
        case .mysql:
            // MySQL 使用现有的工作区视图
            MySQLWorkspaceView(connectionConfig: connectionConfig, workspaceId: workspaceId)
        case .redis:
            // Redis 使用统一的上下分割布局
            RedisUnifiedWorkspaceView(connectionConfig: connectionConfig, workspaceId: workspaceId)
        }
    }
}

// MARK: - Redis Unified Workspace View

/// Redis 统一工作区视图
/// 使用与 MySQL 相同的上下分割布局（编辑器在上，结果在下）
struct RedisUnifiedWorkspaceView: View {
    let connectionConfig: ConnectionConfig
    let workspaceId: UUID
    @Environment(ConnectionManager.self) var connectionManager

    // State - Service
    @State var service: RedisService?

    // State - Connection
    @State var isConnecting: Bool = false

    // State - Error
    @State var showError: Bool = false
    @State var errorMessage: String = ""

    // State - Command
    @State var commandText: String = ""
    @State var commandHistory: [String] = []
    @State var isExecuting: Bool = false
    @State var lastResult: RedisCommandResult?

    // State - Display
    @State var displayMode: UnifiedDisplayMode = .editorOnly
    @State var editorHeight: CGFloat = WindowStateRepository.shared.load().editorHeight ?? 200

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
        .task { await connectIfNeeded() }
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
            editorView
        } else {
            SplitView(
                topView: AnyView(editorView),
                bottomView: AnyView(resultView),
                topHeight: $editorHeight,
                minTopHeight: 120,
                minBottomHeight: 100
            )
        }
    }

    // MARK: - Editor View

    @ViewBuilder
    private var editorView: some View {
        RedisEditorView(
            commandText: $commandText,
            history: commandHistory,
            serverVersion: service?.session.serverVersion,
            selectedDatabase: service?.session.selectedDatabase,
            onExecute: { command in
                await executeCommand(command)
            },
            onSelectHistory: { commandText = $0 },
            isExecuting: isExecuting
        )
    }

    // MARK: - Result View

    @ViewBuilder
    private var resultView: some View {
        if isExecuting {
            LoadingSQLView()
        } else if let result = lastResult {
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

    // MARK: - Connection Management

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
            let password = try? connectionManager.getPassword(for: connectionConfig.id)
            try await newService.connect(config: connectionConfig, password: password)
        } catch {
            showError(message: error.localizedDescription)
        }
        isConnecting = false
    }

    private func disconnect() async {
        await service?.disconnect()
        service = nil
    }

    // MARK: - Command Execution

    private func executeCommand(_ command: String) async {
        guard let service = service else { return }

        isExecuting = true
        displayMode = .result

        do {
            let result = try await service.executeCommand(command)
            lastResult = result
            // 添加到历史
            if !commandHistory.contains(command) {
                commandHistory.insert(command, at: 0)
                // 限制历史长度
                if commandHistory.count > 100 {
                    commandHistory.removeLast()
                }
            }
        } catch {
            lastResult = RedisCommandResult.error(error.localizedDescription)
        }

        isExecuting = false
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Unified Display Mode

/// 统一工作区显示模式
enum UnifiedDisplayMode {
    /// 仅编辑器
    case editorOnly
    /// 显示结果
    case result
}

// MARK: - Preview

#Preview {
    let mysqlConfig = ConnectionConfig(
        name: "Test MySQL",
        databaseKind: .mysql,
        host: "localhost",
        port: 3306,
        username: "root",
        defaultDatabase: nil
    )

    let redisConfig = ConnectionConfig(
        name: "Test Redis",
        databaseKind: .redis,
        host: "localhost",
        port: 6379,
        username: "",
        defaultDatabase: nil
    )

    return VStack {
        UnifiedWorkspaceView(connectionConfig: mysqlConfig, workspaceId: UUID())
        UnifiedWorkspaceView(connectionConfig: redisConfig, workspaceId: UUID())
    }
}
