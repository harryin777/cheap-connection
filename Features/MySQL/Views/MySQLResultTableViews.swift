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
    @ObservedObject private var settingsRepo = SettingsRepository.shared
    let columns: [String]
    @Binding var columnWidths: [CGFloat]
    let renderWidths: [CGFloat]
    let rowNumberWidth: CGFloat
    let viewportWidth: CGFloat // 新增：viewport 宽度，确保根容器铺满
    let isDraggingColumn: Int?
    let onColumnDrag: (Int, CGFloat, DragGesture.Value) -> Void
    let onColumnDragEnd: () -> Void

    private let dividerWidth: CGFloat = 1
    private let headerTextColor = Color(red: 0.42, green: 0.74, blue: 0.95)

    var body: some View {
        let fontSize = CGFloat(settingsRepo.settings.dataViewFontSize)

        return HStack(spacing: 0) {
            // 行号列
            Text("#")
                .font(.system(size: fontSize - 1, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: rowNumberWidth, alignment: .center)
                .background(Color(.controlBackgroundColor))

            // 分隔线
            ResultVerticalDivider()

            // 数据列
            ForEach(Array(columns.indices), id: \.self) { columnIndex in
                Text(columns[columnIndex])
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(headerTextColor)
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

            // 尾部填充：确保整行铺满 viewport 宽度
            if totalContentWidth < viewportWidth {
                Spacer()
                    .frame(minWidth: 0)
            }
        }
        // 根容器至少铺满 viewport 宽度
        .frame(minWidth: viewportWidth, maxHeight: 24)
        .background(Color(.controlBackgroundColor))
    }

    /// 计算当前内容总宽度
    private var totalContentWidth: CGFloat {
        let dividersCount = CGFloat(columns.count) // 行号分隔线 + 列间分隔线
        let dividersWidth = dividersCount * dividerWidth
        let columnsWidth = renderWidths.reduce(0, +)
        return rowNumberWidth + dividersWidth + columnsWidth
    }
}

// MARK: - Data Row

/// 数据行视图
struct ResultDataRowView: View {
    @ObservedObject private var settingsRepo = SettingsRepository.shared
    let row: [MySQLRowValue]
    let rowIndex: Int
    let columnWidths: [CGFloat]
    let renderWidths: [CGFloat]
    let rowNumberWidth: CGFloat
    let viewportWidth: CGFloat // 新增：viewport 宽度，确保根容器铺满
    let selectedCell: CellPosition?
    let editingCell: CellPosition?
    let editingText: String
    let isEditingFocused: FocusState<Bool>.Binding
    let onEditingTextChange: (String) -> Void
    let onCellSelect: (CellPosition) -> Void
    let onStartEditing: (CellPosition, MySQLRowValue) -> Void
    let onFinishEditing: () -> Void
    let onCancelEditing: () -> Void

    private let dividerWidth: CGFloat = 1

    var body: some View {
        let fontSize = CGFloat(settingsRepo.settings.dataViewFontSize)

        return HStack(spacing: 0) {
            // 行号
            Text("\(rowIndex + 1)")
                .font(.system(size: fontSize - 1, design: .monospaced))
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
                    onEditingTextChange: onEditingTextChange,
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

            // 尾部填充：确保整行铺满 viewport 宽度
            if totalContentWidth < viewportWidth {
                Spacer()
                    .frame(minWidth: 0)
            }
        }
        // 根容器至少铺满 viewport 宽度
        .frame(minWidth: viewportWidth, maxHeight: 22)
        .background(rowBackgroundColor(rowIndex))
    }

    /// 计算当前内容总宽度
    private var totalContentWidth: CGFloat {
        let dividersCount = CGFloat(row.count) // 行号分隔线 + 列间分隔线
        let dividersWidth = dividersCount * dividerWidth
        let columnsWidth = renderWidths.reduce(0, +)
        return rowNumberWidth + dividersWidth + columnsWidth
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
