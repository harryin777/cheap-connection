//
//  MySQLEditorToolbar.swift
//  cheap-connection
//
//  MySQL SQL 编辑器工具栏与工作区标签
//

import SwiftUI

extension MySQLEditorView {
    var toolbarView: some View {
        HStack(spacing: 8) {
            Button {
                executeSQL()
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
                            sqlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray
                                : Color.green
                        )
                        .cornerRadius(4)
                }
            }
            .buttonStyle(.plain)
            .disabled(sqlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecuting)
            .help("执行 (⌘↵)")

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

            if let onOpenFile {
                Button {
                    Task { await onOpenFile() }
                } label: {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("打开 .sql 文件")
            }

            if let onImport {
                Button {
                    Task { await onImport() }
                } label: {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 11))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("导入并执行 .sql 文件")
            }

            if let activeWorkspaceTab, let onSelectWorkspaceTab {
                Divider()
                    .frame(height: 16)

                workspaceTabsView(activeTab: activeWorkspaceTab, onSelect: onSelectWorkspaceTab)
            }

            Spacer()

            // Context selectors 始终显示：connection pill 独立可点，schema pill 可在无库时显示"未指定"
            contextSelectorsView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
    }

    var contextSelectorsView: some View {
        HStack(spacing: 8) {
            // Schema menu 只消费当前 query connection 的数据库列表
            SQLEditorSchemaMenu(
                databases: queryDatabases,
                selectedDatabase: selectedQueryDatabase,
                onSelect: onSelectQueryDatabase
            )
            .id("\(queryConnectionId.uuidString)-\(queryDatabases.joined(separator: ","))")  // Force rebuild on connection or databases change

            // Connection menu 永远独立可点
            SQLEditorConnectionMenu(
                connections: availableConnections,
                selectedConnectionId: queryConnectionId,
                selectedConnectionName: queryConnectionName,
                onSelect: onSwitchQueryConnection
            )
        }
    }

    func workspaceTabsView(
        activeTab: MySQLDetailTab,
        onSelect: @escaping (MySQLDetailTab) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(MySQLDetailTab.allCases, id: \.self) { tab in
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
