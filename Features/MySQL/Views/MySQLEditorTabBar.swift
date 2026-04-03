//
//  MySQLEditorTabBar.swift
//  cheap-connection
//
//  MySQL SQL 编辑器查询标签条
//

import SwiftUI

extension MySQLEditorView {
    var queryTabBar: some View {
        let verticalPadding = max(2, tabBarFontSize * 0.25)

        return HStack(spacing: 0) {
            ForEach(editorTabs) { tab in
                queryTabItem(tab)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, verticalPadding)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }

    func queryTabItem(_ tab: EditorQueryTab) -> some View {
        let tabMinWidth = max(80, tabBarFontSize * 7)
        let itemVerticalPadding = max(4, tabBarFontSize * 0.4)
        let closeButtonSide = max(20, tabBarFontSize + 8)

        return HStack(spacing: 0) {
            Button {
                onSelectEditorTab?(tab.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: tabBarFontSize - 1))
                        .foregroundStyle(.secondary)

                    Text(tab.title)
                        .font(.system(size: tabBarFontSize))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    // 未保存圆点指示器
                    if tab.isDirty {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, itemVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onCloseEditorTab?(tab.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: tabBarFontSize + 1))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(activeEditorTabId == tab.id ? .secondary : .tertiary)
                    .frame(width: closeButtonSide, height: closeButtonSide)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .frame(minWidth: tabMinWidth)
        .background(activeEditorTabId == tab.id ? Color.accentColor.opacity(0.12) : Color.clear)
        .overlay(
            Rectangle()
                .fill(activeEditorTabId == tab.id ? Color.accentColor : Color.clear)
                .frame(height: 1.5),
            alignment: .bottom
        )
    }
}
