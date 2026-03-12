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

/// MySQL工作区视图
struct MySQLWorkspaceView: View {
    let connectionConfig: ConnectionConfig

    @Environment(ConnectionManager.self) private var connectionManager

    // State
    @State private var service: MySQLService?
    @State private var databases: [MySQLDatabaseSummary] = []
    @State private var columns: [MySQLColumnDefinition] = []
    @State private var sqlResult: MySQLQueryResult?  // SQL 查询结果
    @State private var tableDataResult: MySQLQueryResult?  // 表数据结果
    @State private var pagination = PaginationState()
    @State private var selectedDatabase: String?
    @State private var selectedTable: String?
    @State private var selectedTab: MySQLDetailTab = .data
    @State private var sqlExecutionDatabase: String?
    @State private var sqlText = ""
    @State private var sqlHistory: [String] = []

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

    /// 获取当前选中数据库的所有表
    private var currentDatabaseTables: [MySQLTableSummary] {
        guard let dbName = selectedDatabase,
              let db = databases.first(where: { $0.name == dbName }),
              let tables = db.tables else {
            return []
        }
        return tables
    }

    /// SQL 可执行数据库名称列表
    private var sqlDatabaseOptions: [String] {
        databases.map(\.name).sorted()
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
            await connectIfNeeded()
        }
        .onDisappear {
            // 视图消失时断开连接
            Task {
                await disconnect()
            }
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
                // 选中表时默认切换到数据标签
                selectedTab = .data
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
            // 顶部：SQL 编辑器 + 查询结果（可拖拽调整大小）
            VSplitView {
                // SQL 编辑器
                MySQLEditorView(
                    sqlText: $sqlText,
                    history: sqlHistory,
                    isExecuting: isLoadingSQL,
                    onExecute: { sql in
                        await executeSQL(sql)
                    },
                    onSelectHistory: { sql in
                        sqlText = sql
                    },
                    onImport: {
                        await importSQLFile()
                    },
                    onOpenFile: {
                        await openSQLFile()
                    },
                    onCloseTab: {
                        // 关闭 Query Tab 时清空结果
                        sqlResult = nil
                    },
                    queryDatabases: sqlDatabaseOptions,
                    selectedQueryDatabase: sqlExecutionDatabase,
                    onSelectQueryDatabase: { database in
                        sqlExecutionDatabase = database
                    },
                    tables: currentDatabaseTables,
                    columns: columns
                )
                .frame(minHeight: 100, idealHeight: 200)

                // 查询结果区域
                sqlResultArea
                    .frame(minHeight: 100, idealHeight: 150)
            }
            .frame(maxHeight: 350)

            Divider()

            // 下部：侧边栏 + 详情区域
            HSplitView {
                // 左侧：树形侧边栏
                MySQLSidebarView(
                    databases: $databases,
                    connectionName: connectionConfig.name,
                    selectedDatabase: selectedDatabase,
                    selectedTable: selectedTable,
                    onSelectDatabase: { db in
                        selectedDatabase = db
                        selectedTable = nil
                        if sqlExecutionDatabase == nil {
                            sqlExecutionDatabase = db
                        }
                    },
                    onSelectTable: { db, table in
                        selectedDatabase = db
                        selectedTable = table
                        if sqlExecutionDatabase == nil {
                            sqlExecutionDatabase = db
                        }
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

                // 右侧：详情区域（结构和数据）
                detailView
                    .frame(minWidth: 400)
            }
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
        } else if let db = selectedDatabase {
            // 选中了数据库但没选表
            databaseSelectedView(db)
        } else {
            emptySelectionView
        }
    }

    private var tabBarView: some View {
        HStack(spacing: 0) {
            ForEach(MySQLDetailTab.allCases, id: \.self) { tab in
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

    /// SQL标签页的结果区域
    @ViewBuilder
    private var sqlResultArea: some View {
        if isLoadingSQL {
            loadingSQLView
        } else if let result = sqlResult {
            MySQLResultView(result: result)
        } else {
            emptySQLResultView
        }
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

    private var emptySQLResultView: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("输入 SQL 并执行")
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
        sqlExecutionDatabase = nil
    }

    private func loadDatabases() async {
        guard let service = service else { return }

        isLoadingDatabases = true
        defer { isLoadingDatabases = false }

        do {
            databases = try await service.fetchDatabases()
            if sqlExecutionDatabase == nil {
                if let selectedDatabase {
                    sqlExecutionDatabase = selectedDatabase
                } else if let preferred = connectionConfig.defaultDatabase,
                          sqlDatabaseOptions.contains(preferred) {
                    sqlExecutionDatabase = preferred
                } else {
                    sqlExecutionDatabase = sqlDatabaseOptions.first
                }
            }
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

        do {
            // 按 SQL 执行数据库处理 SQL 中未显式指定库名的表名
            var processedSQL = sql
            if let db = sqlExecutionDatabase ?? selectedDatabase {
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
            sqlText = content
            print("📁 Opened SQL file: \(url.lastPathComponent), size: \(content.count) chars")
        } catch {
            errorMessage = "读取文件失败: \(error.localizedDescription)"
            showError = true
        }
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
