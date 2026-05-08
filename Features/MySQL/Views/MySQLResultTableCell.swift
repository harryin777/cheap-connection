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
    let columnWidth: CGFloat
    let isSelected: Bool
    let isEditing: Bool
    let editingText: String
    let isEditingFocused: FocusState<Bool>.Binding
    let onEditingTextChange: (String) -> Void
    let onSelect: () -> Void
    let onStartEditing: () -> Void
    let onFinishEditing: () -> Void
    let onCancelEditing: () -> Void

    @State private var showFullContent = false

    private var displayText: String {
        value.isNull ? "NULL" : value.displayValue
    }

    private var fontSize: CGFloat {
        CGFloat(settingsRepo.settings.dataViewFontSize)
    }

    /// 文本是否超出单元格可见区域
    private var isTextOverflowing: Bool {
        guard !value.isNull else { return false }
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let textWidth = ceil((displayText as NSString).size(withAttributes: [.font: font]).width)
        return textWidth > columnWidth - 16
    }

    var body: some View {
        Group {
            if isEditing {
                TextField("", text: Binding(
                    get: { editingText },
                    set: onEditingTextChange
                ))
                    .font(.system(size: fontSize, design: .monospaced))
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
                    .font(.system(size: fontSize, design: .monospaced).italic())
                    .foregroundStyle(.tertiary)
            } else {
                normalCellContent
            }
        }
        .padding(.horizontal, isEditing ? 0 : 8)
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

    // MARK: - Normal Content

    @ViewBuilder
    private var normalCellContent: some View {
        Text(displayText)
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topTrailing) {
                if isTextOverflowing {
                    eyeButton
                }
            }
    }

    // MARK: - Eye Button

    @ViewBuilder
    private var eyeButton: some View {
        Button(action: { showFullContent = true }) {
            Image(systemName: "eye")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.controlBackgroundColor).opacity(0.9))
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showFullContent) {
            cellFullContentView
        }
    }

    // MARK: - Full Content Popover

    @ViewBuilder
    private var cellFullContentView: some View {
        ScrollView {
            Text(displayText)
                .font(.system(size: fontSize, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(minWidth: 300, minHeight: 100)
        .frame(maxWidth: 500, maxHeight: 400)
    }
}
