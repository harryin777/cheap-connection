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
    @State var formattedSQLResult: String?
    @State var sqlResultConnectionId: UUID?
    @State var sqlResultDatabase: String?
    @State var sqlResultTable: String?
    @State var sqlResultColumns: [MySQLColumnDefinition] = []
    @State var lastExecutedSQL: String?
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

    var canEditSQLResult: Bool {
        sqlResultConnectionId != nil &&
        sqlResultDatabase != nil &&
        sqlResultTable != nil &&
        !sqlResultColumns.filter(\.isPrimaryKey).isEmpty
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
        .onDisappear {
            guard !isPanelClosing else { return }
            isPanelClosing = true
            Task {
                await cancelPendingTasksAndWait()
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
                        let pageSize = pagination.pageSize
                        let newPage = max(1, (offset / pageSize) + 1)
                        enqueuePendingTask {
                            await MainActor.run {
                                pagination.page = newPage
                            }
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
        } else if let formattedSQLResult {
            FormattedSQLResultView(sql: formattedSQLResult)
        } else if let sqlResult {
            MySQLResultView(
                result: sqlResult,
                onCellEdit: canEditSQLResult ? { [self] rowIndex, columnIndex, newValue in
                    enqueuePendingTask {
                        await updateSQLResultCell(
                            rowIndex: rowIndex,
                            columnIndex: columnIndex,
                            newValue: newValue
                        )
                    }
                } : nil
            )
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
                pendingTasks[taskId] = nil
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

struct FormattedSQLResultView: View {
    let sql: String
    @ObservedObject private var settingsRepo = SettingsRepository.shared

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(highlightedSQL)
                .font(.system(size: CGFloat(settingsRepo.settings.dataViewFontSize), design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.textBackgroundColor))
    }

    private var highlightedSQL: AttributedString {
        let baseFont = Font.system(size: CGFloat(settingsRepo.settings.dataViewFontSize), design: .monospaced)
        let defaultColor = Color.primary
        let keywordColor = Color(red: 0.93, green: 0.62, blue: 0.32)
        let commentColor = Color(red: 0.42, green: 0.62, blue: 0.46)
        let stringColor = Color(red: 0.47, green: 0.72, blue: 0.80)

        var attributed = AttributedString(sql)
        attributed.font = baseFont
        attributed.foregroundColor = defaultColor

        let nsString = sql as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        func apply(pattern: String, color: Color) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            regex.enumerateMatches(in: sql, options: [], range: fullRange) { match, _, _ in
                guard let match, let range = Range(match.range, in: sql),
                      let attributedRange = Range(range, in: attributed) else { return }
                attributed[attributedRange].foregroundColor = color
                attributed[attributedRange].font = baseFont
            }
        }

        apply(pattern: #"(?i)\b(create|table|primary|key|unique|constraint|default|not|null|engine|charset|collate|comment|auto_increment|on|update|current_timestamp|int|bigint|varchar|datetime|text|json|decimal|unsigned)\b"#, color: keywordColor)
        apply(pattern: #"'(?:''|[^'])*'"#, color: stringColor)
        apply(pattern: #"(?m)(--|#).*$"#, color: commentColor)
        apply(pattern: #"(?s)/\*.*?\*/"#, color: commentColor)

        return attributed
    }
}
