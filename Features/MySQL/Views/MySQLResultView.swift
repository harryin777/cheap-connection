//
//  MySQLResultView.swift
//  cheap-connection
//
//  MySQL查询结果展示视图 - DataGrip风格紧凑表格
//

import SwiftUI

/// MySQL查询结果视图 - DataGrip风格紧凑表格
struct MySQLResultView: View {
    let result: MySQLQueryResult
    @State private var selectedRow: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 执行信息状态栏
            if result.isSuccess {
                statusBarView
            }

            Divider()

            // 内容区域
            Group {
                if let error = result.error {
                    errorView(error: error)
                } else if result.hasResults {
                    resultTableView
                } else {
                    emptyResultView
                }
            }
        }
    }

    // MARK: - Subviews

    private var statusBarView: some View {
        HStack(spacing: 12) {
            // 行数信息
            if let rows = result.executionInfo.affectedRows {
                Label("\(rows) 行受影响", systemImage: "checkmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else if result.rowCount > 0 {
                Label("\(result.rowCount) 行", systemImage: "list.bullet")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            // 执行时间
            Text(result.formattedDuration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer()

            // 状态
            if result.isSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.windowBackgroundColor))
    }

    private var resultTableView: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // 表头
                headerRow

                // 数据行
                ForEach(Array(result.rows.enumerated()), id: \.offset) { index, row in
                    dataRow(row: row, rowIndex: index)
                }
            }
            .padding(4)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            // 行号列
            Text("#")
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .center)
                .padding(.horizontal, 4)
                .background(Color(.controlBackgroundColor))

            // 数据列
            ForEach(result.columns, id: \.self) { column in
                Text(column)
                    .font(.system(size: 10, design: .monospaced))
                    .fontWeight(.semibold)
                    .frame(minWidth: 60, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.controlBackgroundColor))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dataRow(row: [MySQLRowValue], rowIndex: Int) -> some View {
        HStack(spacing: 0) {
            // 行号
            Text("\(rowIndex + 1)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .center)
                .padding(.horizontal, 4)
                .background(selectedRow == rowIndex ? Color.accentColor.opacity(0.15) : Color.clear)

            // 数据值
            ForEach(Array(row.enumerated()), id: \.offset) { columnIndex, value in
                dataCell(value: value, rowIndex: rowIndex, columnIndex: columnIndex)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowIndex % 2 == 0 ? Color.clear : Color(.controlBackgroundColor).opacity(0.3))
        .onTapGesture {
            selectedRow = rowIndex
        }
    }

    private func dataCell(value: MySQLRowValue, rowIndex: Int, columnIndex: Int) -> some View {
        Text(value.displayValue)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(value.isNull ? .tertiary : .primary)
            .frame(minWidth: 60, alignment: value.isNull ? .center : .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                selectedRow == rowIndex
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear
            )
            .lineLimit(1)
            .onTapGesture {
                selectedRow = rowIndex
            }
    }

    private func errorView(error: AppError) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 16))

                Text(error.localizedDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

            if error.isRetryable {
                Button("重试") {
                    // 重试操作由父视图处理
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.05))
    }

    private var emptyResultView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            Text("查询成功，无结果")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text("执行成功但未返回数据")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let previewResult = MySQLQueryResult(
        columns: ["id", "username", "email", "created_at"],
        rows: [MySQLRowValue.previewRow],
        executionInfo: MySQLExecutionInfo(executedAt: Date(), duration: 0.0234, affectedRows: nil, isQuery: true),
        error: nil
    )

    MySQLResultView(result: previewResult)
        .frame(width: 600, height: 300)
}
