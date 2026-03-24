//
//  MySQLRightPanelRedisBridge.swift
//  cheap-connection
//
//  MySQL 右侧面板中的 Redis 命令桥接
//

import Foundation

extension MySQLRightPanelView {
    func executeRedisCommand(_ command: String, connection: ConnectionConfig) async {
        do {
            guard let password = try connectionManager.getPassword(for: connection.id) else {
                errorMessage = "Password not found"
                showError = true
                return
            }

            let redisService = RedisService(connectionConfig: connection)
            try await redisService.connect(config: connection, password: password.isEmpty ? nil : password)

            if let dbStr = currentQueryDatabase, dbStr.hasPrefix("DB") {
                let dbIndex = Int(dbStr.dropFirst(2)) ?? 0
                try await redisService.selectDatabase(dbIndex)
            }

            let startTime = Date()
            let result = try await redisService.executeCommand(command)
            let duration = Date().timeIntervalSince(startTime)

            await redisService.disconnect()
            sqlResult = convertRedisResultToMySQLResult(result, duration: duration)
        } catch {
            guard !Task.isCancelled, !isPanelClosing else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func convertRedisResultToMySQLResult(_ redisResult: RedisCommandResult, duration: TimeInterval) -> MySQLQueryResult {
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
                error: .queryError(redisResult.errorMessage ?? "Unknown error"),
                totalCount: nil
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
                error: nil,
                totalCount: nil
            )
        }

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
            error: nil,
            totalCount: nil
        )
    }

    private func convertRedisValueToRows(_ value: RedisValue) -> (columns: [String], rows: [[MySQLRowValue]]) {
        switch value {
        case .string(let string):
            return (["Result"], [[.string(string)]])
        case .int(let number):
            return (["Result"], [[.int(number)]])
        case .double(let number):
            return (["Result"], [[.double(number)]])
        case .status(let status):
            return (["Result"], [[.string(status)]])
        case .data(let data):
            return (["Result"], [[.string("<data: \(data.count) bytes>")]])
        case .array(let items):
            guard !items.isEmpty else {
                return (["Result"], [[.string("(empty list or set)")]])
            }
            let rows = items.enumerated().map { index, value in
                redisArrayRow(index: index, value: value)
            }
            return (["Index", "Value"], rows)
        case .map(let dictionary):
            let rows: [[MySQLRowValue]] = dictionary.map { entry in
                [
                    MySQLRowValue.string(entry.key),
                    MySQLRowValue.string(entry.value.stringValue ?? entry.value.description)
                ]
            }
            return (["Key", "Value"], rows)
        case .error(let error):
            return (["Error"], [[.string(error)]])
        case .null:
            return (["Result"], [[.null]])
        }
    }

    private func redisArrayRow(index: Int, value: RedisValue) -> [MySQLRowValue] {
        let position: MySQLRowValue = .int(index + 1)

        switch value {
        case .string(let string):
            return [position, .string(string)]
        case .int(let number):
            return [position, .int(number)]
        case .double(let number):
            return [position, .double(number)]
        case .status(let status):
            return [position, .string(status)]
        case .data(let data):
            return [position, .string("<data: \(data.count) bytes>")]
        case .error(let error):
            return [position, .string("(error) \(error)")]
        case .null:
            return [position, .null]
        case .array:
            return [position, .string("(nested array)")]
        case .map:
            return [position, .string("(nested map)")]
        }
    }
}
