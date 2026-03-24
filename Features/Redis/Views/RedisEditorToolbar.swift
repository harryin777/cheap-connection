//
//  RedisEditorToolbar.swift
//  cheap-connection
//
//  Redis 编辑器工具栏与上下文信息
//

import SwiftUI

extension RedisEditorView {
    var toolbarView: some View {
        let fontSize = CGFloat(SettingsRepository.shared.settings.tabBarFontSize)

        return HStack(spacing: 8) {
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
                        .font(.system(size: fontSize + 1, weight: .medium))
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

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistory.toggle()
                }
            } label: {
                Image(systemName: showHistory ? "sidebar.right" : "clock.arrow.circlepath")
                    .font(.system(size: fontSize + 1))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(showHistory ? "隐藏历史" : "显示历史")

            if !history.isEmpty {
                Text("\(history.count)")
                    .font(.system(size: fontSize - 1))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Divider()
                .frame(height: 16)

            Button {
                commandText = ""
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: fontSize))
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

            contextInfoView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
    }

    var contextInfoView: some View {
        let fontSize = CGFloat(SettingsRepository.shared.settings.tabBarFontSize)

        return HStack(spacing: 8) {
            if let db = selectedDatabase {
                Text("DB \(db)")
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
            }

            if let version = serverVersion {
                Text("Redis \(version)")
                    .font(.system(size: fontSize - 1))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    func workspaceTabsView(
        activeTab: RedisDetailTab,
        onSelect: @escaping (RedisDetailTab) -> Void
    ) -> some View {
        let fontSize = CGFloat(SettingsRepository.shared.settings.tabBarFontSize)

        return HStack(spacing: 0) {
            ForEach(RedisDetailTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: fontSize))
                        Text(tab.rawValue)
                            .font(.system(size: fontSize, weight: .medium))
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
