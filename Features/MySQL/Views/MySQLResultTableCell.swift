//
//  MySQLResultTableCell.swift
//  cheap-connection
//
//  MySQL结果表格单元格组件
//

import SwiftUI

// MARK: - Data Cell View

/// 数据单元格视图
struct ResultDataCellView: View {
    @ObservedObject private var settingsRepo = SettingsRepository.shared
    let value: MySQLRowValue
    let rowIndex: Int
    let columnIndex: Int
    let isSelected: Bool
    let isEditing: Bool
    let editingText: String
    let isEditingFocused: FocusState<Bool>.Binding
    let onEditingTextChange: (String) -> Void
    let onSelect: () -> Void
    let onStartEditing: () -> Void
    let onFinishEditing: () -> Void
    let onCancelEditing: () -> Void

    private var displayText: String {
        value.isNull ? "NULL" : value.displayValue
    }

    var body: some View {
        Group {
            if isEditing {
                // 编辑模式
                TextField("", text: Binding(
                    get: { editingText },
                    set: onEditingTextChange
                ))
                    .font(.system(size: CGFloat(settingsRepo.settings.dataViewFontSize), design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 6)
                    .focused(isEditingFocused)
                    .onSubmit {
                        onFinishEditing()
                    }
                    .onExitCommand {
                        onCancelEditing()
                    }
            } else if value.isNull {
                Text("NULL")
                    .font(.system(size: CGFloat(settingsRepo.settings.dataViewFontSize), design: .monospaced).italic())
                    .foregroundStyle(.tertiary)
            } else {
                Text(displayText)
                    .font(.system(size: CGFloat(settingsRepo.settings.dataViewFontSize), design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, isEditing ? 0 : 8)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.2) :
            isEditing ? Color.accentColor.opacity(0.1) : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onStartEditing()
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    onSelect()
                }
        )
        .help(displayText)
    }
}
