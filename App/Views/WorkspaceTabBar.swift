//
//  WorkspaceTabBar.swift
//  cheap-connection
//
//  工作区标签栏 - DataGrip 风格的多标签切换
//

import SwiftUI

/// 工作区标签栏
struct WorkspaceTabBar: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @ObservedObject private var settingsRepo = SettingsRepository.shared

    var body: some View {
        // WorkspaceSession 标签栏，只显示用户显式打开（双击）的工作区
        let sessions = connectionManager.workspaceManager.openSessions.values
            .sorted { lhs, rhs in
                if lhs.lastActiveAt != rhs.lastActiveAt {
                    return lhs.lastActiveAt < rhs.lastActiveAt
                }
                return lhs.createdAt < rhs.createdAt
            }

        HStack(spacing: 0) {
            ForEach(sessions) { session in
                if let config = connectionManager.connections.first(where: { $0.id == session.connectionId }) {
                    tabItem(session: session, config: config)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Private

    @ViewBuilder
    private func tabItem(session: WorkspaceSession, config: ConnectionConfig) -> some View {
        let isActive = session.id == connectionManager.workspaceManager.activeWorkspaceId
        let fontSize = CGFloat(settingsRepo.settings.tabBarFontSize)

        HStack(spacing: 0) {
            Button {
                connectionManager.workspaceManager.activateWorkspace(session.id)
            } label: {
                HStack(spacing: 6) {
                    // 数据库类型图标
                    Image(systemName: iconForKind(session.kind))
                        .font(.system(size: fontSize - 1))
                        .foregroundStyle(isActive ? Color.accentColor : .secondary)

                    Text(config.name)
                        .font(.system(size: fontSize))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                connectionManager.workspaceManager.closeWorkspace(session.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: fontSize + 1))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isActive ? .secondary : .tertiary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .frame(minWidth: 80)
        .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
        .overlay(
            Rectangle()
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(height: 1.5),
            alignment: .bottom
        )
    }

    private func iconForKind(_ kind: WorkspaceKind) -> String {
        switch kind {
        case .mysql:
            return "cylinder"
        case .redis:
            return "hockey.puck"
        }
    }
}

#Preview {
    WorkspaceTabBar()
        .environment(ConnectionManager.shared)
}
