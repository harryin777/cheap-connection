//
//  RedisEditorView.swift
//  cheap-connection
//
//  Redis 命令编辑器视图
//

import SwiftUI

/// Redis 命令编辑器视图
struct RedisEditorView: View {
    @Binding var commandText: String
    let history: [String]
    let isExecuting: Bool
    let connectionName: String
    let selectedDatabase: Int?
    let onExecute: (String) async -> Void
    let onSelectHistory: (String) -> Void

    @State private var showHistory = false
    @State private var historyFilter = ""
    @State private var showRiskConfirmation = false
    @State private var pendingRiskLevel: RedisRiskLevel = .safe
    @State private var pendingCommand = ""

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView
            Divider()

            // 编辑器 + 历史面板
            HSplitView {
                editorView
                    .frame(minWidth: 300)

                if showHistory {
                    historyPanel
                        .frame(minWidth: 180, maxWidth: 280)
                }
            }
        }
        .onAppear {
            isInputFocused = true
        }
        .alert("危险操作确认", isPresented: $showRiskConfirmation) {
            Button("取消", role: .cancel) {
                pendingCommand = ""
            }
            Button("确认执行", role: .destructive) {
                Task { await executeCommandWithoutCheck(pendingCommand) }
                pendingCommand = ""
            }
        } message: {
            Text(riskConfirmationMessage)
        }
    }

    // MARK: - Risk Confirmation Message

    private var riskConfirmationMessage: String {
        switch pendingRiskLevel {
        case .safe:
            return ""
        case .medium(let msg):
            return "\(msg)\n\n确定要继续吗？"
        case .high(let msg):
            return "⚠️ 高风险操作\n\(msg)\n\n确定要继续吗？"
        case .critical(let msg):
            return "🚨 极高风险操作\n\(msg)\n\n此命令可能造成不可逆的数据损失，确定要继续吗？"
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 连接信息
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(connectionName)
                    .font(.system(size: 11, weight: .medium))

                if let db = selectedDatabase {
                    Text("DB\(db)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .cornerRadius(4)
                }
            }

            Spacer()

            // 执行按钮
            Button {
                Task { await executeCommand() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("执行")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(commandText.trimmingCharacters(in: .whitespaces).isEmpty || isExecuting)
            .keyboardShortcut(.return, modifiers: .command)

            // 历史按钮
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showHistory.toggle()
                }
            } label: {
                Image(systemName: showHistory ? "clock.fill" : "clock")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("命令历史 (⌘H)")

            // 清空按钮
            Button {
                commandText = ""
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("清空编辑器")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Editor View

    @ViewBuilder
    private var editorView: some View {
        VStack(spacing: 0) {
            // 命令输入区
            TextEditor(text: $commandText)
                .font(.system(size: 13, design: .monospaced))
                .padding(8)
                .focused($isInputFocused)
                .background(Color(nsColor: .textBackgroundColor))
                .scrollContentBackground(.hidden)

            // 提示
            HStack {
                Text("提示: 输入 Redis 命令，如 GET key, SET key value")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("⌘↵ 执行")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
    }

    // MARK: - History Panel

    @ViewBuilder
    private var historyPanel: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                TextField("搜索历史...", text: $historyFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 历史列表
            let history = filteredHistory
            if history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)

                    Text("暂无历史命令")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(history.indices, id: \.self) { index in
                            historyRow(history[index], index: index)
                        }
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func historyRow(_ command: String, index: Int) -> some View {
        Button {
            commandText = command
            showHistory = false
            isInputFocused = true
        } label: {
            HStack {
                Text("\(index + 1)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 30, alignment: .trailing)

                Text(command)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(index % 2 == 0 ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    private var filteredHistory: [String] {
        if historyFilter.isEmpty {
            return history
        }
        return history.filter {
            $0.localizedCaseInsensitiveContains(historyFilter)
        }
    }

    // MARK: - Actions

    private func executeCommand() async {
        let trimmed = commandText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // 检测命令风险等级
        let riskLevel = RedisRiskDetector.analyze(trimmed)

        switch riskLevel {
        case .safe:
            // 安全命令，直接执行
            await executeCommandWithoutCheck(trimmed)

        case .medium, .high, .critical:
            // 需要用户确认
            pendingRiskLevel = riskLevel
            pendingCommand = trimmed
            showRiskConfirmation = true
        }
    }

    private func executeCommandWithoutCheck(_ command: String) async {
        await onExecute(command)
    }
}
