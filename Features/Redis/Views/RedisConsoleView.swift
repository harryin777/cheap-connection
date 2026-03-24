//
//  RedisConsoleView.swift
//  cheap-connection
//
//  Redis 命令控制台视图
//

import SwiftUI

/// Redis 命令控制台视图
struct RedisConsoleView: View {
    let service: RedisService

    // State - Input
    @State var commandText: String = ""
    @State var isExecuting: Bool = false

    // State - Result
    @State var lastResult: RedisCommandResult?

    // State - History
    @State var showHistory: Bool = false
    @State var historyFilter: String = ""

    // State - Risk Confirmation
    @State private var showRiskConfirmation: Bool = false
    @State private var pendingRiskLevel: RedisRiskLevel = .safe
    @State private var pendingCommand: String = ""

    // Focus
    @FocusState var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView
            Divider()

            // 主内容区
            HSplitView {
                // 左侧: 命令输入
                inputView
                    .frame(minWidth: 300, idealWidth: 400)

                // 右侧: 结果展示
                resultView
                    .frame(minWidth: 300)
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

    var riskConfirmationMessage: String {
        RedisCommandSupport.confirmationMessage(for: pendingRiskLevel)
    }

    // MARK: - Actions

    func executeCommand() async {
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
        isExecuting = true

        do {
            let result = try await service.executeCommand(command)
            lastResult = result
        } catch {
            lastResult = RedisCommandResult.error(error.localizedDescription)
        }

        isExecuting = false
    }

    func clearAll() {
        commandText = ""
        lastResult = nil
        showHistory = false
    }
}
