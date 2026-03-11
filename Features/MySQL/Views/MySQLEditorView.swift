//
//  MySQLEditorView.swift
//  cheap-connection
//
//  MySQL SQL编辑器视图 - DataGrip风格工具栏
//

import SwiftUI

/// MySQL SQL编辑器视图 - DataGrip风格
struct MySQLEditorView: View {
    @Binding var sqlText: String
    let history: [String]
    let onExecute: (String) async -> Void
    let onSelectHistory: (String) -> Void

    @State private var showHistory = false
    @State private var showConfirmDialog = false
    @State private var pendingSQL = ""

    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏 - DataGrip风格
            toolbarView

            Divider()

            // 主内容区
            HSplitView {
                // SQL 编辑器
                editorView
                    .frame(minWidth: 300)

                // 历史面板
                if showHistory {
                    historyPanel
                        .frame(minWidth: 180, maxWidth: 280)
                }
            }
        }
        .confirmationDialog("确认执行", isPresented: $showConfirmDialog) {
            Button("执行") {
                Task {
                    await onExecute(pendingSQL)
                }
                pendingSQL = ""
            }
            Button("取消", role: .cancel) {
                pendingSQL = ""
            }
        } message: {
            Text("此操作可能会修改或删除数据，是否继续？")
        }
    }

    // MARK: - Subviews

    private var toolbarView: some View {
        HStack(spacing: 8) {
            // 执行按钮 - 绿色播放图标
            Button {
                executeSQL()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 24)
                    .background(
                        sqlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.gray
                            : Color.green
                    )
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .disabled(sqlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("执行 (⌘↵)")

            // 历史按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistory.toggle()
                }
            } label: {
                Image(systemName: showHistory ? "sidebar.right" : "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(showHistory ? "隐藏历史" : "显示历史")

            Divider()
                .frame(height: 16)

            // 清空按钮
            Button {
                sqlText = ""
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(sqlText.isEmpty)
            .help("清空")

            Spacer()

            // 历史记录计数
            if !history.isEmpty {
                Text("\(history.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
    }

    private var editorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 代码编辑器
            TextEditor(text: $sqlText)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .focused($isEditorFocused)

            // 底部提示栏
            HStack {
                Text("⌘↵ 执行")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(sqlText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) 行")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
        }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 面板标题
            HStack {
                Text("执行历史")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showHistory = false
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

            Divider()

            // 历史列表
            if history.isEmpty {
                emptyHistoryView
            } else {
                historyListView
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private var emptyHistoryView: some View {
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

    // MARK: - Actions

    private func executeSQL() {
        let sql = sqlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else { return }

        // 检查 SQL 风险等级
        let riskLevel = SQLRiskLevel.analyze(sql)
        if riskLevel == .dangerous || riskLevel == .warning {
            pendingSQL = sql
            showConfirmDialog = true
        } else {
            Task {
                await onExecute(sql)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MySQLEditorView(
        sqlText: .constant("SELECT * FROM users LIMIT 10;"),
        history: [
            "SELECT * FROM users LIMIT 10;",
            "SHOW DATABASES;",
            "DESCRIBE orders;"
        ],
        onExecute: { _ in },
        onSelectHistory: { _ in }
    )
    .frame(width: 700, height: 400)
}
