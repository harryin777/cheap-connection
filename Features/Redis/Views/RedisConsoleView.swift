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
    @State private var commandText: String = ""
    @State private var isExecuting: Bool = false

    // State - Result
    @State private var lastResult: RedisCommandResult?

    // State - History
    @State private var showHistory: Bool = false
    @State private var historyFilter: String = ""

    // State - Risk Confirmation
    @State private var showRiskConfirmation: Bool = false
    @State private var pendingRiskLevel: RedisRiskLevel = .safe
    @State private var pendingCommand: String = ""

    // Focus
    @FocusState private var isInputFocused: Bool

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
            // 标题
            Label("命令控制台", systemImage: "terminal")
                .font(.system(size: 12, weight: .medium))

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
                showHistory.toggle()
            } label: {
                Image(systemName: showHistory ? "clock.fill" : "clock")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("命令历史")

            // 清空按钮
            Button {
                clearAll()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("清空")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Input View

    @ViewBuilder
    private var inputView: some View {
        VStack(spacing: 0) {
            // 命令输入区
            TextEditor(text: $commandText)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .focused($isInputFocused)
                .background(Color(nsColor: .textBackgroundColor))

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
        .overlay(
            Group {
                if showHistory {
                    historyOverlay
                }
            }
        )
    }

    // MARK: - History Overlay

    @ViewBuilder
    private var historyOverlay: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func historyRow(_ command: String, index: Int) -> some View {
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
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(index % 2 == 0 ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    private var filteredHistory: [String] {
        if historyFilter.isEmpty {
            return service.session.commandHistory
        }
        return service.session.commandHistory.filter {
            $0.localizedCaseInsensitiveContains(historyFilter)
        }
    }

    // MARK: - Result View

    @ViewBuilder
    private var resultView: some View {
        if isExecuting {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("执行中...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let result = lastResult {
            RedisCommandResultView(result: result)
        } else {
            // 空状态
            VStack(spacing: 16) {
                Image(systemName: "terminal")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)

                Text("命令结果")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("输入命令后点击执行查看结果")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        isExecuting = true

        do {
            let result = try await service.executeCommand(command)
            lastResult = result
        } catch {
            lastResult = RedisCommandResult.error(error.localizedDescription)
        }

        isExecuting = false
    }

    private func clearAll() {
        commandText = ""
        lastResult = nil
        showHistory = false
    }
}

// MARK: - Result View

/// Redis 命令结果展示视图
struct RedisCommandResultView: View {
    let result: RedisCommandResult

    @State private var showFullValue: Bool = false
    private let previewLimit: Int = 10000

    var body: some View {
        VStack(spacing: 0) {
            // 结果头部
            resultHeader
            Divider()

            // 结果内容
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if result.success {
                        successContent
                    } else {
                        errorContent
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var resultHeader: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(result.success ? .green : .red)

            // 状态文本
            Text(result.success ? "执行成功" : "执行失败")
                .font(.system(size: 11, weight: .medium))

            Spacer()

            // 耗时
            Label(result.formattedDuration, systemImage: "clock")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            // 受影响的 key 数量
            if let affected = result.affectedKeys {
                Label("\(affected) 个 key", systemImage: "key")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Success Content

    @ViewBuilder
    private var successContent: some View {
        if let value = result.value {
            switch value {
            case .null:
                nullView
            case .string(let s):
                stringView(s)
            case .int(let i):
                intView(i)
            case .double(let d):
                doubleView(d)
            case .status(let s):
                statusView(s)
            case .error(let msg):
                errorValueView(msg)
            case .array(let arr):
                arrayView(arr)
            case .data(let data):
                dataView(data)
            case .map(let dict):
                mapView(dict)
            }
        } else {
            Text("OK")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var nullView: some View {
        Text("(nil)")
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func stringView(_ s: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showFullValue || s.count <= previewLimit {
                Text(s)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(s.prefix(previewLimit)))
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)

                    HStack {
                        Text("已截断显示，共 \(s.count) 字符")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Button("显示完整内容") {
                            showFullValue = true
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    }
                }
            }

            // 统计
            HStack(spacing: 16) {
                Label("\(s.count) 字符", systemImage: "textformat")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Label("\(s.utf8.count) 字节", systemImage: "memorychip")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func intView(_ i: Int) -> some View {
        HStack {
            Text("(integer) \(i)")
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.blue)

            Spacer()
        }
    }

    @ViewBuilder
    private func doubleView(_ d: Double) -> some View {
        HStack {
            Text("(double) \(String(format: "%.6g", d))")
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.purple)

            Spacer()
        }
    }

    @ViewBuilder
    private func statusView(_ s: String) -> some View {
        HStack {
            Text(s)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.green)

            Spacer()
        }
    }

    @ViewBuilder
    private func errorValueView(_ msg: String) -> some View {
        HStack {
            Text("(error) \(msg)")
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.red)

            Spacer()
        }
    }

    @ViewBuilder
    private func arrayView(_ arr: [RedisValue]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 元素数量
            Text("\(arr.count) 个元素")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            // 元素列表
            ForEach(arr.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 30, alignment: .trailing)

                    arrayElementView(arr[index])
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func arrayElementView(_ value: RedisValue) -> some View {
        switch value {
        case .null:
            Text("(nil)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        case .string(let s):
            Text(s.count > 200 ? String(s.prefix(200)) + "..." : s)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
        case .int(let i):
            Text("(integer) \(i)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.blue)
        case .double(let d):
            Text("(double) \(String(format: "%.6g", d))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.purple)
        case .status(let s):
            Text(s)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.green)
        case .error(let msg):
            Text("(error) \(msg)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.red)
        case .data(let data):
            Text("<\(data.count) 字节数据>")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        case .array(let arr):
            Text("[\(arr.count) 个元素]")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        case .map(let dict):
            Text("{\(dict.count) 个字段}")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dataView(_ data: Data) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("<\(data.count) 字节数据>")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            // 尝试显示为十六进制
            if data.count <= 1024 {
                let hex = data.map { String(format: "%02x", $0) }.joined(separator: " ")
                Text(hex)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
            }
        }
    }

    @ViewBuilder
    private func mapView(_ dict: [String: RedisValue]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(dict.count) 个字段")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            let sortedKeys = dict.keys.sorted()
            ForEach(sortedKeys, id: \.self) { key in
                HStack(alignment: .top, spacing: 0) {
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(width: 150, alignment: .leading)
                        .padding(.trailing, 12)

                    arrayElementView(dict[key]!)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Error Content

    @ViewBuilder
    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 错误图标
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)

                Text("执行出错")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // 错误消息
            if let message = result.errorMessage {
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ConnectionConfig(
        name: "Test Redis",
        databaseKind: .redis,
        host: "localhost",
        port: 6379,
        username: "",
        defaultDatabase: nil
    )

    let service = RedisService(connectionConfig: config)

    return RedisConsoleView(service: service)
        .frame(width: 800, height: 500)
}
