//
//  ConnectionListView.swift
//  cheap-connection
//
//  左侧资源树视图 - DataGrip 风格连接/数据库/表导航
//

import SwiftUI

/// 连接列表视图
struct ConnectionListView: View {
    @Environment(ConnectionManager.self) var connectionManager
    @StateObject var dataLoader = ConnectionListDataLoader()

    @State var showingCreateSheet = false
    @State var editingConnection: ConnectionConfig?
    @State var deletingConnection: ConnectionConfig?
    @State var showingDeleteConfirm = false

    @State var expandedConnectionIds: Set<UUID> = []
    @State var expandedDatabaseKeys: Set<String> = []
    @State var expandedFolderKeys: Set<String> = []
    @State var browserSelectedConnectionId: UUID?
    @State var browserSelectedDatabaseName: String?
    @State var browserSelectedTableName: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if connectionManager.connections.isEmpty {
                    ConnectionListEmptyStateView()
                } else {
                    ForEach(connectionManager.connections) { config in
                        connectionNode(config)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            connectionManager.loadConnections()
            autoExpandSelectedConnection()
        }
        .onDisappear {
            dataLoader.disconnectAllServices()
        }
        .onChange(of: browserSelectedConnectionId) { _, _ in
            autoExpandSelectedConnection()
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
    }

    // MARK: - Connection Node

    private func connectionNode(_ config: ConnectionConfig) -> some View {
        VStack(spacing: 0) {
            ConnectionListNodeView(
                config: config,
                isExpanded: expandedConnectionIds.contains(config.id),
                isLoading: dataLoader.loadingConnectionIds.contains(config.id),
                databaseCount: dataLoader.databasesByConnection[config.id]?.count,
                isSelected: isConnectionSelected(config)
            ) {
                toggleConnection(config)
            } onSelect: {
                // 单击只更新左侧资源树高亮与展开，不创建也不切换右侧工作区
                selectConnection(config)
            } onDoubleClick: {
                // 双击与单击语义保持一致：左侧只是资源树，不承担右侧工作区路由
                selectConnection(config)
            } onEdit: {
                editingConnection = config
            } onDelete: {
                deletingConnection = config
                showingDeleteConfirm = true
            }

            if config.databaseKind == .mysql, expandedConnectionIds.contains(config.id) {
                mysqlConnectionChildren(config)
            }
        }
    }

    @ViewBuilder
    private func mysqlConnectionChildren(_ config: ConnectionConfig) -> some View {
        if dataLoader.loadingConnectionIds.contains(config.id),
           dataLoader.databasesByConnection[config.id] == nil {
            ConnectionListLoadingRow(leading: 30)
        } else if let databases = dataLoader.databasesByConnection[config.id], !databases.isEmpty {
            ForEach(databases) { database in
                databaseNode(database, in: config)
            }
        } else {
            ConnectionListInfoRow(text: "无数据库", leading: 30)
        }
    }

    // MARK: - Database Node

    private func databaseNode(_ database: MySQLDatabaseSummary, in config: ConnectionConfig) -> some View {
        let databaseKey = ConnectionListTreeKeys.databaseKey(connectionId: config.id, databaseName: database.name)

        return VStack(spacing: 0) {
            ConnectionListDatabaseNodeView(
                database: database,
                databaseKey: databaseKey,
                isExpanded: expandedDatabaseKeys.contains(databaseKey),
                isLoading: dataLoader.loadingDatabaseKeys.contains(databaseKey),
                isSelected: isDatabaseSelected(database.name, in: config),
                leading: 22
            ) {
                toggleDatabase(database.name, in: config)
            } onSelect: {
                updateBrowserSelection(connectionId: config.id, database: database.name, table: nil)
            }

            if expandedDatabaseKeys.contains(databaseKey) {
                tablesFolderNode(for: database, in: config)
            }
        }
    }

    // MARK: - Tables Folder Node

    @ViewBuilder
    private func tablesFolderNode(for database: MySQLDatabaseSummary, in config: ConnectionConfig) -> some View {
        let databaseKey = ConnectionListTreeKeys.databaseKey(connectionId: config.id, databaseName: database.name)
        let folderKey = ConnectionListTreeKeys.tablesFolderKey(connectionId: config.id, databaseName: database.name)
        let isExpanded = expandedFolderKeys.contains(folderKey)

        ConnectionListTablesFolderView(
            database: database,
            isExpanded: isExpanded,
            isLoading: dataLoader.loadingDatabaseKeys.contains(databaseKey),
            tablesCount: database.tables?.count ?? database.tableCount,
            leading: 44
        ) {
            toggleTablesFolder(for: database, in: config)
        }

        if isExpanded {
            if dataLoader.loadingDatabaseKeys.contains(databaseKey), database.tables == nil {
                ConnectionListLoadingRow(leading: 66)
            } else if let tables = database.tables, !tables.isEmpty {
                ForEach(tables) { table in
                    tableRow(table, database: database.name, in: config)
                }
            } else if database.tables == nil && (database.tableCount ?? 0) > 0 {
                // Cache lost but database has tables - show loading hint instead of "无表"
                ConnectionListLoadingRow(leading: 66)
            } else {
                ConnectionListInfoRow(text: "无表", leading: 66)
            }
        }
    }

    // MARK: - Table Row

    private func tableRow(_ table: MySQLTableSummary, database: String, in config: ConnectionConfig) -> some View {
        ConnectionListTableRowView(
            table: table,
            isSelected: isTableSelected(database: database, table: table.name, in: config),
            leading: 66
        ) {
            // 单击：只更新左侧资源树高亮
            updateBrowserSelection(connectionId: config.id, database: database, table: table.name)
        } onDoubleClick: {
            // 双击：更新左侧高亮并发送通知让右侧面板显示表数据
            updateBrowserSelection(connectionId: config.id, database: database, table: table.name)
            let info = TableDoubleClickInfo(
                connectionId: config.id,
                database: database,
                table: table.name
            )
            NotificationCenter.default.post(
                name: .tableDoubleClicked,
                object: info
            )
        }
    }

    func updateBrowserSelection(connectionId: UUID?, database: String?, table: String?) {
        browserSelectedConnectionId = connectionId
        browserSelectedDatabaseName = database
        browserSelectedTableName = table
    }

}

#Preview {
    NavigationSplitView {
        ConnectionListView()
            .environment(ConnectionManager.shared)
    } detail: {
        Text("选择一个连接")
    }
}
