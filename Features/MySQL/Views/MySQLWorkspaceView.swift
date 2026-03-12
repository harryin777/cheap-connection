//
//  MySQLWorkspaceView.swift
//  cheap-connection
//
//  MySQL工作区视图 - DataGrip风格布局
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

/// MySQL工作区标签页（只有结构和数据）
enum MySQLDetailTab: String, CaseIterable {
    case structure = "结构"
    case data = "数据"

    var icon: String {
        switch self {
        case .structure: return "tablecells"
        case .data: return "list.bullet"
        }
    }
}

/// 工作区显示模式 - 互斥状态
enum WorkspaceDisplayMode: Equatable {
    /// 默认编辑态：只展示 query 编辑内容
    case editorOnly
    /// SQL 结果态：执行 SQL 后显示结果面板
    case sqlResult
    /// 表详情态：点击左侧具体表后显示结构/数据
    case tableDetail(MySQLDetailTab)

    static func == (lhs: WorkspaceDisplayMode, rhs: WorkspaceDisplayMode) -> Bool {
        switch (lhs, rhs) {
        case (.editorOnly, .editorOnly):
            return true
        case (.sqlResult, .sqlResult):
            return true
        case (.tableDetail(let lTab), .tableDetail(let rTab)):
            return lTab == rTab
        default:
            return false
        }
    }
}

/// MySQL工作区视图
struct MySQLWorkspaceView: View {
    let connectionConfig: ConnectionConfig

    @Environment(ConnectionManager.self) private var connectionManager

    // State
    @State private var service: MySQLService?
    @State private var databases: [MySQLDatabaseSummary] = []  // 当前 workspace 连接的数据库（用于资源树浏览）
    @State private var columns: [MySQLColumnDefinition] = []
    @State private var sqlResult: MySQLQueryResult?  // SQL 查询结果
    @State private var tableDataResult: MySQLQueryResult?  // 表数据结果
    @State private var pagination = PaginationState()

    // MARK: - 资源树浏览状态（左侧树选择，与 query context 完全独立）
    @State private var selectedDatabase: String?
    @State private var selectedTable: String?
    @State private var selectedTab: MySQLDetailTab = .data

    // MARK: - Query Context 缓存（按 connectionId 缓存数据库列表）
    /// 其他连接的数据库缓存，key 是 connectionId
    @State private var connectionDatabaseCache: [UUID: [String]] = [:]
    /// 正在加载的连接 ID
    @State private var loadingConnectionId: UUID?

    @State private var sqlHistory: [String] = []

    // Query Tab 状态
    @State private var editorTabs: [EditorQueryTab] = []
    @State private var activeEditorTabId: UUID?
    @State private var sqlText = ""  // 当前 SQL 文本

    // 工作区显示模式
    @State private var displayMode: WorkspaceDisplayMode = .editorOnly

    // Loading states
    @State private var isLoadingDatabases = false
    @State private var isLoadingStructure = false
    @State private var isLoadingData = false
    @State private var isLoadingSQL = false
    @State private var isConnecting = false
    @State private var loadingDatabase: String?

    // Error handling
    @State private var showError = false
    @State private var errorMessage = ""

    // Sorting
    @State private var orderBy: String?
    @State private var orderDirection: OrderDirection = .ascending

    // Import state
    @State private var showImportProgress = false
    @State private var importProgress: Double = 0
    @State private var importStatus = ""
    @State private var importResult: SQLImportResult?
    @State private var showImportResult = false

    // MARK: - Computed Properties

    /// 获取当前选中数据库的所有表（用于资源树浏览）
    private var currentDatabaseTables: [MySQLTableSummary] {
        guard let dbName = selectedDatabase,
              let db = databases.first(where: { $0.name == dbName }),
              let tables = db.tables else {
            return []
        }
        return tables
    }

    /// 当前活动的 Query Tab
    private var activeQueryTab: EditorQueryTab? {
        guard let tabId = activeEditorTabId else { return nil }
        return editorTabs.first(where: { $0.id == tabId })
    }

    /// 当前 query 上下文的连接 ID（优先从活动 tab 获取，否则回退到 workspace 连接）
    private var currentQueryConnectionId: UUID {
        activeQueryTab?.queryConnectionId ?? connectionConfig.id
    }

    /// 当前 query 上下文的连接名称
    private var currentQueryConnectionName: String {
        activeQueryTab?.queryConnectionName ?? connectionConfig.name
    }

    /// 当前 query 上下文的数据库名
    private var currentQueryDatabase: String? {
        activeQueryTab?.queryDatabaseName
    }

    /// 获取当前 query 连接的数据库列表
    private var queryDatabaseOptions: [String] {
        let connId = currentQueryConnectionId
        if connId == connectionConfig.id {
            // 当前 workspace 连接，直接返回已加载的数据库
            return databases.map(\.name).sorted()
        } else {
            // 其他连接，从缓存获取
            return connectionDatabaseCache[connId]?.sorted() ?? []
        }
    }

    /// 所有可用的 MySQL 连接列表
    private var availableConnections: [ConnectionConfig] {
        connectionManager.connections.filter { $0.databaseKind == .mysql }
    }

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
            syncSelectionFromManager()
            await connectIfNeeded()
        }
        .onDisappear {
            // 视图消失时断开连接
            Task {
                await disconnect()
            }
        }
        .onChange(of: connectionManager.selectedDatabaseName) { _, _ in
            syncSelectionFromManager()
        }
        .onChange(of: connectionManager.selectedTableName) { _, _ in
            syncSelectionFromManager()
        }
        .onChange(of: selectedDatabase) { _, newDatabase in
            guard connectionManager.selectedConnectionId == connectionConfig.id else { return }
            if connectionManager.selectedDatabaseName != newDatabase {
                connectionManager.selectedDatabaseName = newDatabase
            }
        }
        .onChange(of: selectedTable) { _, newTable in
            guard connectionManager.selectedConnectionId == connectionConfig.id else { return }
            if connectionManager.selectedTableName != newTable {
                connectionManager.selectedTableName = newTable
            }
        }
        .onChange(of: sqlText) { _, newValue in
            // 同步 sqlText 到当前活动的 tab
            syncSQLTextToActiveTab()
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
            if let result = importResult {
                Text(result.summary)
            } else {
                Text("导入完成")
            }
        }
        .onChange(of: selectedTable) { _, newTable in
            if let table = newTable, let db = selectedDatabase {
                // 选中表时切换到表详情模式，默认显示数据标签
                selectedTab = .data
                displayMode = .tableDetail(.data)
                Task {
                    await loadTableStructure(database: db, table: table)
                    await loadTableData(database: db, table: table)
                }
            }
        }
    }

    // MARK: - Subviews

    private var connectedView: some View {
        VStack(spacing: 0) {
            // 顶部：SQL 编辑器（始终显示）
            MySQLEditorView(
                sqlText: $sqlText,
                history: sqlHistory,
                queryConnectionId: currentQueryConnectionId,
                queryConnectionName: currentQueryConnectionName,
                availableConnections: availableConnections,
                queryDatabases: queryDatabaseOptions,
                selectedQueryDatabase: currentQueryDatabase,
                onSwitchQueryConnection: { connectionId in
                    switchQueryConnection(connectionId)
                },
                onSelectQueryDatabase: { database in
                    updateQueryDatabase(database)
                },
                onExecute: { sql in
                    await executeSQL(sql)
                },
                onSelectHistory: { sql in
                    sqlText = sql
                },
                isExecuting: isLoadingSQL,
                activeWorkspaceTab: displayMode == .editorOnly ? nil : selectedTab,
                onSelectWorkspaceTab: { tab in
                    selectedTab = tab
                    // 切换结构/数据 tab 时更新 displayMode
                    displayMode = .tableDetail(tab)
                },
                onImport: {
                    await importSQLFile()
                },
                onOpenFile: {
                    await openSQLFile()
                },
                onCloseTab: {
                    closeActiveEditorTab()
                },
                tables: currentDatabaseTables,
                columns: columns,
                editorTabs: editorTabs,
                activeEditorTabId: activeEditorTabId,
                onSelectEditorTab: { tabId in
                    selectEditorTab(tabId)
                },
                onCloseEditorTab: { tabId in
                    closeEditorTab(tabId)
                }
            )
            .frame(minHeight: 120)

            // 下方内容区域：根据显示模式互斥显示
            switch displayMode {
            case .editorOnly:
                // 默认态：不显示任何下方面板
                EmptyView()

            case .sqlResult:
                // SQL 结果态：只显示 SQL 结果面板
                Divider()
                sqlResultArea
                    .frame(minHeight: 100, maxHeight: .infinity)

            case .tableDetail:
                // 表详情态：只显示结构/数据面板
                Divider()
                detailView
                    .frame(minWidth: 400, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        // 只有选中了表才显示内容，不显示空状态
        if let table = selectedTable, let db = selectedDatabase {
            VStack(spacing: 0) {
                // 内容区域
                switch selectedTab {
                case .structure:
                    MySQLStructureView(
                        columns: columns,
                        isLoading: isLoadingStructure
                    )

                case .data:
                    MySQLDataView(
                        result: tableDataResult,
                        pagination: $pagination,
                        isLoading: isLoadingData,
                        onLoadPage: { offset in
                            pagination.page = max(1, (offset / pagination.pageSize) + 1)
                            await loadTableData(database: db, table: table)
                        },
                        onRefresh: {
                            await loadTableData(database: db, table: table)
                        },
                        onCellEdit: { rowIndex, columnIndex, newValue in
                            await updateCell(
                                database: db,
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
        // 注意：没有选中表时不显示任何空状态，由 displayMode 控制整个区域是否显示
    }

    /// SQL标签页的结果区域
    @ViewBuilder
    private var sqlResultArea: some View {
        // 只在加载中或有结果时显示，不显示空状态
        if isLoadingSQL {
            loadingSQLView
        } else if let result = sqlResult {
            MySQLResultView(result: result)
        }
        // 注意：没有结果时不显示空状态，由 displayMode 控制整个区域是否显示
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

    private var loadingSQLView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("执行中...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
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

        // 如果已有连接，先断开
        await disconnect()

        do {
            // Get password from Keychain
            guard let password = try KeychainService.shared.getPassword(for: connectionConfig.id) else {
                throw AppError.authenticationFailed("未找到保存的密码，请重新编辑连接")
            }

            // Create service
            let newService = MySQLService(connectionConfig: connectionConfig)
            try await newService.connect(config: connectionConfig, password: password)
            service = newService
            connectionManager.recordConnectionUsage(connectionConfig.id)

            // Load databases
            await loadDatabases()
        } catch {
            // 连接失败时清理
            await service?.disconnect()
            service = nil
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func disconnect() async {
        await service?.disconnect()
        service = nil
        databases = []
        columns = []
        sqlResult = nil
        tableDataResult = nil
        selectedDatabase = nil
        selectedTable = nil
        // 清空连接数据库缓存
        connectionDatabaseCache.removeAll()
    }

    private func loadDatabases() async {
        guard let service = service else { return }

        isLoadingDatabases = true
        defer { isLoadingDatabases = false }

        do {
            databases = try await service.fetchDatabases()
            // 同步到缓存
            connectionDatabaseCache[connectionConfig.id] = databases.map(\.name)
            syncSelectionFromManager()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func loadTablesForDatabase(_ database: String) async {
        guard let service = service else {
            print("⚠️ loadTablesForDatabase: service is nil")
            return
        }

        print("📋 Loading tables for database: \(database)")
        loadingDatabase = database

        do {
            let tables = try await service.fetchTables(database: database)
            print("✅ Loaded \(tables.count) tables for \(database)")

            // 更新对应数据库的表列表
            if let index = databases.firstIndex(where: { $0.name == database }) {
                databases[index].tables = tables
            }
        } catch {
            print("❌ Failed to load tables for \(database): \(error)")
            errorMessage = "加载表失败: \(error.localizedDescription)"
            showError = true
        }

        loadingDatabase = nil
    }

    private func syncSelectionFromManager() {
        guard connectionManager.selectedConnectionId == connectionConfig.id else { return }

        // 只同步资源树浏览状态到结构/数据面板，不影响 query context
        if selectedDatabase != connectionManager.selectedDatabaseName {
            selectedDatabase = connectionManager.selectedDatabaseName
        }

        if selectedTable != connectionManager.selectedTableName {
            selectedTable = connectionManager.selectedTableName
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
            tableDataResult = try await service.fetchTableData(
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

    /// SQL标签页的单元格编辑处理
    private func sqlCellEditHandler(rowIndex: Int, columnIndex: Int, newValue: String) async {
        guard let db = selectedDatabase, let table = selectedTable else { return }
        await updateCell(database: db, table: table, rowIndex: rowIndex, columnIndex: columnIndex, newValue: newValue)
    }

    private func updateCell(
        database: String,
        table: String,
        rowIndex: Int,
        columnIndex: Int,
        newValue: String
    ) async {
        guard let service = service,
              let result = tableDataResult,
              rowIndex < result.rows.count,
              columnIndex < result.columns.count else {
            print("⚠️ updateCell: invalid parameters")
            return
        }

        // 获取列名和主键信息
        let columnName = result.columns[columnIndex]
        let primaryKeyColumns = columns.filter { $0.isPrimaryKey }

        // 检查是否有主键
        guard !primaryKeyColumns.isEmpty else {
            errorMessage = "无法编辑：该表没有主键"
            showError = true
            return
        }

        // 构建 WHERE 子句（使用主键）
        var whereClauses: [String] = []
        let row = result.rows[rowIndex]

        for pkColumn in primaryKeyColumns {
            guard let pkIndex = result.columns.firstIndex(of: pkColumn.name) else {
                errorMessage = "无法编辑：找不到主键列 \(pkColumn.name)"
                showError = true
                return
            }

            let pkValue = row[pkIndex]
            let escapedValue = escapeValueForSQL(pkValue)
            whereClauses.append("`\(pkColumn.name)` = \(escapedValue)")
        }

        // 构建 UPDATE SQL
        let escapedDB = "`" + database.replacingOccurrences(of: "`", with: "``") + "`"
        let escapedTable = "`" + table.replacingOccurrences(of: "`", with: "``") + "`"
        let escapedColumn = "`" + columnName.replacingOccurrences(of: "`", with: "``") + "`"
        let escapedNewValue = escapeStringValue(newValue)

        let sql = """
            UPDATE \(escapedDB).\(escapedTable)
            SET \(escapedColumn) = \(escapedNewValue)
            WHERE \(whereClauses.joined(separator: " AND "))
            LIMIT 1
            """

        print("📝 Update cell SQL: \(sql)")

        do {
            let updateResult = try await service.executeSQL(sql)
            if let error = updateResult.error {
                errorMessage = "更新失败: \(error.localizedDescription)"
                showError = true
            } else {
                print("✅ Cell updated successfully")
                // 刷新数据
                await loadTableData(database: database, table: table)
            }
        } catch {
            errorMessage = "更新失败: \(error.localizedDescription)"
            showError = true
        }
    }

    private func escapeValueForSQL(_ value: MySQLRowValue) -> String {
        if value.isNull {
            return "NULL"
        }
        return escapeStringValue(value.displayValue)
    }

    private func escapeStringValue(_ value: String) -> String {
        if value.isEmpty {
            return "''"
        }
        // 转义单引号和反斜杠
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "'\(escaped)'"
    }

    private func executeSQL(_ sql: String) async {
        guard let service = service else {
            print("⚠️ executeSQL: service is nil")
            return
        }

        isLoadingSQL = true
        defer { isLoadingSQL = false }

        // Add to history
        if !sqlHistory.contains(sql) {
            sqlHistory.insert(sql, at: 0)
            if sqlHistory.count > 50 {
                sqlHistory.removeLast()
            }
        }

        // 切换到 SQL 结果模式
        displayMode = .sqlResult

        do {
            // 按 SQL 执行数据库处理 SQL 中未显式指定库名的表名
            var processedSQL = sql
            // 注意：传入这里的 sql 已经是 SQLStatementParser 解析后的"最终执行范围"
            // 只对这个范围进行预处理（添加数据库前缀等）
            // 使用当前 query context 的数据库
            if let db = currentQueryDatabase {
                processedSQL = preprocessSQL(sql, database: db)
                print("🔄 Executing SQL (with db context): \(processedSQL.prefix(100))...")
            } else {
                print("🔄 Executing SQL: \(sql.prefix(100))...")
            }

            let result = try await service.executeSQL(processedSQL)
            sqlResult = result
            if let error = result.error {
                print("❌ SQL result error: \(error.localizedDescription)")
            } else {
                print("✅ SQL executed: \(result.isSuccess), rows: \(result.rowCount)")
            }
        } catch {
            print("❌ SQL execution failed: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// 预处理 SQL，为未指定数据库的表名添加当前数据库前缀
    private func preprocessSQL(_ sql: String, database: String) -> String {
        let escapedDB = "`" + database.replacingOccurrences(of: "`", with: "``") + "`"

        // 处理 FROM table_name 模式
        var result = sql

        // 匹配 FROM 后面紧跟的表名（不带数据库前缀的情况）
        // 模式：FROM 后面跟着空格，然后是标识符（可能带反引号），但没有点号
        let fromPattern = #/(?i)\bFROM\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(fromPattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "FROM \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 JOIN table_name 模式
        let joinPattern = #/(?i)\bJOIN\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(joinPattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "JOIN \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 UPDATE table_name 模式
        let updatePattern = #/(?i)\bUPDATE\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(updatePattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "UPDATE \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 INSERT INTO table_name 模式
        let insertPattern = #/(?i)\bINSERT\s+INTO\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(insertPattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "INSERT INTO \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        // 匹配 DELETE FROM table_name 模式
        let deletePattern = #/(?i)\bDELETE\s+FROM\s+(`?)(\w+)\1(?!\s*\.)/#
        result = result.replacing(deletePattern) { match in
            let quote = match.output.1
            let tableName = match.output.2
            return "DELETE FROM \(escapedDB).\(quote)\(tableName)\(quote)"
        }

        return result
    }

    // MARK: - SQL File Operations

    /// 打开 SQL 文件到编辑器
    private func openSQLFile() async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.init(filenameExtension: "sql")!]
        panel.message = "选择要打开的 SQL 文件"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)

            // 按 fileURL 在 editorTabs 中查重
            if let existingTab = editorTabs.first(where: { $0.fileURL == url }) {
                // 已存在：切换到该 tab
                activeEditorTabId = existingTab.id
                sqlText = existingTab.content
                print("📁 Switched to existing SQL file: \(url.lastPathComponent)")
            } else {
                // 不存在：创建新 tab，使用当前 workspace 连接作为默认上下文
                let newTab = EditorQueryTab(
                    fileURL: url,
                    content: content,
                    defaultConnectionId: connectionConfig.id,
                    defaultConnectionName: connectionConfig.name,
                    defaultDatabase: connectionConfig.defaultDatabase ?? databases.first?.name
                )
                editorTabs.append(newTab)
                activeEditorTabId = newTab.id
                sqlText = content
                print("📁 Opened SQL file: \(url.lastPathComponent), size: \(content.count) chars")
            }

            // 打开文件后切换到编辑模式，不显示任何结果面板
            displayMode = .editorOnly
        } catch {
            errorMessage = "读取文件失败: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Editor Tab Management

    /// 选择编辑器 Tab
    private func selectEditorTab(_ tabId: UUID) {
        guard let tab = editorTabs.first(where: { $0.id == tabId }) else { return }
        activeEditorTabId = tabId
        sqlText = tab.content

        // 切换文件 tab 时，如果当前在表详情模式，则保持该模式
        // 如果当前在 SQL 结果模式，也保持（因为用户可能想查看该文件的执行结果）
        // 如果当前在编辑模式，保持编辑模式
        // 这里不做额外切换，让用户保持当前工作上下文
    }

    /// 关闭指定编辑器 Tab
    private func closeEditorTab(_ tabId: UUID) {
        guard let index = editorTabs.firstIndex(where: { $0.id == tabId }) else { return }

        // 先同步当前 sqlText 到当前 tab
        syncSQLTextToActiveTab()

        // 移除 tab
        editorTabs.remove(at: index)

        // 如果关闭的是当前活动 tab
        if activeEditorTabId == tabId {
            if editorTabs.isEmpty {
                // 无剩余 tab：清空状态，回到纯编辑模式
                activeEditorTabId = nil
                sqlText = ""
                sqlResult = nil
                displayMode = .editorOnly
            } else {
                // 切换到相邻 tab
                let newIndex = min(index, editorTabs.count - 1)
                let newTab = editorTabs[newIndex]
                activeEditorTabId = newTab.id
                sqlText = newTab.content
            }
        }
    }

    /// 关闭当前活动的编辑器 Tab
    private func closeActiveEditorTab() {
        guard let tabId = activeEditorTabId else {
            // 没有活动的文件 tab，清空结果
            sqlResult = nil
            return
        }
        closeEditorTab(tabId)
    }

    /// 同步 sqlText 到当前活动的 tab
    private func syncSQLTextToActiveTab() {
        guard let activeId = activeEditorTabId,
              let index = editorTabs.firstIndex(where: { $0.id == activeId }) else { return }
        editorTabs[index].content = sqlText
    }

    // MARK: - SQL File Import

    /// 导入 SQL 文件
    private func importSQLFile() async {
        // 创建文件选择对话框
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.init(filenameExtension: "sql")!]
        panel.message = "选择要导入的 SQL 文件"

        // 显示对话框
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        // 读取文件内容
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            print("📁 Loaded SQL file: \(url.lastPathComponent), size: \(content.count) chars")

            // 解析 SQL 语句
            let statements = parseSQLStatements(from: content)
            print("📋 Parsed \(statements.count) SQL statements")

            await executeSQLStatements(statements, fileName: url.lastPathComponent)

        } catch {
            errorMessage = "读取文件失败: \(error.localizedDescription)"
            showError = true
        }
    }

    /// 解析 SQL 语句（按分号分割，处理多行语句）
    private func parseSQLStatements(from content: String) -> [String] {
        var statements: [String] = []
        var currentStatement = ""
        var inString = false
        var stringDelimiter: Character?

        for char in content {
            // 处理字符串
            if char == "'" || char == "\"" {
                if !inString {
                    inString = true
                    stringDelimiter = char
                } else if char == stringDelimiter {
                    inString = false
                    stringDelimiter = nil
                }
                currentStatement.append(char)
                continue
            }

            // 在字符串内，跳过分号检查
            if inString {
                currentStatement.append(char)
                continue
            }

            // 遇到分号，结束当前语句
            if char == ";" {
                let trimmed = currentStatement.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    statements.append(trimmed)
                }
                currentStatement = ""
            } else {
                currentStatement.append(char)
            }
        }

        // 处理最后一条语句（可能没有分号结尾）
        let trimmed = currentStatement.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            statements.append(trimmed)
        }

        return statements
    }

    /// 执行多条 SQL 语句
    private func executeSQLStatements(_ statements: [String], fileName: String) async {
        guard let service = service else {
            errorMessage = "未连接到数据库"
            showError = true
            return
        }

        // 显示进度
        showImportProgress = true
        importProgress = 0
        importStatus = "准备执行..."

        let startTime = Date()
        var successCount = 0
        var failedCount = 0
        var errors: [String] = []

        for (index, sql) in statements.enumerated() {
            // 更新进度
            let progress = Double(index + 1) / Double(statements.count)
            importProgress = progress
            importStatus = "执行中... (\(index + 1)/\(statements.count))"

            do {
                // 预处理 SQL（添加数据库前缀）
                var processedSQL = sql
                if let db = selectedDatabase {
                    processedSQL = preprocessSQL(sql, database: db)
                }

                let result = try await service.executeSQL(processedSQL)
                if let error = result.error {
                    failedCount += 1
                    errors.append("语句 \(index + 1): \(error.localizedDescription)")
                    print("❌ Statement \(index + 1) failed: \(error.localizedDescription)")
                } else {
                    successCount += 1
                    print("✅ Statement \(index + 1) executed successfully")
                }
            } catch {
                failedCount += 1
                errors.append("语句 \(index + 1): \(error.localizedDescription)")
                print("❌ Statement \(index + 1) error: \(error)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // 隐藏进度，显示结果
        showImportProgress = false
        importResult = SQLImportResult(
            success: failedCount == 0,
            totalStatements: statements.count,
            successStatements: successCount,
            failedStatements: failedCount,
            errors: errors,
            duration: duration
        )
        showImportResult = true

        print("📊 Import completed: \(successCount)/\(statements.count) success, \(failedCount) failed")
    }

    // MARK: - Query Context Management

    /// 切换当前活动 tab 的 query 连接
    private func switchQueryConnection(_ connectionId: UUID) {
        guard let tabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }) else { return }
        guard let connection = connectionManager.connections.first(where: { $0.id == connectionId }) else { return }

        let oldDatabase = editorTabs[tabIndex].queryDatabaseName

        // 更新 tab 的连接上下文
        editorTabs[tabIndex].queryConnectionId = connectionId
        editorTabs[tabIndex].queryConnectionName = connection.name

        // 检查旧数据库是否仍有效，无效则清空
        if let oldDb = oldDatabase {
            Task {
                let databases = await fetchDatabasesForConnection(connectionId)
                if !databases.contains(oldDb) {
                    // 旧数据库不在新连接中，回退到默认数据库
                    editorTabs[tabIndex].queryDatabaseName = connection.defaultDatabase ?? databases.first
                }
            }
        } else {
            // 没有旧数据库，设置默认
            Task {
                let databases = await fetchDatabasesForConnection(connectionId)
                editorTabs[tabIndex].queryDatabaseName = connection.defaultDatabase ?? databases.first
            }
        }

        print("🔄 Switched query connection to: \(connection.name)")
    }

    /// 更新当前活动 tab 的 query 数据库
    private func updateQueryDatabase(_ database: String?) {
        guard let tabIndex = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }) else { return }
        editorTabs[tabIndex].queryDatabaseName = database
        print("📝 Updated query database to: \(database ?? "nil")")
    }

    /// 获取指定连接的数据库列表（带缓存）
    private func fetchDatabasesForConnection(_ connectionId: UUID) async -> [String] {
        // 如果是当前 workspace 连接，直接返回已加载的
        if connectionId == connectionConfig.id {
            return databases.map(\.name)
        }

        // 检查缓存
        if let cached = connectionDatabaseCache[connectionId] {
            return cached
        }

        // 需要从对应连接获取
        guard let connection = connectionManager.connections.first(where: { $0.id == connectionId }) else {
            return []
        }

        loadingConnectionId = connectionId

        do {
            guard let password = try connectionManager.getPassword(for: connectionId) else {
                loadingConnectionId = nil
                return []
            }

            let tempService = MySQLService(connectionConfig: connection)
            try await tempService.connect(config: connection, password: password)

            let dbList = try await tempService.fetchDatabases()
            await tempService.disconnect()

            let dbNames = dbList.map(\.name)
            connectionDatabaseCache[connectionId] = dbNames
            loadingConnectionId = nil

            return dbNames
        } catch {
            print("❌ Failed to fetch databases for connection \(connection.name): \(error)")
            loadingConnectionId = nil
            return []
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
