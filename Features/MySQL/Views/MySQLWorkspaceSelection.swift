//
//  MySQLWorkspaceSelection.swift
//  cheap-connection
//
//  MySQL 工作区选中同步、数据编辑与 SQL 执行
//

import Foundation

extension MySQLWorkspaceView {
    /// 从 ConnectionManager 同步左侧资源树的选中状态到本地状态
    /// 注意：此函数只影响左侧资源树的浏览焦点，不影响右侧 query context
    func syncSelectionFromManager() {
        guard connectionManager.selectedConnectionId == connectionConfig.id else { return }

        if selectedDatabase != connectionManager.selectedDatabaseName {
            selectedDatabase = connectionManager.selectedDatabaseName
        }

        if selectedTable != connectionManager.selectedTableName {
            selectedTable = connectionManager.selectedTableName
        }
    }

    /// 将左侧资源树的数据库选择同步到 ConnectionManager
    /// 注意：此函数只用于左侧树的浏览同步，query toolbar 的数据库选择不会走到这里
    func syncDatabaseToManager(_ newDatabase: String?) {
        guard connectionManager.selectedConnectionId == connectionConfig.id else { return }
        if connectionManager.selectedDatabaseName != newDatabase {
            connectionManager.selectedDatabaseName = newDatabase
        }
    }

    func handleTableSelection(_ newTable: String?) {
        guard let table = newTable, let database = selectedDatabase else { return }

        selectedTab = .data
        displayMode = .tableDetail(.data)

        Task {
            await loadTableStructure(database: database, table: table)
            await loadTableData(database: database, table: table)
        }
    }

    func updateCell(database: String, table: String, rowIndex: Int, columnIndex: Int, newValue: String) async {
        guard let service,
              let result = tableDataResult,
              rowIndex < result.rows.count,
              columnIndex < result.columns.count else { return }

        let columnName = result.columns[columnIndex]
        let primaryKeyColumns = columns.filter { $0.isPrimaryKey }

        guard !primaryKeyColumns.isEmpty else {
            errorMessage = "无法编辑：该表没有主键"
            showError = true
            return
        }

        let row = result.rows[rowIndex]
        var whereClauses: [String] = []

        for primaryKeyColumn in primaryKeyColumns {
            guard let pkIndex = result.columns.firstIndex(of: primaryKeyColumn.name) else {
                errorMessage = "无法编辑：找不到主键列 \(primaryKeyColumn.name)"
                showError = true
                return
            }

            let pkValue = row[pkIndex]
            let escapedValue = SQLPreprocessor.escapeValueForSQL(pkValue)
            whereClauses.append("`\(primaryKeyColumn.name)` = \(escapedValue)")
        }

        let escapedDatabase = "`" + database.replacingOccurrences(of: "`", with: "``") + "`"
        let escapedTable = "`" + table.replacingOccurrences(of: "`", with: "``") + "`"
        let escapedColumn = "`" + columnName.replacingOccurrences(of: "`", with: "``") + "`"
        let escapedNewValue = SQLPreprocessor.escapeStringValue(newValue)

        let sql = """
            UPDATE \(escapedDatabase).\(escapedTable)
            SET \(escapedColumn) = \(escapedNewValue)
            WHERE \(whereClauses.joined(separator: " AND "))
            LIMIT 1
            """

        do {
            let updateResult = try await service.executeSQL(sql)
            if let error = updateResult.error {
                errorMessage = "更新失败: \(error.localizedDescription)"
                showError = true
            } else {
                await loadTableData(database: database, table: table)
            }
        } catch {
            errorMessage = "更新失败: \(error.localizedDescription)"
            showError = true
        }
    }

    func executeSQL(_ sql: String) async {
        isLoadingSQL = true
        defer { isLoadingSQL = false }

        if !sqlHistory.contains(sql) {
            sqlHistory.insert(sql, at: 0)
            if sqlHistory.count > 50 {
                sqlHistory.removeLast()
            }
        }

        displayMode = .sqlResult

        do {
            let queryConnectionId = currentQueryConnectionId
            let queryServiceHandle = try await serviceForQueryConnection(queryConnectionId)
            defer {
                if queryServiceHandle.shouldDisconnect {
                    Task {
                        await queryServiceHandle.service.disconnect()
                    }
                }
            }

            var processedSQL = sql
            if let currentQueryDatabase {
                processedSQL = SQLPreprocessor.preprocessSQL(sql, database: currentQueryDatabase)
            }
            sqlResult = try await queryServiceHandle.service.executeSQL(processedSQL)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
