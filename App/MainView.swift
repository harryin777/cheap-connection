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
        // GPT TODO: 当前 detail 区完全由 connectionManager.selectedConnectionId 决定，
        // GPT TODO: 这意味着左侧资源树一旦切换连接，右侧整个工作区就会被强制切换到那个连接。
        // GPT TODO: 用户要求左侧资源树选择和右侧 query 文件上下文解耦：
        // GPT TODO: 1) 左侧树负责“资源浏览/表详情”的当前焦点；
        // GPT TODO: 2) 右侧 query 文件需要维护自己的 queryConnectionId / queryDatabase；
        // GPT TODO: 3) 因此 glm5 需要把“当前打开的工作区连接”与“左侧资源树当前高亮连接”拆成两套状态，
        // GPT TODO:    不能继续让 selectedConnectionId 同时承担 explorer selection 和 query context 两种职责。
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
