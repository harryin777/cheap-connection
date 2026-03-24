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

    @FocusState var isInputFocused: Bool

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

    private var riskConfirmationMessage: String {
        RedisCommandSupport.confirmationMessage(for: pendingRiskLevel)
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

    // MARK: - Actions

    func executeCommand() async {
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
