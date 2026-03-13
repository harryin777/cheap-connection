//
//  SQLEditorHistoryPanel.swift
//  cheap-connection
//
//  SQL 编辑器历史面板组件
//

import SwiftUI

/// SQL 编辑器历史面板
struct SQLEditorHistoryPanel: View {
    let history: [String]
    @Binding var isPresented: Bool
    let onSelectHistory: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 面板标题
            headerView

            Divider()

            // 历史列表
            if history.isEmpty {
                emptyView
            } else {
                historyListView
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("执行历史")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.controlBackgroundColor))
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            Text("暂无历史记录")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(history, id: \.self) { sql in
                    historyItemRow(sql)
                }
            }
        }
    }

    private func historyItemRow(_ sql: String) -> some View {
        Button {
            onSelectHistory(sql)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(sql)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(3)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(sql.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) 行")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var showHistory = true

        var body: some View {
            SQLEditorHistoryPanel(
                history: [
                    "SELECT * FROM users LIMIT 10;",
                    "SHOW DATABASES;",
                    "DESCRIBE orders;"
                ],
                isPresented: $showHistory,
                onSelectHistory: { _ in }
            )
            .frame(width: 250, height: 300)
        }
    }

    return PreviewWrapper()
}
