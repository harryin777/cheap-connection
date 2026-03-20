//
//  MySQLRightPanelOperations.swift
//  cheap-connection
//
//  MySQL 右侧面板操作 - 数据加载、编辑与 SQL 执行
//

import Foundation

extension MySQLRightPanelView {
    // MARK: - Table Data Loading

    func loadTableStructure(database: String, table: String) async {
        guard !Task.isCancelled, !isPanelClosing else { return }
        isLoadingStructure = true
        defer { isLoadingStructure = false }

        do {
            let loadedColumns = try await withQueryService(currentQueryConnectionId) { queryService in
                try await queryService.fetchTableStructure(database: database, table: table)
            }
            guard !Task.isCancelled, !isPanelClosing else { return }
            columns = loadedColumns
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func loadTableData(database: String, table: String) async {
        guard !Task.isCancelled, !isPanelClosing else { return }
        isLoadingData = true
        defer { isLoadingData = false }

        do {
            let result = try await withQueryService(currentQueryConnectionId) { queryService in
                try await queryService.fetchTableData(
                    database: database,
                    table: table,
                    pagination: pagination,
                    orderBy: orderBy,
                    orderDirection: orderDirection
                )
            }
            guard !Task.isCancelled, !isPanelClosing else { return }
            tableDataResult = result
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Cell Update

    func updateCell(database: String, table: String, rowIndex: Int, columnIndex: Int, newValue: String) async {
        guard !Task.isCancelled, !isPanelClosing else { return }
        guard let result = tableDataResult,
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
            let updateResult = try await withQueryService(currentQueryConnectionId) { queryService in
                try await queryService.executeSQL(sql)
            }
            guard !Task.isCancelled, !isPanelClosing else { return }
            if let error = updateResult.error {
                errorMessage = "更新失败: \(error.localizedDescription)"
                showError = true
            } else {
                await loadTableData(database: database, table: table)
            }
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            errorMessage = "更新失败: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - SQL Execution

    func executeSQL(_ sql: String) async {
        guard !isPanelClosing else { return }
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
            sqlResult = try await withQueryService(currentQueryConnectionId) { queryService in
                var processedSQL = sql
                if let currentQueryDatabase {
                    processedSQL = SQLPreprocessor.preprocessSQL(sql, database: currentQueryDatabase)
                }
                return try await queryService.executeSQL(processedSQL)
            }
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Table Detail Selection (主动触发，非左侧树同步)

    /// 显示指定表的详情（由右侧面板主动触发，非左侧树点击同步）
    func showTableDetail(database: String, table: String) {
        detailDatabase = database
        detailTable = table
        selectedTab = .data
        displayMode = .tableDetail(.data)

        enqueuePendingTask {
            await loadTableStructure(database: database, table: table)
            guard !Task.isCancelled else { return }
            await loadTableData(database: database, table: table)
        }
    }
}
