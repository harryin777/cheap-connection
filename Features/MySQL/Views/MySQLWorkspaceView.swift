//
//  MySQLWorkspaceView.swift
//  cheap-connection
//
//  MySQL工作区视图 - 只负责连接管理，右侧面板完全独立
//

import SwiftUI

// MARK: - MySQLWorkspaceView

/// MySQL工作区视图
/// 只负责连接管理，右侧面板通过 MySQLRightPanelView 完全独立运行
struct MySQLWorkspaceView: View {
    let connectionConfig: ConnectionConfig
    let workspaceId: UUID
    @Environment(ConnectionManager.self) var connectionManager

    // State - Service & Data (仅用于连接管理)
    @State var service: MySQLService?
    @State var databases: [MySQLDatabaseSummary] = []
    @State var isLoadingDatabases = false

    // State - Connection
    @State var isConnecting = false

    // State - Error
    @State var showError = false
    @State var errorMessage = ""

    // State - Task Management
    @State var pendingTasks: [UUID: Task<Void, Never>] = [:]
    @State var isWorkspaceClosing = false

    var body: some View {
        Group {
            if let service, service.session.connectionState.isConnected {
                // 连接成功，显示独立的右侧面板
                MySQLRightPanelView(
                    connectionConfig: connectionConfig,
                    workspaceId: workspaceId,
                    service: service
                )
            } else if isConnecting {
                ConnectingView(connectionName: connectionConfig.name)
            } else {
                DisconnectedView(connectionName: connectionConfig.name) {
                    await connect()
                }
            }
        }
        .onAppear {
            enqueuePendingTask {
                await connectIfNeeded()
            }
        }
        .onDisappear {
            guard !isWorkspaceClosing else { return }
            isWorkspaceClosing = true
            Task {
                await cancelPendingTasksAndWait()
                await disconnect()
            }
        }
        // 监听工作区关闭通知
        .onReceive(NotificationCenter.default.publisher(for: .workspaceWillClose)) { notification in
            guard let closingWorkspaceId = notification.object as? UUID,
                  closingWorkspaceId == workspaceId,
                  !isWorkspaceClosing else { return }
            isWorkspaceClosing = true
            Task {
                await cancelPendingTasksAndWait()
                await disconnect()
                // 断连完成后通知 WorkspaceManager
                await MainActor.run {
                    connectionManager.workspaceManager.notifyDisconnectComplete(workspaceId)
                }
            }
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    @MainActor
    func enqueuePendingTask(_ operation: @escaping @Sendable () async -> Void) {
        guard !isWorkspaceClosing else { return }
        let taskId = UUID()
        let task = Task {
            await operation()
            await MainActor.run {
                pendingTasks[taskId] = nil
            }
        }
        pendingTasks[taskId] = task
    }

    @MainActor
    func cancelPendingTasksAndWait() async {
        let tasks = Array(pendingTasks.values)
        pendingTasks.removeAll()

        for task in tasks {
            task.cancel()
        }

        for task in tasks {
            await task.value
        }
    }
}

#Preview {
    let config = ConnectionConfig(
        name: "Test MySQL",
        databaseKind: .mysql,
        host: "localhost",
        port: 3306,
        username: "root",
        defaultDatabase: nil
    )
    MySQLWorkspaceView(connectionConfig: config, workspaceId: UUID()).frame(width: 900, height: 600)
}
