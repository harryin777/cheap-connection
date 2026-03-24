//
//  RedisConsoleSupportViews.swift
//  cheap-connection
//
//  Redis 控制台拆分视图
//

import SwiftUI

extension RedisConsoleView {
    @ViewBuilder
    var toolbarView: some View {
        HStack(spacing: 12) {
            Label("命令控制台", systemImage: "terminal")
                .font(.system(size: 12, weight: .medium))

            Spacer()

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

            Button {
                showHistory.toggle()
            } label: {
                Image(systemName: showHistory ? "clock.fill" : "clock")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("命令历史")

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

    @ViewBuilder
    var inputView: some View {
        VStack(spacing: 0) {
            TextEditor(text: $commandText)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .focused($isInputFocused)
                .background(Color(nsColor: .textBackgroundColor))

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
        .overlay {
            if showHistory {
                historyOverlay
            }
        }
    }

    @ViewBuilder
    var historyOverlay: some View {
        VStack(spacing: 0) {
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
    func historyRow(_ command: String, index: Int) -> some View {
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
        .background(index.isMultiple(of: 2) ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    var filteredHistory: [String] {
        guard !historyFilter.isEmpty else {
            return service.session.commandHistory
        }
        return service.session.commandHistory.filter {
            $0.localizedCaseInsensitiveContains(historyFilter)
        }
    }

    @ViewBuilder
    var resultView: some View {
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
}
