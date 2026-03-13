//
//  MySQLResultView.swift
//  cheap-connection
//
//  MySQL查询结果展示视图 - DataGrip风格紧凑表格
//

import SwiftUI

/// 选中的单元格位置
struct CellPosition: Equatable, Hashable {
    let row: Int
    let column: Int
}

/// MySQL查询结果视图 - DataGrip风格紧凑表格（固定表头）
struct MySQLResultView: View {
    let result: MySQLQueryResult
    var onCellEdit: ((Int, Int, String) async -> Void)? = nil

    @State private var selectedCell: CellPosition?
    @State private var editingCell: CellPosition?
    @State private var editingText: String = ""
    @State private var columnWidths: [CGFloat]
    @State private var isDraggingColumn: Int?
    @State private var dragStartWidth: CGFloat = 0
    @FocusState private var isEditingFocused: Bool

    private let rowNumberWidth: CGFloat = 40

    init(result: MySQLQueryResult, onCellEdit: ((Int, Int, String) async -> Void)? = nil) {
        self.result = result
        self.onCellEdit = onCellEdit
        _columnWidths = State(initialValue: Array(repeating: 120, count: result.columns.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if result.isSuccess {
                statusBarView
            }

            Divider()

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

    // MARK: - Status Bar

    private var statusBarView: some View {
        HStack(spacing: 12) {
            if let rows = result.executionInfo.affectedRows {
                Label("\(rows) 行受影响", systemImage: "checkmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else if result.rowCount > 0 {
                Label("\(result.rowCount) 行", systemImage: "list.bullet")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Text(result.formattedDuration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer()

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

    // MARK: - Result Table

    private var resultTableView: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section(header: pinnedHeaderView) {
                    ForEach(Array(result.rows.enumerated()), id: \.offset) { index, row in
                        ResultDataRowView(
                            row: row,
                            rowIndex: index,
                            columnWidths: columnWidths,
                            rowNumberWidth: rowNumberWidth,
                            selectedCell: selectedCell,
                            editingCell: editingCell,
                            editingText: editingText,
                            isEditingFocused: $isEditingFocused,
                            onCellSelect: { pos in selectedCell = pos },
                            onStartEditing: startEditing,
                            onFinishEditing: finishEditing,
                            onCancelEditing: cancelEditing
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var pinnedHeaderView: some View {
        ResultPinnedHeaderView(
            columns: result.columns,
            columnWidths: $columnWidths,
            rowNumberWidth: rowNumberWidth,
            isDraggingColumn: isDraggingColumn,
            onColumnDrag: handleColumnDrag,
            onColumnDragEnd: { isDraggingColumn = nil }
        )
    }

    // MARK: - Editing Actions

    private func startEditing(cellPos: CellPosition, value: MySQLRowValue) {
        guard onCellEdit != nil else { return }
        editingCell = cellPos
        editingText = value.isNull ? "" : value.displayValue
        selectedCell = cellPos
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isEditingFocused = true
        }
    }

    private func finishEditing() {
        guard let cell = editingCell else { return }
        let originalValue = result.rows[cell.row][cell.column].displayValue

        if editingText != originalValue {
            Task {
                await onCellEdit?(cell.row, cell.column, editingText)
            }
        }
        editingCell = nil
        editingText = ""
    }

    private func cancelEditing() {
        editingCell = nil
        editingText = ""
    }

    // MARK: - Column Resize

    private func handleColumnDrag(columnIndex: Int, minWidth: CGFloat, value: DragGesture.Value) {
        if isDraggingColumn != columnIndex {
            isDraggingColumn = columnIndex
            dragStartWidth = columnWidths[columnIndex]
        }
        let newWidth = dragStartWidth + value.translation.width
        let maxWidth: CGFloat = 400
        let clampedWidth = min(maxWidth, max(minWidth, newWidth))
        columnWidths[columnIndex] = clampedWidth.rounded(.toNearestOrAwayFromZero)
    }

    // MARK: - Error & Empty Views

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
                Button("重试") { }
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
        rows: [
            MySQLRowValue.previewRow,
            [.int(2), .string("test_user"), .string("test@example.com"), .string("2024-01-15 10:30:00")]
        ],
        executionInfo: MySQLExecutionInfo(executedAt: Date(), duration: 0.0234, affectedRows: nil, isQuery: true),
        error: nil
    )

    MySQLResultView(result: previewResult)
        .frame(width: 600, height: 300)
}
