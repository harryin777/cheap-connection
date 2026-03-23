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
            let updateResult = try await withQueryService(currentQueryConnectionId) { queryService in
                try await queryService.executeSQL(sql)
            }
            guard !Task.isCancelled, !isPanelClosing else { return }
            if let error = updateResult.error {
                errorMessage = "Update failed: \(error.localizedDescription)"
                showError = true
            } else {
                await loadTableData(database: database, table: table)
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

        // Check if current connection is Redis
        guard let connection = connectionManager.connections.first(where: { $0.id == currentQueryConnectionId }) else {
            errorMessage = "Connection not found"
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

    private func executeRedisCommand(_ command: String, connection: ConnectionConfig) async {
        do {
            // Get password
            guard let password = try connectionManager.getPassword(for: connection.id) else {
                errorMessage = "Password not found"
                showError = true
                return
            }

            // Create Redis service
            let redisService = RedisService(connectionConfig: connection)
            try await redisService.connect(config: connection, password: password.isEmpty ? nil : password)

            // Select database if specified
            if let dbStr = currentQueryDatabase, dbStr.hasPrefix("DB") {
                let dbIndex = Int(dbStr.dropFirst(2)) ?? 0
                try await redisService.selectDatabase(dbIndex)
            }

            // Execute command
            let startTime = Date()
            let result = try await redisService.executeCommand(command)
            let duration = Date().timeIntervalSince(startTime)

            // Disconnect
            await redisService.disconnect()

            // Convert Redis result to MySQL result format for display
            sqlResult = convertRedisResultToMySQLResult(result, command: command, duration: duration)
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func convertRedisResultToMySQLResult(_ redisResult: RedisCommandResult, command: String, duration: TimeInterval) -> MySQLQueryResult {
        let executedAt = Date()

        if !redisResult.success {
            return MySQLQueryResult(
                columns: ["Error"],
                rows: [[.string(redisResult.errorMessage ?? "Unknown error")]],
                executionInfo: MySQLExecutionInfo(
                    executedAt: executedAt,
                    duration: duration,
                    affectedRows: 0,
                    isQuery: true
                ),
                error: .queryError(redisResult.errorMessage ?? "Unknown error")
            )
        }

        guard let value = redisResult.value else {
            return MySQLQueryResult(
                columns: ["Result"],
                rows: [[.string("OK")]],
                executionInfo: MySQLExecutionInfo(
                    executedAt: executedAt,
                    duration: duration,
                    affectedRows: redisResult.affectedKeys ?? 0,
                    isQuery: true
                ),
                error: nil
            )
        }

        // Convert RedisValue to display rows
        let (columns, rows) = convertRedisValueToRows(value)
        return MySQLQueryResult(
            columns: columns,
            rows: rows,
            executionInfo: MySQLExecutionInfo(
                executedAt: executedAt,
                duration: duration,
                affectedRows: redisResult.affectedKeys ?? rows.count,
                isQuery: true
            ),
            error: nil
        )
    }

    private func convertRedisValueToRows(_ value: RedisValue) -> (columns: [String], rows: [[MySQLRowValue]]) {
        switch value {
        case .string(let str):
            return (["Result"], [[.string(str)]])
        case .int(let num):
            return (["Result"], [[.int(num)]])
        case .double(let num):
            return (["Result"], [[.double(num)]])
        case .status(let s):
            return (["Result"], [[.string(s)]])
        case .data(let data):
            return (["Result"], [[.string("<data: \(data.count) bytes>")]])
        case .array(let arr):
            if arr.isEmpty {
                return (["Result"], [[.string("(empty list or set)")]])
            }
            var rows: [[MySQLRowValue]] = []
            for (index, item) in arr.enumerated() {
                switch item {
                case .string(let str):
                    rows.append([.int(index + 1), .string(str)])
                case .int(let num):
                    rows.append([.int(index + 1), .int(num)])
                case .double(let num):
                    rows.append([.int(index + 1), .double(num)])
                case .status(let s):
                    rows.append([.int(index + 1), .string(s)])
                case .data(let data):
                    rows.append([.int(index + 1), .string("<data: \(data.count) bytes>")])
                case .error(let err):
                    rows.append([.int(index + 1), .string("(error) \(err)")])
                case .null:
                    rows.append([.int(index + 1), .null])
                case .array:
                    rows.append([.int(index + 1), .string("(nested array)")])
                case .map:
                    rows.append([.int(index + 1), .string("(nested map)")])
                }
            }
            return (["Index", "Value"], rows)
        case .map(let dict):
            var rows: [[MySQLRowValue]] = []
            for (key, val) in dict {
                rows.append([.string(key), .string(val.stringValue ?? val.description)])
            }
            return (["Key", "Value"], rows)
        case .error(let err):
            return (["Error"], [[.string(err)]])
        case .null:
            return (["Result"], [[.null]])
        }
    }

    // MARK: - Table Detail Selection

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
