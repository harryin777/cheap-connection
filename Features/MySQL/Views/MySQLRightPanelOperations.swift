//
//  MySQLRightPanelOperations.swift
//  cheap-connection
//
//  MySQL 右侧面板操作 - 数据加载、编辑与 SQL 执行
//

import Foundation

extension MySQLRightPanelView {
    struct SQLResultEditContext {
        let connectionId: UUID
        let database: String
        let table: String
        let columns: [MySQLColumnDefinition]
    }

    // MARK: - Table Data Loading

    func loadTableStructure(database: String, table: String, connectionId: UUID) async {
        guard !Task.isCancelled, !isPanelClosing else { return }
        isLoadingStructure = true
        defer { isLoadingStructure = false }

        do {
            let loadedColumns = try await withQueryService(connectionId) { queryService in
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

    func loadTableData(database: String, table: String, connectionId: UUID) async {
        guard !Task.isCancelled, !isPanelClosing else { return }
        isLoadingData = true
        defer { isLoadingData = false }

        do {
            let result = try await withQueryService(connectionId) { queryService in
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

            // Update pagination state with total count and hasMore
            if let totalCount = result.totalCount {
                let hasMore = pagination.offset + result.rowCount < totalCount
                pagination.update(hasMore: hasMore, totalCount: totalCount)
            } else {
                // If no total count, use current page size to estimate hasMore
                let hasMore = result.rowCount >= pagination.pageSize
                pagination.update(hasMore: hasMore, totalCount: nil)
            }
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Cell Update

    func updateCell(database: String, table: String, connectionId: UUID, rowIndex: Int, columnIndex: Int, newValue: String) async {
        guard !Task.isCancelled, !isPanelClosing else { return }
        guard let result = tableDataResult,
              rowIndex < result.rows.count,
              columnIndex < result.columns.count else { return }

        let columnName = result.columns[columnIndex]
        let primaryKeyColumns = columns.filter { $0.isPrimaryKey }

        guard !primaryKeyColumns.isEmpty else {
            errorMessage = "No primary key"
            showError = true
            return
        }

        let row = result.rows[rowIndex]
        var whereClauses: [String] = []

        for primaryKeyColumn in primaryKeyColumns {
            guard let pkIndex = result.columns.firstIndex(of: primaryKeyColumn.name) else {
                errorMessage = "Primary key column not found: \(primaryKeyColumn.name)"
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
            let updateResult = try await withQueryService(connectionId) { queryService in
                try await queryService.executeSQL(sql)
            }
            guard !Task.isCancelled, !isPanelClosing else { return }
            if let error = updateResult.error {
                errorMessage = "Update failed: \(error.localizedDescription)"
                showError = true
            } else {
                await loadTableData(database: database, table: table, connectionId: connectionId)
            }
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            errorMessage = "Update failed: \(error.localizedDescription)"
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

        guard let connectionId = currentQueryConnectionId,
              let connection = connectionManager.connections.first(where: { $0.id == connectionId }) else {
            errorMessage = "请先选择一个连接"
            showError = true
            return
        }

        if connection.databaseKind == .redis {
            // Execute Redis command
            await executeRedisCommand(sql, connection: connection)
        } else {
            // Execute MySQL SQL
            await executeMySQLCommand(sql)
        }
    }

    private func executeMySQLCommand(_ sql: String) async {
        guard let connectionId = currentQueryConnectionId else {
            errorMessage = "请先选择一个连接"
            showError = true
            return
        }
        do {
            let result = try await withQueryService(connectionId) { queryService in
                var processedSQL = sql
                if let currentQueryDatabase {
                    processedSQL = SQLPreprocessor.preprocessSQL(sql, database: currentQueryDatabase)
                }
                return try await queryService.executeSQL(processedSQL)
            }
            guard !Task.isCancelled, !isPanelClosing else { return }

            sqlResult = result
            formattedSQLResult = formatSpecialSQLResult(for: sql, result: result)
            lastExecutedSQL = sql

            if let editContext = try await resolveSQLResultEditContext(for: sql, result: result) {
                sqlResultConnectionId = editContext.connectionId
                sqlResultDatabase = editContext.database
                sqlResultTable = editContext.table
                sqlResultColumns = editContext.columns
            } else {
                clearSQLResultEditContext()
            }
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            formattedSQLResult = nil
            clearSQLResultEditContext()
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    @MainActor
    private func clearSQLResultEditContext() {
        sqlResultConnectionId = nil
        sqlResultDatabase = nil
        sqlResultTable = nil
        sqlResultColumns = []
    }

    private func formatSpecialSQLResult(for sql: String, result: MySQLQueryResult) -> String? {
        guard result.isSuccess, result.rowCount > 0 else { return nil }
        guard SQLPreprocessor.isShowCreateTable(sql) else { return nil }
        guard let createTableColumnIndex = result.columns.firstIndex(where: { $0.caseInsensitiveCompare("Create Table") == .orderedSame }),
              let createTableRow = result.rows.first,
              createTableColumnIndex < createTableRow.count else {
            return nil
        }

        let rawSQL = createTableRow[createTableColumnIndex].displayValue
        return SQLPreprocessor.formatCreateTableSQL(rawSQL)
    }

    private func resolveSQLResultEditContext(for sql: String, result: MySQLQueryResult) async throws -> SQLResultEditContext? {
        guard let connectionId = currentQueryConnectionId,
              result.isSuccess, result.hasResults else { return nil }
        guard let target = SQLPreprocessor.extractSingleTableSelectTarget(sql, defaultDatabase: currentQueryDatabase) else {
            return nil
        }

        let structure = try await withQueryService(connectionId) { queryService in
            try await queryService.fetchTableStructure(database: target.database, table: target.table)
        }

        guard structure.contains(where: \.isPrimaryKey) else {
            return nil
        }

        let resultColumns = Set(result.columns)
        let structureColumns = Set(structure.map(\.name))
        guard resultColumns.isSubset(of: structureColumns) else {
            return nil
        }

        return SQLResultEditContext(
            connectionId: connectionId,
            database: target.database,
            table: target.table,
            columns: structure
        )
    }

    func updateSQLResultCell(rowIndex: Int, columnIndex: Int, newValue: String) async {
        guard !Task.isCancelled, !isPanelClosing else { return }
        guard let sqlResultConnectionId,
              let sqlResultDatabase,
              let sqlResultTable,
              let sqlResult,
              rowIndex < sqlResult.rows.count,
              columnIndex < sqlResult.columns.count else { return }

        let columnName = sqlResult.columns[columnIndex]
        let primaryKeyColumns = sqlResultColumns.filter(\.isPrimaryKey)

        guard !primaryKeyColumns.isEmpty else {
            errorMessage = "No primary key"
            showError = true
            return
        }

        let row = sqlResult.rows[rowIndex]
        var whereClauses: [String] = []

        for primaryKeyColumn in primaryKeyColumns {
            guard let pkIndex = sqlResult.columns.firstIndex(of: primaryKeyColumn.name) else {
                errorMessage = "Primary key column not found in SQL result: \(primaryKeyColumn.name)"
                showError = true
                return
            }

            let pkValue = row[pkIndex]
            let escapedValue = SQLPreprocessor.escapeValueForSQL(pkValue)
            whereClauses.append("`\(primaryKeyColumn.name)` = \(escapedValue)")
        }

        let escapedDatabase = "`" + sqlResultDatabase.replacingOccurrences(of: "`", with: "``") + "`"
        let escapedTable = "`" + sqlResultTable.replacingOccurrences(of: "`", with: "``") + "`"
        let escapedColumn = "`" + columnName.replacingOccurrences(of: "`", with: "``") + "`"
        let escapedNewValue = SQLPreprocessor.escapeStringValue(newValue)

        let updateSQL = """
            UPDATE \(escapedDatabase).\(escapedTable)
            SET \(escapedColumn) = \(escapedNewValue)
            WHERE \(whereClauses.joined(separator: " AND "))
            LIMIT 1
            """

        do {
            let updateResult = try await withQueryService(sqlResultConnectionId) { queryService in
                try await queryService.executeSQL(updateSQL)
            }
            guard !Task.isCancelled, !isPanelClosing else { return }

            if let error = updateResult.error {
                errorMessage = "Update failed: \(error.localizedDescription)"
                showError = true
                return
            }

            if let lastExecutedSQL {
                await executeMySQLCommand(lastExecutedSQL)
            }
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            errorMessage = "Update failed: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Table Detail Selection

    func showTableDetail(database: String, table: String, connectionId: UUID) {
        detailConnectionId = connectionId
        detailDatabase = database
        detailTable = table
        selectedTab = .data
        displayMode = .tableDetail(.data)

        enqueuePendingTask {
            await loadTableStructure(database: database, table: table, connectionId: connectionId)
            guard !Task.isCancelled else { return }
            await loadTableData(database: database, table: table, connectionId: connectionId)
        }
    }
}
