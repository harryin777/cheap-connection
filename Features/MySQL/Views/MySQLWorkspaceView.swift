//
//  MySQLWorkspaceView.swift
//  cheap-connection
//
//  MySQL工作区视图 - DataGrip风格布局
//

import SwiftUI

/// MySQL工作区视图
struct MySQLWorkspaceView: View {
    let connectionConfig: ConnectionConfig
    @Environment(ConnectionManager.self) var connectionManager

    // State - Service & Data
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
        activeQueryTab?.queryConnectionId ?? connectionConfig.id
    }

    var currentQueryConnectionName: String {
        activeQueryTab?.queryConnectionName ?? connectionConfig.name
    }

    var currentQueryDatabase: String? {
        activeQueryTab?.queryDatabaseName
    }

    var queryDatabaseOptions: [String] {
        let connectionId = currentQueryConnectionId
        if connectionId == connectionConfig.id {
            return databases.map(\.name).sorted()
        }
        return connectionDatabaseCache[connectionId]?.sorted() ?? []
    }

    var availableConnections: [ConnectionConfig] {
        connectionManager.connections.filter { $0.databaseKind == .mysql }
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
        .task { await connectIfNeeded() }
        .onDisappear { Task { await disconnect() } }
        .onChange(of: connectionManager.selectedDatabaseName) { _, _ in syncSelectionFromManager() }
        .onChange(of: connectionManager.selectedTableName) { _, _ in syncSelectionFromManager() }
        .onChange(of: selectedDatabase) { _, newDatabase in syncDatabaseToManager(newDatabase) }
        .onChange(of: selectedTable) { _, newTable in handleTableSelection(newTable) }
        .onChange(of: sqlText) { _, _ in syncSQLTextToActiveTab() }
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
        VStack(spacing: 0) {
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
                onExecute: { await executeSQL($0) },
                onSelectHistory: { sqlText = $0 },
                isExecuting: isLoadingSQL,
                activeWorkspaceTab: displayMode == .editorOnly ? nil : selectedTab,
                onSelectWorkspaceTab: { tab in
                    selectedTab = tab
                    displayMode = .tableDetail(tab)
                },
                onImport: { await importSQLFile() },
                onOpenFile: { await openSQLFile() },
                onCloseTab: { closeActiveEditorTab() },
                tables: currentDatabaseTables,
                columns: columns,
                editorTabs: editorTabs,
                activeEditorTabId: activeEditorTabId,
                onSelectEditorTab: { selectEditorTab($0) },
                onCloseEditorTab: { closeEditorTab($0) }
            )
            .frame(minHeight: 120)

            switch displayMode {
            case .editorOnly:
                EmptyView()
            case .sqlResult:
                Divider()
                sqlResultArea.frame(minHeight: 100, maxHeight: .infinity)
            case .tableDetail:
                Divider()
                detailView.frame(minWidth: 400, maxHeight: .infinity)
            }
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
                        pagination.page = max(1, (offset / pagination.pageSize) + 1)
                        await loadTableData(database: database, table: table)
                    },
                    onRefresh: { await loadTableData(database: database, table: table) },
                    onCellEdit: { [self] rowIndex, columnIndex, newValue in
                        await updateCell(
                            database: database,
                            table: table,
                            rowIndex: rowIndex,
                            columnIndex: columnIndex,
                            newValue: newValue
                        )
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
    MySQLWorkspaceView(connectionConfig: config).frame(width: 900, height: 600)
}
