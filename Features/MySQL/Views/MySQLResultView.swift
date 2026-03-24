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

    // MARK: - Pagination State
    @State private var currentPage: Int = 1
    private let pageSize: Int = 500

    private let rowNumberWidth: CGFloat = 40
    private let dividerWidth: CGFloat = 1
    private let minColumnWidth: CGFloat = 60

    init(result: MySQLQueryResult, onCellEdit: ((Int, Int, String) async -> Void)? = nil) {
        self.result = result
        self.onCellEdit = onCellEdit
        _columnWidths = State(initialValue: Array(repeating: 120, count: result.columns.count))
    }

    // MARK: - Pagination Computed Properties

    private var totalPages: Int {
        let total = result.rowCount
        return (total + pageSize - 1) / pageSize
    }

    private var startIndex: Int {
        (currentPage - 1) * pageSize
    }

    private var endIndex: Int {
        min(startIndex + pageSize, result.rowCount)
    }

    private var visibleRows: [[MySQLRowValue]] {
        guard result.rowCount > 0 else { return [] }
        return Array(result.rows[startIndex..<endIndex])
    }

    /// 计算渲染列宽：当列总宽不足以填满 viewport 时，将剩余宽度分配给最后一列
    private func calculateRenderColumnWidths(viewportWidth: CGFloat, columnCount: Int) -> [CGFloat] {
        guard columnCount > 0 else { return [] }

        // 计算可用宽度 = viewport - 行号列 - (n+1)个分隔线
        let totalDividerWidth = CGFloat(columnCount + 1) * dividerWidth
        let availableWidth = viewportWidth - rowNumberWidth - totalDividerWidth

        // 原始列总宽
        let totalColumnWidth = columnWidths.reduce(0, +)

        if totalColumnWidth >= availableWidth {
            // 列总宽已超过可用宽度，使用原始列宽（允许横向滚动）
            return columnWidths
        } else {
            // 列总宽不足，将剩余宽度加到最后一列
            var renderWidths = columnWidths
            let extraWidth = availableWidth - totalColumnWidth
            renderWidths[columnCount - 1] += extraWidth
            return renderWidths
        }
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

            // 底部分页控件
            if result.hasResults && totalPages > 1 {
                Divider()
                paginationBar
            }
        }
        .onChange(of: result.rowCount) { _, _ in
            // 当结果行数变化时重置页码
            currentPage = 1
        }
    }

    // MARK: - Pagination Bar

    private var paginationBar: some View {
        HStack(spacing: 8) {
            // 上一页
            Button {
                if currentPage > 1 {
                    currentPage -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .disabled(currentPage <= 1)

            // 页码显示
            Text("\(currentPage)/\(totalPages)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 40)

            // 下一页
            Button {
                if currentPage < totalPages {
                    currentPage += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages)

            Divider()
                .frame(height: 16)

            // 行范围显示
            Text("\(startIndex + 1)-\(endIndex) / \(result.rowCount) 行")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
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
        GeometryReader { geometry in
            let renderWidths = calculateRenderColumnWidths(
                viewportWidth: geometry.size.width,
                columnCount: result.columns.count
            )

            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: pinnedHeaderView(renderWidths: renderWidths, viewportWidth: geometry.size.width)) {
                        ForEach(Array(visibleRows.indices), id: \.self) { localIndex in
                            ResultDataRowView(
                                row: visibleRows[localIndex],
                                rowIndex: startIndex + localIndex,
                                columnWidths: columnWidths,
                                renderWidths: renderWidths,
                                rowNumberWidth: rowNumberWidth,
                                viewportWidth: geometry.size.width,
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
                .frame(
                    minWidth: geometry.size.width,
                    minHeight: geometry.size.height,
                    alignment: .topLeading
                )
            }
        }
    }

    private func pinnedHeaderView(renderWidths: [CGFloat], viewportWidth: CGFloat) -> some View {
        ResultPinnedHeaderView(
            columns: result.columns,
            columnWidths: $columnWidths,
            renderWidths: renderWidths,
            rowNumberWidth: rowNumberWidth,
            viewportWidth: viewportWidth,
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
        error: nil,
        totalCount: nil
    )

    MySQLResultView(result: previewResult)
        .frame(width: 600, height: 300)
}
