//
//  MySQLEditorTabBar.swift
//  cheap-connection
//
//  MySQL SQL 编辑器查询标签条
//

import SwiftUI

extension MySQLEditorView {
    var queryTabBar: some View {
        HStack(spacing: 0) {
            ForEach(editorTabs) { tab in
                queryTabItem(tab)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }

    func queryTabItem(_ tab: EditorQueryTab) -> some View {
        HStack(spacing: 0) {
            Button {
                onSelectEditorTab?(tab.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text(tab.title)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onCloseEditorTab?(tab.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(activeEditorTabId == tab.id ? .secondary : .tertiary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .frame(minWidth: 80)
        .background(activeEditorTabId == tab.id ? Color.accentColor.opacity(0.12) : Color.clear)
        .overlay(
            Rectangle()
                .fill(activeEditorTabId == tab.id ? Color.accentColor : Color.clear)
                .frame(height: 1.5),
            alignment: .bottom
        )
    }
}
