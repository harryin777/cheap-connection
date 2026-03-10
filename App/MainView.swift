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
                .frame(minWidth: 200)
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

/// 连接详情视图（占位）
struct ConnectionDetailView: View {
    let config: ConnectionConfig

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: config.databaseKind.iconName)
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text(config.name)
                .font(.title)

            VStack(spacing: 8) {
                Text(config.connectionDescription)
                    .foregroundStyle(.secondary)

                if let db = config.defaultDatabase {
                    Text("数据库: \(db)")
                        .foregroundStyle(.tertiary)
                }
            }

            Text("连接功能开发中...")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainView()
        .environment(ConnectionManager())
}
