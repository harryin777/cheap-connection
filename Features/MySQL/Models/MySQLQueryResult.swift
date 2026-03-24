//
//  MySQLQueryResult.swift
//  cheap-connection
//
//  MySQL查询结果
//

import Foundation

/// MySQL执行信息
/// 记录查询执行的元数据
struct MySQLExecutionInfo: Sendable {
    /// 执行时间
    let executedAt: Date

    /// 执行耗时（秒）
    let duration: TimeInterval

    /// 影响的行数（对于INSERT/UPDATE/DELETE）
    let affectedRows: Int?

    /// 是否为查询语句（SELECT）
    let isQuery: Bool
}

/// MySQL查询结果
/// 包含列定义、行数据和执行信息
struct MySQLQueryResult: Sendable {
    /// 列名列表
    let columns: [String]

    /// 行数据（每行是一个MySQLRowValue数组）
    let rows: [[MySQLRowValue]]

    /// 执行信息
    let executionInfo: MySQLExecutionInfo

    /// 错误信息（如果有）
    let error: AppError?

    /// 总行数（用于分页）
    let totalCount: Int?

    // MARK: - Computed Properties

    /// 是否执行成功
    var isSuccess: Bool {
        error == nil
    }

    /// 是否有结果数据
    var hasResults: Bool {
        !columns.isEmpty && !rows.isEmpty
    }

    /// 结果行数
    var rowCount: Int {
        rows.count
    }

    /// 列数
    var columnCount: Int {
        columns.count
    }

    /// 格式化的执行时间
    var formattedDuration: String {
        let ms = executionInfo.duration * 1000
        if ms < 1000 {
            return String(format: "%.2f ms", ms)
        } else {
            return String(format: "%.2f s", executionInfo.duration)
        }
    }

    /// 获取指定行指定列的值
    subscript(row: Int, column: Int) -> MySQLRowValue {
        guard row >= 0, row < rows.count,
              column >= 0, column < columns.count else {
            return .null
        }
        return rows[row][column]
    }

    /// 获取指定行指定列名的值
    subscript(row: Int, column columnName: String) -> MySQLRowValue {
        guard let columnIndex = columns.firstIndex(of: columnName),
              row >= 0, row < rows.count else {
            return .null
        }
        return rows[row][columnIndex]
    }
}

// MARK: - Static Factory Methods

extension MySQLQueryResult {
    /// 创建空结果
    static func empty(executionInfo: MySQLExecutionInfo) -> MySQLQueryResult {
        MySQLQueryResult(
            columns: [],
            rows: [],
            executionInfo: executionInfo,
            error: nil,
            totalCount: nil
        )
    }

    /// 创建错误结果
    static func error(_ error: AppError, startTime: Date = Date()) -> MySQLQueryResult {
        let executionInfo = MySQLExecutionInfo(
            executedAt: startTime,
            duration: Date().timeIntervalSince(startTime),
            affectedRows: nil,
            isQuery: true
        )
        return MySQLQueryResult(
            columns: [],
            rows: [],
            executionInfo: executionInfo,
            error: error,
            totalCount: nil
        )
    }
}

// MARK: - Preview Support

extension MySQLQueryResult {
    /// 预览用例数据
    static let previewData: MySQLQueryResult = {
        let executionInfo = MySQLExecutionInfo(
            executedAt: Date(),
            duration: 0.0234,
            affectedRows: nil,
            isQuery: true
        )
        return MySQLQueryResult(
            columns: ["id", "username", "email", "created_at", "is_active"],
            rows: [
                MySQLRowValue.previewRow,
                MySQLRowValue.previewRowWithNull,
            ],
            executionInfo: executionInfo,
            error: nil,
            totalCount: 1000
        )
    }()

    static let previewError: MySQLQueryResult = {
        let executionInfo = MySQLExecutionInfo(
            executedAt: Date(),
            duration: 0.0012,
            affectedRows: nil,
            isQuery: true
        )
        return MySQLQueryResult(
            columns: [],
            rows: [],
            executionInfo: executionInfo,
            error: .queryError("Unknown column 'unknown_field' in 'field list'"),
            totalCount: nil
        )
    }()
}
