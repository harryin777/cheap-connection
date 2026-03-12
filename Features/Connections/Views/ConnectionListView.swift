//
//  ConnectionListView.swift
//  cheap-connection
//
//  左侧资源树视图 - DataGrip 风格连接/数据库/表导航
//

import SwiftUI

/// 连接列表视图
struct ConnectionListView: View {
    @Environment(ConnectionManager.self) private var connectionManager

    @State private var showingCreateSheet = false
    @State private var editingConnection: ConnectionConfig?
    @State private var deletingConnection: ConnectionConfig?
    @State private var showingDeleteConfirm = false

    @State private var expandedConnectionIds: Set<UUID> = []
    @State private var expandedDatabaseKeys: Set<String> = []
    @State private var expandedFolderKeys: Set<String> = []
    @State private var databasesByConnection: [UUID: [MySQLDatabaseSummary]] = [:]
    @State private var mysqlServices: [UUID: MySQLService] = [:]
    @State private var loadingConnectionIds: Set<UUID> = []
    @State private var loadingDatabaseKeys: Set<String> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if connectionManager.connections.isEmpty {
                    emptyStateView
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
            disconnectAllServices()
        }
        .onChange(of: connectionManager.selectedConnectionId) { _, _ in
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

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            Text("暂无连接")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("点击右上角 + 新建连接")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(.top, 80)
    }

    private func connectionNode(_ config: ConnectionConfig) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                disclosureIcon(
                    isExpanded: expandedConnectionIds.contains(config.id),
                    isVisible: config.databaseKind == .mysql
                )
                .onTapGesture {
                    guard config.databaseKind == .mysql else { return }
                    toggleConnection(config)
                }

                Image(systemName: config.databaseKind == .mysql ? "cylinder.split.1x2" : "memorychip")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(config.databaseKind == .mysql ? .blue : .orange)
                    .frame(width: 14)

                Text(config.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if loadingConnectionIds.contains(config.id) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else if let count = databasesByConnection[config.id]?.count {
                    countBadge("\(count)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(connectionSelectionBackground(for: config))
            .contentShape(Rectangle())
            .onTapGesture {
                selectConnection(config)
            }
            .contextMenu {
                Button {
                    editingConnection = config
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    deletingConnection = config
                    showingDeleteConfirm = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }

            if config.databaseKind == .mysql, expandedConnectionIds.contains(config.id) {
                mysqlConnectionChildren(config)
            }
        }
    }

    @ViewBuilder
    private func mysqlConnectionChildren(_ config: ConnectionConfig) -> some View {
        if loadingConnectionIds.contains(config.id), databasesByConnection[config.id] == nil {
            loadingRow(leading: 30)
        } else if let databases = databasesByConnection[config.id], !databases.isEmpty {
            ForEach(databases) { database in
                databaseNode(database, in: config)
            }
        } else {
            infoRow("无数据库", leading: 30)
        }
    }

    private func databaseNode(_ database: MySQLDatabaseSummary, in config: ConnectionConfig) -> some View {
        let databaseKey = databaseTreeKey(connectionId: config.id, databaseName: database.name)

        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                disclosureIcon(
                    isExpanded: expandedDatabaseKeys.contains(databaseKey),
                    isVisible: true
                )
                .onTapGesture {
                    toggleDatabase(database.name, in: config)
                }

                Image(systemName: database.isSystemDatabase ? "cylinder" : "square.grid.2x2")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(database.isSystemDatabase ? Color.secondary : Color.blue)
                    .frame(width: 14)

                Text(database.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if loadingDatabaseKeys.contains(databaseKey) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else if let count = database.tableCount {
                    countBadge("\(count)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .padding(.leading, 22)
            .background(databaseSelectionBackground(database.name, in: config))
            .contentShape(Rectangle())
            .onTapGesture {
                connectionManager.selectConnection(config.id, database: database.name, table: nil)
            }

            if expandedDatabaseKeys.contains(databaseKey) {
                tablesFolderNode(for: database, in: config)
            }
        }
    }

    @ViewBuilder
    private func tablesFolderNode(for database: MySQLDatabaseSummary, in config: ConnectionConfig) -> some View {
        let databaseKey = databaseTreeKey(connectionId: config.id, databaseName: database.name)
        let folderKey = tablesFolderTreeKey(connectionId: config.id, databaseName: database.name)
        let isExpanded = expandedFolderKeys.contains(folderKey)

        HStack(spacing: 6) {
            disclosureIcon(
                isExpanded: isExpanded,
                isVisible: true
            )
            .onTapGesture {
                toggleTablesFolder(for: database, in: config)
            }

            Image(systemName: "folder")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 14)

            Text("tables")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let count = database.tables?.count ?? database.tableCount {
                countBadge("\(count)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .padding(.leading, 44)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleTablesFolder(for: database, in: config)
        }

        if isExpanded {
            if loadingDatabaseKeys.contains(databaseKey), database.tables == nil {
                loadingRow(leading: 66)
            } else if let tables = database.tables, !tables.isEmpty {
                ForEach(tables) { table in
                    tableRow(table, database: database.name, in: config)
                }
            } else {
                infoRow("无表", leading: 66)
            }
        }
    }

    private func tableRow(_ table: MySQLTableSummary, database: String, in config: ConnectionConfig) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 10)

            Image(systemName: "tablecells")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(table.name)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .padding(.leading, 66)
        .background(tableSelectionBackground(database: database, table: table.name, in: config))
        .contentShape(Rectangle())
        .onTapGesture {
            connectionManager.selectConnection(config.id, database: database, table: table.name)
        }
    }

    private func disclosureIcon(isExpanded: Bool, isVisible: Bool) -> some View {
        Group {
            if isVisible {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Color.clear
            }
        }
        .frame(width: 10, height: 10)
        .contentShape(Rectangle())
    }

    private func countBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
    }

    private func loadingRow(leading: CGFloat) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
            Text("加载中")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, leading)
        .padding(.vertical, 4)
    }

    private func infoRow(_ text: String, leading: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.leading, leading)
            .padding(.vertical, 4)
    }

    private func connectionSelectionBackground(for config: ConnectionConfig) -> Color {
        guard connectionManager.selectedConnectionId == config.id,
              connectionManager.selectedDatabaseName == nil,
              connectionManager.selectedTableName == nil else {
            return .clear
        }

        return Color.accentColor.opacity(0.16)
    }

    private func databaseSelectionBackground(_ database: String, in config: ConnectionConfig) -> Color {
        guard connectionManager.selectedConnectionId == config.id,
              connectionManager.selectedDatabaseName == database,
              connectionManager.selectedTableName == nil else {
            return .clear
        }

        return Color.accentColor.opacity(0.16)
    }

    private func tableSelectionBackground(database: String, table: String, in config: ConnectionConfig) -> Color {
        guard connectionManager.selectedConnectionId == config.id,
              connectionManager.selectedDatabaseName == database,
              connectionManager.selectedTableName == table else {
            return .clear
        }

        return Color.accentColor.opacity(0.16)
    }

    private func selectConnection(_ config: ConnectionConfig) {
        connectionManager.selectConnection(config.id)

        guard config.databaseKind == .mysql else { return }
        expandedConnectionIds.insert(config.id)

        Task {
            await ensureDatabasesLoaded(for: config)
        }
    }

    private func toggleConnection(_ config: ConnectionConfig) {
        if expandedConnectionIds.contains(config.id) {
            expandedConnectionIds.remove(config.id)
            disconnectService(for: config.id)
            return
        }

        expandedConnectionIds.insert(config.id)
        Task {
            await ensureDatabasesLoaded(for: config)
        }
    }

    private func toggleDatabase(_ databaseName: String, in config: ConnectionConfig) {
        let databaseKey = databaseTreeKey(connectionId: config.id, databaseName: databaseName)
        let folderKey = tablesFolderTreeKey(connectionId: config.id, databaseName: databaseName)

        if expandedDatabaseKeys.contains(databaseKey) {
            expandedDatabaseKeys.remove(databaseKey)
            expandedFolderKeys.remove(folderKey)
            return
        }

        expandedDatabaseKeys.insert(databaseKey)
        expandedFolderKeys.insert(folderKey)

        Task {
            await ensureTablesLoaded(for: databaseName, in: config)
        }
    }

    private func toggleTablesFolder(for database: MySQLDatabaseSummary, in config: ConnectionConfig) {
        let folderKey = tablesFolderTreeKey(connectionId: config.id, databaseName: database.name)

        if expandedFolderKeys.contains(folderKey) {
            expandedFolderKeys.remove(folderKey)
            return
        }

        expandedFolderKeys.insert(folderKey)

        Task {
            await ensureTablesLoaded(for: database.name, in: config)
        }
    }

    @MainActor
    private func ensureDatabasesLoaded(for config: ConnectionConfig) async {
        guard config.databaseKind == .mysql else { return }
        if databasesByConnection[config.id] != nil { return }
        if loadingConnectionIds.contains(config.id) { return }

        loadingConnectionIds.insert(config.id)
        defer { loadingConnectionIds.remove(config.id) }

        do {
            let service = try await mysqlService(for: config)
            let databases = try await service.fetchDatabases()
                .sorted {
                    if $0.isSystemDatabase != $1.isSystemDatabase {
                        return !$0.isSystemDatabase
                    }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            databasesByConnection[config.id] = databases
        } catch {
            connectionManager.errorMessage = "加载数据库失败: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func ensureTablesLoaded(for databaseName: String, in config: ConnectionConfig) async {
        guard config.databaseKind == .mysql else { return }

        let databaseKey = databaseTreeKey(connectionId: config.id, databaseName: databaseName)
        if loadingDatabaseKeys.contains(databaseKey) { return }

        if let databases = databasesByConnection[config.id],
           let database = databases.first(where: { $0.name == databaseName }),
           database.tables != nil {
            return
        }

        loadingDatabaseKeys.insert(databaseKey)
        defer { loadingDatabaseKeys.remove(databaseKey) }

        do {
            let service = try await mysqlService(for: config)
            let tables = try await service.fetchTables(database: databaseName)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            updateTables(tables, for: databaseName, connectionId: config.id)
        } catch {
            connectionManager.errorMessage = "加载表失败: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func mysqlService(for config: ConnectionConfig) async throws -> MySQLService {
        if let service = mysqlServices[config.id], service.session.connectionState.isConnected {
            return service
        }

        guard let password = try connectionManager.getPassword(for: config.id), !password.isEmpty else {
            throw AppError.authenticationFailed("未找到保存的密码，请重新编辑连接")
        }

        let service = mysqlServices[config.id] ?? MySQLService(connectionConfig: config)
        try await service.connect(config: config, password: password)
        mysqlServices[config.id] = service
        return service
    }

    private func updateTables(_ tables: [MySQLTableSummary], for databaseName: String, connectionId: UUID) {
        guard var databases = databasesByConnection[connectionId],
              let index = databases.firstIndex(where: { $0.name == databaseName }) else {
            return
        }

        databases[index].tables = tables
        databasesByConnection[connectionId] = databases
    }

    private func autoExpandSelectedConnection() {
        guard let selectedConnectionId = connectionManager.selectedConnectionId,
              let config = connectionManager.connections.first(where: { $0.id == selectedConnectionId }),
              config.databaseKind == .mysql else {
            return
        }

        expandedConnectionIds.insert(selectedConnectionId)
        Task {
            await ensureDatabasesLoaded(for: config)
        }
    }

    private func disconnectService(for connectionId: UUID) {
        guard let service = mysqlServices.removeValue(forKey: connectionId) else { return }

        Task {
            await service.disconnect()
        }
    }

    private func disconnectAllServices() {
        let services = Array(mysqlServices.values)
        mysqlServices.removeAll()

        Task {
            for service in services {
                await service.disconnect()
            }
        }
    }

    private func databaseTreeKey(connectionId: UUID, databaseName: String) -> String {
        "\(connectionId.uuidString)::\(databaseName)"
    }

    private func tablesFolderTreeKey(connectionId: UUID, databaseName: String) -> String {
        "\(connectionId.uuidString)::\(databaseName)::tables"
    }

    private func deleteConnection(_ config: ConnectionConfig) {
        disconnectService(for: config.id)
        databasesByConnection.removeValue(forKey: config.id)
        expandedConnectionIds.remove(config.id)

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
