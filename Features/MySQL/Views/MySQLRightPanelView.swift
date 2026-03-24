//
//  MySQLRightPanelView.swift
//  cheap-connection
//
//  MySQL 右侧面板视图 - 完全独立于左侧资源树
//

import SwiftUI

// MARK: - MySQLRightPanelView

/// MySQL 右侧面板视图
/// 完全独立于左侧资源树，不监听 ConnectionManager.selectedXxx 变化
struct MySQLRightPanelView: View {
    let connectionConfig: ConnectionConfig
    let workspaceId: UUID
    let service: MySQLService
    @Environment(ConnectionManager.self) var connectionManager

    // State - Query Context
    @State var connectionDatabaseCache: [UUID: [String]] = [:]
    @State var scratchQueryConnectionId: UUID?
    @State var scratchQueryConnectionName: String?
    @State var scratchQueryDatabaseName: String?
    @State var editorTabs: [EditorQueryTab] = []
    @State var activeEditorTabId: UUID?
    @State var sqlText = ""
    @State var sqlHistory: [String] = []

    // State - Display
    @State var selectedTab: MySQLDetailTab = .data
    @State var displayMode: WorkspaceDisplayMode = .editorOnly

    // State - Table Detail
    @State var detailConnectionId: UUID?
    @State var detailDatabase: String?
    @State var detailTable: String?
    @State var columns: [MySQLColumnDefinition] = []
    @State var tableDataResult: MySQLQueryResult?
    @State var sqlResult: MySQLQueryResult?
    @State var pagination = PaginationState()

    // State - Loading
    @State var isLoadingSQL = false
    @State var isLoadingData = false
    @State var isLoadingStructure = false
    @State var isLoadingQueryMetadata = false

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

    // State - Task Management
    @State var pendingTasks: [UUID: Task<Void, Never>] = [:]
    @State var isPanelClosing = false

    // State - Autocomplete Metadata
    @State var queryTables: [MySQLTableSummary] = []
    @State var queryAllColumns: [MySQLColumnDefinition] = []

    // MARK: - Computed Properties

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
        return connectionDatabaseCache[currentQueryConnectionId]?.sorted() ?? []
    }

    var availableConnections: [ConnectionConfig] {
        // 显示所有连接（MySQL + Redis），让用户可以在同一壳层下切换不同类型的连接
        connectionManager.connections
    }

    var autocompleteTables: [MySQLTableSummary] {
        return queryTables
    }

    var autocompleteColumns: [MySQLColumnDefinition] {
        return queryAllColumns
    }

    // MARK: - Body

    var body: some View {
        Group {
            if displayMode == .editorOnly {
                editorOnlyView
            } else {
                splitView
            }
        }
        .onAppear {
            initializeQueryContext()
            enqueuePendingTask {
                await loadInitialMetadata()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tableDoubleClicked)) { notification in
            guard let info = notification.object as? TableDoubleClickInfo else { return }
            showTableDetail(database: info.database, table: info.table, connectionId: info.connectionId)
        }
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

    // MARK: - View Components

    @ViewBuilder
    private var editorOnlyView: some View {
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
    }

    @ViewBuilder
    private var splitView: some View {
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
                    isExecuting: isLoadingSQL,
                    // 只在查看表详情时显示 workspace tabs
                    activeWorkspaceTab: {
                        if case .tableDetail = displayMode {
                            return selectedTab
                        }
                        return nil
                    }(),
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
            bottomView: AnyView(bottomContentView),
            topHeight: $editorHeight,
            minTopHeight: 120,
            minBottomHeight: 100
        )
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
        if let table = detailTable, let database = detailDatabase, let connectionId = detailConnectionId {
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
                            await loadTableData(database: database, table: table, connectionId: connectionId)
                        }
                    },
                    onRefresh: { [self] in
                        enqueuePendingTask {
                            await loadTableData(database: database, table: table, connectionId: connectionId)
                        }
                    },
                    onCellEdit: { [self] rowIndex, columnIndex, newValue in
                        enqueuePendingTask {
                            await updateCell(
                                database: database,
                                table: table,
                                connectionId: connectionId,
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

    // MARK: - Initialization

    private func initializeQueryContext() {
        if scratchQueryConnectionId == nil {
            scratchQueryConnectionId = connectionConfig.id
            scratchQueryConnectionName = connectionConfig.name
            scratchQueryDatabaseName = connectionConfig.defaultDatabase
        }
    }

    private func loadInitialMetadata() async {
        // 加载当前 Query Context 连接的数据库列表
        let databases = await fetchDatabasesForConnection(currentQueryConnectionId)
        if connectionDatabaseCache[currentQueryConnectionId] == nil {
            connectionDatabaseCache[currentQueryConnectionId] = databases
        }

        // 如果有默认数据库，加载元数据
        if let defaultDb = currentQueryDatabase {
            await loadQueryMetadata(database: defaultDb)
        }
    }

    // MARK: - Task Management

    @MainActor
    func enqueuePendingTask(_ operation: @escaping @Sendable () async -> Void) {
        guard !isPanelClosing else { return }
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
    let service = MySQLService(connectionConfig: config)
    MySQLRightPanelView(
        connectionConfig: config,
        workspaceId: UUID(),
        service: service
    ).frame(width: 900, height: 600)
}
