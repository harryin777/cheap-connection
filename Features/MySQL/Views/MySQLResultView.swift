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

    @ObservedObject private var settingsRepo = SettingsRepository.shared

    @State var selectedCell: CellPosition?
    @State var editingCell: CellPosition?
    @State var editingText: String = ""
    @State var columnWidths: [CGFloat]
    @State var isDraggingColumn: Int?
    @State var dragStartWidth: CGFloat = 0
    @FocusState var isEditingFocused: Bool

    // MARK: - Pagination State
    @State var currentPage: Int = 1
    let pageSize: Int = 500

    let rowNumberWidth: CGFloat = 40
    let dividerWidth: CGFloat = 1
    let minColumnWidth: CGFloat = 60

    init(result: MySQLQueryResult, onCellEdit: ((Int, Int, String) async -> Void)? = nil) {
        self.result = result
        self.onCellEdit = onCellEdit
        _columnWidths = State(initialValue: Array(repeating: 120, count: result.columns.count))
    }

    // MARK: - Pagination Computed Properties

    var totalPages: Int {
        let total = result.rowCount
        return (total + pageSize - 1) / pageSize
    }

    var startIndex: Int {
        (currentPage - 1) * pageSize
    }

    var endIndex: Int {
        min(startIndex + pageSize, result.rowCount)
    }

    var visibleRows: [[MySQLRowValue]] {
        guard result.rowCount > 0 else { return [] }
        return Array(result.rows[startIndex..<endIndex])
    }

    /// 计算渲染列宽：当列总宽不足以填满 viewport 时，将剩余宽度分配给最后一列
    func calculateRenderColumnWidths(viewportWidth: CGFloat, columnCount: Int) -> [CGFloat] {
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
