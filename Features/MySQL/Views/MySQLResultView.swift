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
    var onCellEdit: ((Int, Int, String) async -> Void)? = nil  // rowIndex, columnIndex, newValue

    @State private var selectedCell: CellPosition?
    @State private var editingCell: CellPosition?
    @State private var editingText: String = ""
    @State private var columnWidths: [CGFloat]
    @State private var isDraggingColumn: Int?
    @State private var dragStartWidth: CGFloat = 0
    @FocusState private var isEditingFocused: Bool

    // 最小和最大列宽
    private let minColumnWidth: CGFloat = 60
    private let maxColumnWidth: CGFloat = 400
    private let defaultColumnWidth: CGFloat = 120
    private let rowNumberWidth: CGFloat = 40
    private let dividerWidth: CGFloat = 1

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

    // MARK: - Subviews

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

    private var resultTableView: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                // 表头作为 Section header，会自动固定在顶部
                Section(header: pinnedHeaderRow) {
                    // 数据行
                    ForEach(Array(result.rows.enumerated()), id: \.offset) { index, row in
                        dataRow(row: row, rowIndex: index)
                    }
                }
            }
        }
    }

    /// 固定表头（用于 LazyVStack pinnedViews）
    private var pinnedHeaderRow: some View {
        HStack(spacing: 0) {
            // 行号列
            Text("#")
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: rowNumberWidth, alignment: .center)
                .background(Color(.controlBackgroundColor))

            // 分隔线
            verticalDivider

            // 数据列
            ForEach(Array(result.columns.indices), id: \.self) { columnIndex in
                Text(result.columns[columnIndex])
                    .font(.system(size: 10, design: .monospaced))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
                    .frame(width: columnWidths[columnIndex], alignment: .leading)
                    .background(Color(.controlBackgroundColor))

                // 列分隔线（可拖拽调整）
                if columnIndex < result.columns.count - 1 {
                    columnResizer(columnIndex: columnIndex)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 24)
        .background(Color(.controlBackgroundColor))
    }

    private func dataRow(row: [MySQLRowValue], rowIndex: Int) -> some View {
        HStack(spacing: 0) {
            // 行号
            Text("\(rowIndex + 1)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: rowNumberWidth, alignment: .center)
                .background(rowBackgroundColor(rowIndex))

            // 分隔线
            verticalDivider

            // 数据单元格
            ForEach(Array(row.indices), id: \.self) { columnIndex in
                dataCell(value: row[columnIndex], rowIndex: rowIndex, columnIndex: columnIndex)
                    .frame(width: columnWidths[columnIndex], alignment: .leading)

                // 列分隔线
                if columnIndex < row.count - 1 {
                    verticalDivider
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 22)
        .background(rowBackgroundColor(rowIndex))
    }

    private func dataCell(value: MySQLRowValue, rowIndex: Int, columnIndex: Int) -> some View {
        let cellPos = CellPosition(row: rowIndex, column: columnIndex)
        let isSelected = selectedCell == cellPos
        let isEditing = editingCell == cellPos
        let displayText = value.isNull ? "NULL" : value.displayValue

        return Group {
            if isEditing {
                // 编辑模式
                TextField("", text: $editingText)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 6)
                    .focused($isEditingFocused)
                    .onSubmit {
                        finishEditing()
                    }
                    .onExitCommand {
                        cancelEditing()
                    }
            } else if value.isNull {
                Text("NULL")
                    .font(.system(size: 11, design: .monospaced).italic())
                    .foregroundStyle(.tertiary)
            } else {
                Text(displayText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, isEditing ? 0 : 8)
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.2) :
            isEditing ? Color.accentColor.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // 双击进入编辑模式
            startEditing(cellPos: cellPos, value: value)
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // 单击选中
                    selectedCell = cellPos
                }
        )
        .help(displayText)
    }

    private func startEditing(cellPos: CellPosition, value: MySQLRowValue) {
        guard onCellEdit != nil else { return }
        editingCell = cellPos
        editingText = value.isNull ? "" : value.displayValue
        selectedCell = cellPos
        // 延迟设置焦点，确保 TextField 已经渲染
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isEditingFocused = true
        }
    }

    private func finishEditing() {
        guard let cell = editingCell else { return }
        let originalValue = result.rows[cell.row][cell.column].displayValue

        // 只有值改变时才触发保存
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

    private func dataCellContent(value: MySQLRowValue) -> some View {
        Group {
            if value.isNull {
                Text("NULL")
                    .font(.system(size: 11, design: .monospaced).italic())
                    .foregroundStyle(.tertiary)
            } else {
                Text(value.displayValue)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 8)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private func rowBackgroundColor(_ rowIndex: Int) -> Color {
        rowIndex % 2 == 0 ? Color.clear : Color(.controlBackgroundColor).opacity(0.3)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: dividerWidth)
    }

    private func columnResizer(columnIndex: Int) -> some View {
        Rectangle()
            .fill(isDraggingColumn == columnIndex ? Color.accentColor : Color(nsColor: .separatorColor))
            .frame(width: isDraggingColumn == columnIndex ? 2 : dividerWidth)
            .frame(width: dividerWidth)
            .overlay {
                Color.clear
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if isDraggingColumn != columnIndex {
                                    isDraggingColumn = columnIndex
                                    dragStartWidth = columnWidths[columnIndex]
                                }
                                let newWidth = dragStartWidth + value.translation.width
                                let clampedWidth = min(maxColumnWidth, max(minColumnWidth, newWidth))
                                columnWidths[columnIndex] = clampedWidth.rounded(.toNearestOrAwayFromZero)
                            }
                            .onEnded { _ in
                                isDraggingColumn = nil
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
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
                Button("重试") {
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
