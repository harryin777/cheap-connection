//
//  RedisEditorView.swift
//  cheap-connection
//
//  Redis 命令编辑器视图 - DataGrip 风格
//

import SwiftUI

/// Redis 命令编辑器视图 - DataGrip 风格
struct RedisEditorView: View {
    @Binding var commandText: String
    let history: [String]
    let serverVersion: String?
    let selectedDatabase: Int?

    // MARK: - Callbacks
    let onExecute: (String) async -> Void

    var isExecuting: Bool = false
    var activeWorkspaceTab: RedisDetailTab? = nil
    var onSelectWorkspaceTab: ((RedisDetailTab) -> Void)? = nil

    @State var showHistory = false
    @State var showRiskConfirmation = false
    @State var pendingRiskLevel: RedisRiskLevel = .safe
    @State var pendingCommand = ""

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbarView

            Divider()

            ZStack(alignment: .topLeading) {
                HSplitView {
                    editorView
                        .frame(minWidth: 300)

                    if showHistory {
                        historyPanel
                            .frame(minWidth: 180, maxWidth: 280)
                    }
                }
            }
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
        .onReceive(NotificationCenter.default.publisher(for: .executeSQL)) { _ in
            Task { await executeCommand() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearEditor)) { _ in
            commandText = ""
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleHistory)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showHistory.toggle()
            }
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

    // MARK: - Editor View

    var editorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $commandText)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .focused($isInputFocused)
                .background(Color(nsColor: .textBackgroundColor))
                .scrollContentBackground(.hidden)

            HStack {
                Text("Cmd+Enter 执行 | 输入 Redis 命令如 GET key, SET key value")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(commandText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) 行")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
        }
    }

    // MARK: - History Panel

    var historyPanel: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
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
                    .padding(.top, 40)
                } else {
                    ForEach(history.indices.reversed(), id: \.self) { index in
                        historyRow(history[index], index: index)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func historyRow(_ command: String, index: Int) -> some View {
        HStack {
            Text("\(history.count - index)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)

            Text(command)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(index % 2 == 0 ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Actions

    private func executeCommand() async {
        let trimmed = commandText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // 检测命令风险等级
        let riskLevel = RedisRiskDetector.analyze(trimmed)

        switch riskLevel {
        case .safe:
            await executeCommandWithoutCheck(trimmed)
        case .medium, .high, .critical:
            pendingRiskLevel = riskLevel
            pendingCommand = trimmed
            showRiskConfirmation = true
        }
    }

    private func executeCommandWithoutCheck(_ command: String) async {
        await onExecute(command)
    }
}

// MARK: - Toolbar Extension

extension RedisEditorView {
    var toolbarView: some View {
        HStack(spacing: 8) {
            // 执行按钮
            Button {
                Task { await executeCommand() }
            } label: {
                if isExecuting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 28, height: 24)
                        .background(Color.gray)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 24)
                        .background(
                            commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray
                                : Color.green
                        )
                        .cornerRadius(4)
                }
            }
            .buttonStyle(.plain)
            .disabled(commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
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

            if !history.isEmpty {
                Text("\(history.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Divider()
                .frame(height: 16)

            // 清空按钮
            Button {
                commandText = ""
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(commandText.isEmpty)
            .help("清空")

            if let activeWorkspaceTab, let onSelectWorkspaceTab {
                Divider()
                    .frame(height: 16)

                workspaceTabsView(activeTab: activeWorkspaceTab, onSelect: onSelectWorkspaceTab)
            }

            Spacer()

            // 上下文信息
            contextInfoView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
    }

    var contextInfoView: some View {
        HStack(spacing: 8) {
            // 数据库索引
            if let db = selectedDatabase {
                Text("DB \(db)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
            }

            // 服务器版本
            if let version = serverVersion {
                Text("Redis \(version)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    func workspaceTabsView(
        activeTab: RedisDetailTab,
        onSelect: @escaping (RedisDetailTab) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(RedisDetailTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(activeTab == tab ? Color.accentColor.opacity(0.14) : Color.clear)
                    .overlay(
                        Rectangle()
                            .fill(activeTab == tab ? Color.accentColor.opacity(0.35) : Color.clear)
                            .frame(height: 1),
                        alignment: .bottom
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var commandText = "GET user:1"

        var body: some View {
            RedisEditorView(
                commandText: $commandText,
                history: [
                    "GET user:1",
                    "SET user:1 value",
                    "KEYS *"
                ],
                serverVersion: "7.0.0",
                selectedDatabase: 0,
                onExecute: { _ in }
            )
            .frame(width: 700, height: 300)
        }
    }

    return PreviewWrapper()
}
