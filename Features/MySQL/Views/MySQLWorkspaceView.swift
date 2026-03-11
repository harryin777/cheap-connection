//
//  MySQLWorkspaceView.swift
//  cheap-connection
//
//  MySQL工作区视图 - DataGrip风格布局
//

import SwiftUI
import Combine

/// MySQL工作区标签页
enum MySQLWorkspaceTab: String, CaseIterable {
    case structure = "结构"
    case data = "数据"
    case sql = "SQL"

    var icon: String {
        switch self {
        case .structure: return "tablecells"
        case .data: return "list.bullet"
        case .sql: return "terminal"
        }
    }
}

/// MySQL工作区视图
struct MySQLWorkspaceView: View {
    let connectionConfig: ConnectionConfig

    @Environment(ConnectionManager.self) private var connectionManager

    // State
    @State private var service: MySQLService?
    @State private var databases: [MySQLDatabaseSummary] = []
    @State private var columns: [MySQLColumnDefinition] = []
    @State private var dataResult: MySQLQueryResult?
    @State private var pagination = PaginationState()
    @State private var selectedDatabase: String?
    @State private var selectedTable: String?
    @State private var selectedTab: MySQLWorkspaceTab = .structure
    @State private var sqlText = ""
    @State private var sqlHistory: [String] = []

    // Loading states
    @State private var isLoadingDatabases = false
    @State private var isLoadingStructure = false
    @State private var isLoadingData = false
    @State private var isConnecting = false
    @State private var loadingDatabase: String?

    // Error handling
    @State private var showError = false
    @State private var errorMessage = ""

    // Sorting
    @State private var orderBy: String?
    @State private var orderDirection: OrderDirection = .ascending

    // MARK: - Body

    var body: some View {
        Group {
            if let service = service, service.session.connectionState.isConnected {
                connectedView
            } else if isConnecting {
                connectingView
            } else {
                disconnectedView
            }
        }
        .task {
            await connectIfNeeded()
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedTable) { _, newTable in
            if let table = newTable, let db = selectedDatabase {
                Task {
                    await loadTableStructure(database: db, table: table)
                    await loadTableData(database: db, table: table)
                }
            }
        }
    }

    // MARK: - Subviews

    private var connectedView: some View {
        HSplitView {
            // 左侧：树形侧边栏
            MySQLSidebarView(
                databases: $databases,
                selectedDatabase: selectedDatabase,
                selectedTable: selectedTable,
                onSelectDatabase: { db in
                    selectedDatabase = db
                    selectedTable = nil
                },
                onSelectTable: { db, table in
                    selectedDatabase = db
                    selectedTable = table
                },
                onRefresh: {
                    await loadDatabases()
                },
                onLoadTables: { database in
                    await loadTablesForDatabase(database)
                },
                isLoading: isLoadingDatabases,
                loadingDatabase: loadingDatabase
            )
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

            // 右侧：详情区域
            detailView
                .frame(minWidth: 500)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let table = selectedTable, let db = selectedDatabase {
            VStack(spacing: 0) {
                // 标签栏
                tabBarView

                Divider()

                // 内容区域
                switch selectedTab {
                case .structure:
                    MySQLStructureView(
                        columns: columns,
                        isLoading: isLoadingStructure
                    )

                case .data:
                    MySQLDataView(
                        result: dataResult,
                        pagination: $pagination,
                        isLoading: isLoadingData,
                        onLoadPage: { offset in
                            pagination.page = max(1, (offset / pagination.pageSize) + 1)
                            await loadTableData(database: db, table: table)
                        },
                        onRefresh: {
                            await loadTableData(database: db, table: table)
                        }
                    )

                case .sql:
                    MySQLEditorView(
                        sqlText: $sqlText,
                        history: sqlHistory,
                        onExecute: { sql in
                            await executeSQL(sql)
                        },
                        onSelectHistory: { sql in
                            sqlText = sql
                        }
                    )
                }
            }
        } else if let db = selectedDatabase {
            // 选中了数据库但没选表
            databaseSelectedView(db)
        } else {
            emptySelectionView
        }
    }

    private var tabBarView: some View {
        HStack(spacing: 0) {
            ForEach(MySQLWorkspaceTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(minWidth: 60)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .background(Color(.windowBackgroundColor))
    }

    private func databaseSelectedView(_ database: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "cylinder")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text(database)
                .font(.headline)
                .foregroundStyle(.primary)

            Text("选择一个表以查看详情")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("选择数据库和表")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("从左侧列表中选择数据库，展开后选择表")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("正在连接...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(connectionConfig.name)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var disconnectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("未连接")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("点击连接按钮建立连接")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Button("连接") {
                Task {
                    await connect()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func connectIfNeeded() async {
        guard service == nil else { return }
        await connect()
    }

    private func connect() async {
        isConnecting = true
        defer { isConnecting = false }

        do {
            // Get password from Keychain
            guard let password = try KeychainService.shared.getPassword(for: connectionConfig.id) else {
                throw AppError.authenticationFailed("未找到保存的密码，请重新编辑连接")
            }

            // Create service
            let newService = MySQLService(connectionConfig: connectionConfig)
            try await newService.connect(config: connectionConfig, password: password)
            service = newService

            // Load databases
            await loadDatabases()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func disconnect() async {
        await service?.disconnect()
        service = nil
        databases = []
        columns = []
        dataResult = nil
        selectedDatabase = nil
        selectedTable = nil
    }

    private func loadDatabases() async {
        guard let service = service else { return }

        isLoadingDatabases = true
        defer { isLoadingDatabases = false }

        do {
            databases = try await service.fetchDatabases()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func loadTablesForDatabase(_ database: String) async {
        guard let service = service else { return }

        loadingDatabase = database
        defer { loadingDatabase = nil }

        do {
            let tables = try await service.fetchTables(database: database)

            // 更新对应数据库的表列表
            if let index = databases.firstIndex(where: { $0.name == database }) {
                databases[index].tables = tables
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func loadTableStructure(database: String, table: String) async {
        guard let service = service else { return }

        isLoadingStructure = true
        defer { isLoadingStructure = false }

        do {
            columns = try await service.fetchTableStructure(database: database, table: table)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func loadTableData(database: String, table: String) async {
        guard let service = service else { return }

        isLoadingData = true
        defer { isLoadingData = false }

        do {
            dataResult = try await service.fetchTableData(
                database: database,
                table: table,
                pagination: pagination,
                orderBy: orderBy,
                orderDirection: orderDirection
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func executeSQL(_ sql: String) async {
        guard let service = service else { return }

        // Add to history
        if !sqlHistory.contains(sql) {
            sqlHistory.insert(sql, at: 0)
            if sqlHistory.count > 50 {
                sqlHistory.removeLast()
            }
        }

        do {
            let result = try await service.executeSQL(sql)
            dataResult = result

            if result.isSuccess && !result.hasResults {
                // For non-SELECT queries, refresh table data
                if let db = selectedDatabase, let table = selectedTable {
                    await loadTableData(database: db, table: table)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ConnectionConfig(
        name: "Test MySQL",
        databaseKind: .mysql,
        host: "localhost",
        port: 3306,
        username: "root",
        defaultDatabase: nil
    )

    MySQLWorkspaceView(connectionConfig: config)
        .frame(width: 900, height: 600)
}
