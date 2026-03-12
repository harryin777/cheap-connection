//
//  MainView.swift
//  cheap-connection
//
//  主视图 - 应用主界面
//

import SwiftUI

/// 主视图
struct MainView: View {
    @Environment(ConnectionManager.self) private var connectionManager

    var body: some View {
        NavigationSplitView {
            ConnectionListView()
                .frame(minWidth: 260, idealWidth: 300)
        } detail: {
            detailView
        }
        .alert("错误", isPresented: .init(
            get: { connectionManager.errorMessage != nil },
            set: { if !$0 { connectionManager.clearError() } }
        )) {
            Button("确定", role: .cancel) {
                connectionManager.clearError()
            }
        } message: {
            if let error = connectionManager.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Private

    @ViewBuilder
    private var detailView: some View {
        // NOTE: detail 区由 connectionManager.selectedConnectionId 决定
        // 这控制的是左侧资源树高亮连接对应的 workspace 显示
        // Query 执行上下文由 MySQLWorkspaceView 中的 EditorQueryTab 独立管理
        if let selectedId = connectionManager.selectedConnectionId,
           let config = connectionManager.connections.first(where: { $0.id == selectedId }) {
            ConnectionDetailView(config: config)
        } else {
            emptyStateView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("选择一个连接")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("从左侧列表选择一个数据库连接，或创建新连接")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 连接详情视图
struct ConnectionDetailView: View {
    let config: ConnectionConfig

    var body: some View {
        switch config.databaseKind {
        case .mysql:
            MySQLWorkspaceView(connectionConfig: config)
        case .redis:
            RedisWorkspaceView(connectionConfig: config)
        }
    }
}

#Preview {
    MainView()
        .environment(ConnectionManager())
}
