//
//  MySQLWorkspaceView.swift
//  cheap-connection
//
//  MySQL工作区视图 - DataGrip风格布局
//

import SwiftUI

// MARK: - MySQLWorkspaceView

/// MySQL工作区视图
struct MySQLWorkspaceView: View {
    let connectionConfig: ConnectionConfig
    let workspaceId: UUID
    @Environment(ConnectionManager.self) var connectionManager

    // State - Service & Data
    // 注意：service 虽然挂在 View 的 @State 上，但在 workspace 切换时，
    // WorkspaceManager 会通过 closeWorkspaceAndWait 先发送 workspaceWillClose 通知，
    // 让 View 正确执行 disconnect 并等待完成，然后再销毁 View。
    @State var service: MySQLService?
    @State var databases: [MySQLDatabaseSummary] = []
    @State var columns: [MySQLColumnDefinition] = []
    @State var sqlResult: MySQLQueryResult?
    @State var tableDataResult: MySQLQueryResult?
    @State var pagination = PaginationState()

    // State - Selection
    @State var selectedDatabase: String?
    @State var selectedTable: String?
    @State var selectedTab: MySQLDetailTab = .data
    @State var displayMode: WorkspaceDisplayMode = .editorOnly

    // State - Query Context
    @State var connectionDatabaseCache: [UUID: [String]] = [:]
    @State var scratchQueryConnectionId: UUID?
    @State var scratchQueryConnectionName: String?
    @State var scratchQueryDatabaseName: String?
    @State var editorTabs: [EditorQueryTab] = []
    @State var activeEditorTabId: UUID?
    @State var sqlText = ""
    @State var sqlHistory: [String] = []

    // State - Loading
    @State var isLoadingDatabases = false
    @State var isLoadingStructure = false
    @State var isLoadingData = false
    @State var isLoadingSQL = false
    @State var isConnecting = false

    // State - Error
    @State var showError = false
    @State var errorMessage = ""

    // State - Sorting
    @State var orderBy: String?
    @State var orderDirection: OrderDirection = .ascending

    // State - Import
    @State var showImportProgress = false
    @State var importProgress: Double = 0
    @State var importStatus = ""
    @State var importResult: SQLImportResult?
    @State var showImportResult = false

    // State - Splitter
    @State var editorHeight: CGFloat = WindowStateRepository.shared.load().editorHeight ?? 200

    // State - Task Management (用于取消未完成的 Task)
    @State var pendingTasks: [UUID: Task<Void, Never>] = [:]
    @State var isWorkspaceClosing = false

    // State - Autocomplete Metadata (独立于侧边栏选择)
    @State var queryTables: [MySQLTableSummary] = []
    @State var queryAllColumns: [MySQLColumnDefinition] = []
    @State var isLoadingQueryMetadata = false

    var currentDatabaseTables: [MySQLTableSummary] {
        guard let dbName = selectedDatabase,
              let db = databases.first(where: { $0.name == dbName }),
              let tables = db.tables else { return [] }
        return tables
    }

    var activeQueryTab: EditorQueryTab? {
        guard let tabId = activeEditorTabId else { return nil }
        return editorTabs.first(where: { $0.id == tabId })
    }

    var currentQueryConnectionId: UUID {
        activeQueryTab?.queryConnectionId ?? scratchQueryConnectionId ?? connectionConfig.id
    }

    var currentQueryConnectionName: String {
        activeQueryTab?.queryConnectionName ?? scratchQueryConnectionName ?? connectionConfig.name
    }

    var currentQueryDatabase: String? {
        activeQueryTab?.queryDatabaseName ?? scratchQueryDatabaseName
    }

    var queryDatabaseOptions: [String] {
        // 统一从 connectionDatabaseCache 获取，不再借用左侧资源树的 databases 数据
        // 这样右侧 schema menu 的选项完全独立于左侧树当前展开的连接
        return connectionDatabaseCache[currentQueryConnectionId]?.sorted() ?? []
    }

    var availableConnections: [ConnectionConfig] {
        connectionManager.connections.filter { $0.databaseKind == .mysql }
    }

    /// 自动补全使用的表列表（只使用查询上下文的表，不回退到侧边栏）
    var autocompleteTables: [MySQLTableSummary] {
        // 不再 fallback 到 currentDatabaseTables，让 query context 完全独立
        // 这样可以明确区分”元数据未加载”和”没有匹配项”
        return queryTables
    }

    /// 自动补全使用的列列表（只使用查询上下文的列，不回退到侧边栏）
    var autocompleteColumns: [MySQLColumnDefinition] {
        // 不再 fallback 到 columns，让 query context 完全独立
        return queryAllColumns
    }

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
            enqueuePendingTask {
                await connectIfNeeded()
            }
        }
        // 监听工作区关闭通知，只在显式关闭时断连
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
        .onChange(of: connectionManager.selectedDatabaseName) { _, _ in syncSelectionFromManager() }
        .onChange(of: connectionManager.selectedTableName) { _, _ in syncSelectionFromManager() }
        .onChange(of: selectedDatabase) { _, newDatabase in syncDatabaseToManager(newDatabase) }
        .onChange(of: selectedTable) { _, newTable in handleTableSelection(newTable) }
        .onChange(of: sqlText) { _, _ in syncSQLTextToActiveTab() }
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
        .alert("导入进度", isPresented: $showImportProgress) {
            Button("取消", role: .cancel) { }
        } message: {
            Text(importStatus)
        }
        .alert("导入结果", isPresented: $showImportResult) {
            Button("确定", role: .cancel) {
                importResult = nil
            }
        } message: {
            if let importResult {
                Text(importResult.summary)
            } else {
                Text("导入完成")
            }
        }
    }

    @ViewBuilder
    var connectedView: some View {
        if displayMode == .editorOnly {
            // 纯编辑器模式 - 不需要分割
            MySQLEditorView(
                sqlText: $sqlText,
                history: sqlHistory,
                queryConnectionId: currentQueryConnectionId,
                queryConnectionName: currentQueryConnectionName,
                availableConnections: availableConnections,
                queryDatabases: queryDatabaseOptions,
                selectedQueryDatabase: currentQueryDatabase,
                onSwitchQueryConnection: { switchQueryConnection($0) },
                onSelectQueryDatabase: { updateQueryDatabase($0) },
                onExecute: { sql in
                    enqueuePendingTask {
                        await executeSQL(sql)
                    }
                },
                onSelectHistory: { sqlText = $0 },
                isExecuting: isLoadingSQL,
                activeWorkspaceTab: nil,
                onSelectWorkspaceTab: { tab in
                    selectedTab = tab
                    displayMode = .tableDetail(tab)
                },
                onImport: { await importSQLFile() },
                onOpenFile: { await openSQLFile() },
                onCloseTab: { closeActiveEditorTab() },
                onSaveFile: { saveSQLFile() },
                tables: autocompleteTables,
                columns: autocompleteColumns,
                editorTabs: editorTabs,
                activeEditorTabId: activeEditorTabId,
                onSelectEditorTab: { selectEditorTab($0) },
                onCloseEditorTab: { closeEditorTab($0) }
            )
        } else {
            // 使用原生 NSSplitView 避免拖拽闪烁
            SplitView(
                topView: AnyView(
                    MySQLEditorView(
                        sqlText: $sqlText,
                        history: sqlHistory,
                        queryConnectionId: currentQueryConnectionId,
                        queryConnectionName: currentQueryConnectionName,
                        availableConnections: availableConnections,
                        queryDatabases: queryDatabaseOptions,
                        selectedQueryDatabase: currentQueryDatabase,
                        onSwitchQueryConnection: { switchQueryConnection($0) },
                        onSelectQueryDatabase: { updateQueryDatabase($0) },
                        onExecute: { sql in
                            enqueuePendingTask {
                                await executeSQL(sql)
                            }
                        },
                        onSelectHistory: { sqlText = $0 },
                        isExecuting: isLoadingSQL,
                        activeWorkspaceTab: selectedTab,
                        onSelectWorkspaceTab: { tab in
                            selectedTab = tab
                            displayMode = .tableDetail(tab)
                        },
                        onImport: { await importSQLFile() },
                        onOpenFile: { await openSQLFile() },
                        onCloseTab: { closeActiveEditorTab() },
                        onSaveFile: { saveSQLFile() },
                        tables: autocompleteTables,
                        columns: autocompleteColumns,
                        editorTabs: editorTabs,
                        activeEditorTabId: activeEditorTabId,
                        onSelectEditorTab: { selectEditorTab($0) },
                        onCloseEditorTab: { closeEditorTab($0) }
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
        case .sqlResult:
            sqlResultArea
        case .tableDetail:
            detailView
        }
    }

    @ViewBuilder
    var detailView: some View {
        if let table = selectedTable, let database = selectedDatabase {
            switch selectedTab {
            case .structure:
                MySQLStructureView(columns: columns, isLoading: isLoadingStructure)
            case .data:
                MySQLDataView(
                    result: tableDataResult,
                    pagination: $pagination,
                    isLoading: isLoadingData,
                    onLoadPage: { [self] offset in
                        enqueuePendingTask {
                            pagination.page = max(1, (offset / pagination.pageSize) + 1)
                            await loadTableData(database: database, table: table)
                        }
                    },
                    onRefresh: { [self] in
                        enqueuePendingTask {
                            await loadTableData(database: database, table: table)
                        }
                    },
                    onCellEdit: { [self] rowIndex, columnIndex, newValue in
                        enqueuePendingTask {
                            await updateCell(
                                database: database,
                                table: table,
                                rowIndex: rowIndex,
                                columnIndex: columnIndex,
                                newValue: newValue
                            )
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    var sqlResultArea: some View {
        if isLoadingSQL {
            LoadingSQLView()
        } else if let sqlResult {
            MySQLResultView(result: sqlResult)
        }
    }

    @MainActor
    func enqueuePendingTask(_ operation: @escaping @Sendable () async -> Void) {
        guard !isWorkspaceClosing else { return }
        let taskId = UUID()
        let task = Task {
            await operation()
            await MainActor.run {
                pendingTasks.removeValue(forKey: taskId)
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
