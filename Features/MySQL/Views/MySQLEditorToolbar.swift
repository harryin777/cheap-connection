//
//  MySQLEditorToolbar.swift
//  cheap-connection
//
//  MySQL SQL 编辑器工具栏与工作区标签
//

import SwiftUI

extension MySQLEditorView {
    var toolbarView: some View {
        let primaryButtonSide = max(24, tabBarFontSize + 13)
        let iconButtonSide = max(20, tabBarFontSize + 9)
        let toolbarVerticalPadding = max(6, tabBarFontSize * 0.45)

        return HStack(spacing: 8) {
            Button {
                executeSQL()
            } label: {
                if isExecuting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: primaryButtonSide, height: primaryButtonSide)
                        .background(Color.gray)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: tabBarFontSize + 1, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: primaryButtonSide, height: primaryButtonSide)
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
                    .font(.system(size: tabBarFontSize + 1))
                    .frame(width: iconButtonSide, height: iconButtonSide)
            }
            .buttonStyle(.plain)
            .help(showHistory ? "隐藏历史" : "显示历史")

            if !history.isEmpty {
                Text("\(history.count)")
                    .font(.system(size: max(9, tabBarFontSize - 1)))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Divider()
                .frame(height: 16)

            Button {
                sqlText = ""
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: tabBarFontSize))
                    .foregroundStyle(.secondary)
                    .frame(width: iconButtonSide, height: iconButtonSide)
            }
            .buttonStyle(.plain)
            .disabled(sqlText.isEmpty)
            .help("清空")

            if let onOpenFile {
                Button {
                    Task { await onOpenFile() }
                } label: {
                    Image(systemName: "doc.text")
                        .font(.system(size: tabBarFontSize))
                        .frame(width: iconButtonSide, height: iconButtonSide)
                }
                .buttonStyle(.plain)
                .help("Open .sql file (import to editor only, no execute)")
            }

            if let onImport {
                Button {
                    Task { await onImport() }
                } label: {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: tabBarFontSize))
                        .frame(width: iconButtonSide, height: iconButtonSide)
                }
                .buttonStyle(.plain)
                .help("Import and execute .sql file")
            }

            if let activeWorkspaceTab, let onSelectWorkspaceTab {
                Divider()
                    .frame(height: 16)

                workspaceTabsView(
                    activeTab: activeWorkspaceTab,
                    onSelect: onSelectWorkspaceTab,
                    isRedisConnection: isCurrentConnectionRedis
                )
            }

            Spacer()

            // Context selectors
            contextSelectorsView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, toolbarVerticalPadding)
        .background(Color(.windowBackgroundColor))
        .id("mysql-toolbar-\(Int(tabBarFontSize))-\(showHistory)")
    }

    var contextSelectorsView: some View {
        HStack(spacing: 8) {
            // Schema menu
            SQLEditorSchemaMenu(
                databases: queryDatabases,
                selectedDatabase: selectedQueryDatabase,
                onSelect: onSelectQueryDatabase
            )
            .id("\(queryConnectionId.uuidString)-\(queryDatabases.joined(separator: ","))")

            // Connection menu
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
        onSelect: @escaping (MySQLDetailTab) -> Void,
        isRedisConnection: Bool
    ) -> some View {
        return HStack(spacing: 0) {
            ForEach(MySQLDetailTab.allCases, id: \.self) { tab in
                Button {
                    guard !isRedisConnection else { return }
                    onSelect(tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: tabBarFontSize))
                        Text(tab.rawValue)
                            .font(.system(size: tabBarFontSize, weight: .medium))
                    }
                    .padding(.horizontal, max(12, tabBarFontSize))
                    .padding(.vertical, max(5, tabBarFontSize * 0.45))
                    .background(activeTab == tab ? Color.accentColor.opacity(0.14) : Color.clear)
                    .overlay(
                        Rectangle()
                            .fill(activeTab == tab ? Color.accentColor.opacity(0.35) : Color.clear)
                            .frame(height: 1),
                        alignment: .bottom
                    )
                }
                .buttonStyle(.plain)
                .disabled(isRedisConnection)
                .opacity(isRedisConnection ? 0.4 : 1.0)
            }
        }
    }
}
