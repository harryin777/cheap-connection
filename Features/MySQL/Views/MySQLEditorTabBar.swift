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

                    // GPT TODO: 2.8 最后一条要求“未保存时在文件名 tab 上显示圆点，保存后自动消失”，但这里完全没有消费 tab.isDirty。
                    // GPT TODO: glm5 需要在文件名附近增加稳定可见的 unsaved indicator（圆点），并直接绑定 tab.isDirty。
                    // GPT TODO: 不要把圆点和关闭按钮复用，也不要做成 hover 态，否则用户无法稳定感知未保存状态。
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
