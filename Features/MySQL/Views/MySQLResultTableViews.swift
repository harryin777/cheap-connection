//
//  MySQLResultTableViews.swift
//  cheap-connection
//
//  MySQL结果表格视图组件
//

import SwiftUI

// MARK: - Pinned Header Row

/// 固定表头行
struct ResultPinnedHeaderView: View {
    let columns: [String]
    @Binding var columnWidths: [CGFloat]
    let renderWidths: [CGFloat]
    let rowNumberWidth: CGFloat
    let isDraggingColumn: Int?
    let onColumnDrag: (Int, CGFloat, DragGesture.Value) -> Void
    let onColumnDragEnd: () -> Void

    private let dividerWidth: CGFloat = 1

    var body: some View {
        HStack(spacing: 0) {
            // 行号列
            Text("#")
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: rowNumberWidth, alignment: .center)
                .background(Color(.controlBackgroundColor))

            // 分隔线
            ResultVerticalDivider()

            // 数据列
            ForEach(Array(columns.indices), id: \.self) { columnIndex in
                Text(columns[columnIndex])
                    .font(.system(size: 10, design: .monospaced))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
                    .frame(width: renderWidths[columnIndex], alignment: .leading)
                    .background(Color(.controlBackgroundColor))

                // 列分隔线（可拖拽调整）
                if columnIndex < columns.count - 1 {
                    ResultColumnResizer(
                        columnIndex: columnIndex,
                        isDragging: isDraggingColumn == columnIndex,
                        columnWidths: $columnWidths,
                        onDrag: onColumnDrag,
                        onColumnDragEnd: onColumnDragEnd
                    )
                }
            }
        }
        .frame(height: 24)
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Data Row

/// 数据行视图
struct ResultDataRowView: View {
    let row: [MySQLRowValue]
    let rowIndex: Int
    let columnWidths: [CGFloat]
    let renderWidths: [CGFloat]
    let rowNumberWidth: CGFloat
    let selectedCell: CellPosition?
    let editingCell: CellPosition?
    let editingText: String
    let isEditingFocused: FocusState<Bool>.Binding
    let onCellSelect: (CellPosition) -> Void
    let onStartEditing: (CellPosition, MySQLRowValue) -> Void
    let onFinishEditing: () -> Void
    let onCancelEditing: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 行号
            Text("\(rowIndex + 1)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: rowNumberWidth, alignment: .center)
                .background(rowBackgroundColor(rowIndex))

            // 分隔线
            ResultVerticalDivider()

            // 数据单元格
            ForEach(Array(row.indices), id: \.self) { columnIndex in
                ResultDataCellView(
                    value: row[columnIndex],
                    rowIndex: rowIndex,
                    columnIndex: columnIndex,
                    isSelected: selectedCell == CellPosition(row: rowIndex, column: columnIndex),
                    isEditing: editingCell == CellPosition(row: rowIndex, column: columnIndex),
                    editingText: editingText,
                    isEditingFocused: isEditingFocused,
                    onSelect: { onCellSelect(CellPosition(row: rowIndex, column: columnIndex)) },
                    onStartEditing: { onStartEditing(CellPosition(row: rowIndex, column: columnIndex), row[columnIndex]) },
                    onFinishEditing: onFinishEditing,
                    onCancelEditing: onCancelEditing
                )
                .frame(width: renderWidths[columnIndex], alignment: .leading)

                // 列分隔线
                if columnIndex < row.count - 1 {
                    ResultVerticalDivider()
                }
            }
        }
        .frame(height: 22)
        .background(rowBackgroundColor(rowIndex))
    }

    private func rowBackgroundColor(_ rowIndex: Int) -> Color {
        rowIndex % 2 == 0 ? Color.clear : Color(.controlBackgroundColor).opacity(0.3)
    }
}

// MARK: - Column Resizer

/// 列宽调整器
struct ResultColumnResizer: View {
    let columnIndex: Int
    let isDragging: Bool
    @Binding var columnWidths: [CGFloat]
    let onDrag: (Int, CGFloat, DragGesture.Value) -> Void
    let onColumnDragEnd: () -> Void

    private let minColumnWidth: CGFloat = 60
    private let maxColumnWidth: CGFloat = 400
    private let dividerWidth: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor : Color(nsColor: .separatorColor))
            .frame(width: isDragging ? 2 : dividerWidth)
            .frame(width: dividerWidth)
            .overlay {
                Color.clear
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                onDrag(columnIndex, minColumnWidth, value)
                            }
                            .onEnded { _ in
                                onColumnDragEnd()
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
}

// MARK: - Vertical Divider

/// 垂直分隔线
struct ResultVerticalDivider: View {
    private let dividerWidth: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: dividerWidth)
    }
}
