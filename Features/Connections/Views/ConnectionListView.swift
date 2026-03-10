//
//  ConnectionListView.swift
//  cheap-connection
//
//  连接列表视图
//

import SwiftUI

/// 连接列表视图
struct ConnectionListView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @State private var selection: UUID?

    @State private var showingCreateSheet = false
    @State private var editingConnection: ConnectionConfig?
    @State private var deletingConnection: ConnectionConfig?
    @State private var showingDeleteConfirm = false

    var body: some View {
        List(selection: $selection) {
            // 最近连接
            if !connectionManager.recentConnections.isEmpty {
                Section("最近使用") {
                    ForEach(recentConnectionConfigs) { config in
                        connectionRow(config)
                    }
                }
            }

            // 所有连接
            Section("所有连接") {
                ForEach(connectionManager.connections) { config in
                    connectionRow(config)
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selection) {
            connectionManager.selectedConnectionId = selection
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("新建连接")
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                ConnectionFormView()
            }
        }
        .sheet(item: $editingConnection) { config in
            NavigationStack {
                ConnectionFormView(config: config)
            }
        }
        .confirmationDialog(
            "确认删除",
            isPresented: $showingDeleteConfirm,
            presenting: deletingConnection
        ) { config in
            Button("删除", role: .destructive) {
                deleteConnection(config)
            }
        } message: { config in
            Text("确定要删除连接「\(config.name)」吗？\n此操作无法撤销。")
        }
        .onAppear {
            connectionManager.loadConnections()
        }
    }

    // MARK: - Private

    @ViewBuilder
    private func connectionRow(_ config: ConnectionConfig) -> some View {
        ConnectionRowView(
            config: config,
            isSelected: connectionManager.selectedConnectionId == config.id,
            onSelect: {
                connectionManager.selectedConnectionId = config.id
            },
            onEdit: {
                editingConnection = config
            },
            onDelete: {
                deletingConnection = config
                showingDeleteConfirm = true
            }
        )
    }

    private var recentConnectionConfigs: [ConnectionConfig] {
        let recentIds = Set(connectionManager.recentConnections.map(\.connectionId))
        return connectionManager.connections.filter { recentIds.contains($0.id) }
    }

    private func deleteConnection(_ config: ConnectionConfig) {
        do {
            try connectionManager.deleteConnection(id: config.id)
        } catch {
            connectionManager.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationSplitView {
        ConnectionListView()
            .environment(ConnectionManager())
    } detail: {
        Text("选择一个连接")
    }
}
