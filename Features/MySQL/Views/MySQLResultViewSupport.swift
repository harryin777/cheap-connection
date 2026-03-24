//
//  MySQLResultViewSupport.swift
//  cheap-connection
//
//  MySQL 查询结果视图的状态栏、分页与编辑辅助逻辑
//

import SwiftUI

extension MySQLResultView {
    var paginationBar: some View {
        let fontSize = CGFloat(SettingsRepository.shared.settings.tabBarFontSize)

        return HStack(spacing: 8) {
            Button {
                if currentPage > 1 {
                    currentPage -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: fontSize))
            }
            .buttonStyle(.plain)
            .disabled(currentPage <= 1)

            Text("\(currentPage)/\(totalPages)")
                .font(.system(size: fontSize - 1, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 40)

            Button {
                if currentPage < totalPages {
                    currentPage += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: fontSize))
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages)

            Divider()
                .frame(height: 16)

            Text("\(startIndex + 1)-\(endIndex) / \(result.rowCount) 行")
                .font(.system(size: fontSize - 1))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
    }

    var statusBarView: some View {
        let fontSize = CGFloat(SettingsRepository.shared.settings.tabBarFontSize)

        return HStack(spacing: 12) {
            if let rows = result.executionInfo.affectedRows {
                Label("\(rows) 行受影响", systemImage: "checkmark.circle")
                    .font(.system(size: fontSize - 1))
                    .foregroundStyle(.secondary)
            } else if result.rowCount > 0 {
                Label("\(result.rowCount) 行", systemImage: "list.bullet")
                    .font(.system(size: fontSize - 1))
                    .foregroundStyle(.secondary)
            }

            Text(result.formattedDuration)
                .font(.system(size: fontSize - 1, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer()

            if result.isSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: fontSize - 1))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.windowBackgroundColor))
    }

    func startEditing(cellPos: CellPosition, value: MySQLRowValue) {
        guard onCellEdit != nil else { return }
        editingCell = cellPos
        editingText = value.isNull ? "" : value.displayValue
        selectedCell = cellPos
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isEditingFocused = true
        }
    }

    func finishEditing() {
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

    func cancelEditing() {
        editingCell = nil
        editingText = ""
    }

    func handleColumnDrag(columnIndex: Int, minWidth: CGFloat, value: DragGesture.Value) {
        if isDraggingColumn != columnIndex {
            isDraggingColumn = columnIndex
            dragStartWidth = columnWidths[columnIndex]
        }

        let newWidth = dragStartWidth + value.translation.width
        let clampedWidth = min(400, max(minWidth, newWidth))
        columnWidths[columnIndex] = clampedWidth.rounded(.toNearestOrAwayFromZero)
    }

    func errorView(error: AppError) -> some View {
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

    var emptyResultView: some View {
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
