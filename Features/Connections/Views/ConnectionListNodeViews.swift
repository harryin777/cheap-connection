//
//  ConnectionListNodeViews.swift
//  cheap-connection
//
//  ConnectionListView 的子视图组件
//

import SwiftUI

// MARK: - Connection Node

struct ConnectionListNodeView: View {
    @ObservedObject private var settingsRepo = SettingsRepository.shared
    let config: ConnectionConfig
    let isExpanded: Bool
    let isLoading: Bool
    let databaseCount: Int?
    let isSelected: Bool

    let onToggle: () -> Void
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ConnectionListDisclosureIcon(
                    isExpanded: isExpanded,
                    isVisible: config.databaseKind == .mysql
                )
                .onTapGesture {
                    guard config.databaseKind == .mysql else { return }
                    onToggle()
                }

                Image(systemName: config.databaseKind == .mysql ? "cylinder.split.1x2" : "memorychip")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(config.databaseKind == .mysql ? .blue : .orange)
                    .frame(width: 14)

                Text(config.name)
                    .font(.system(size: CGFloat(settingsRepo.settings.connectionTreeFontSize), weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else if let count = databaseCount {
                    ConnectionListCountBadge(text: "\(count)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.16) : .clear)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onDoubleClick()
            }
            .onTapGesture(count: 1) {
                onSelect()
            }
            .contextMenu {
                Button {
                    onEdit()
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Database Node

struct ConnectionListDatabaseNodeView: View {
    @ObservedObject private var settingsRepo = SettingsRepository.shared
    let database: MySQLDatabaseSummary
    let databaseKey: String
    let isExpanded: Bool
    let isLoading: Bool
    let isSelected: Bool
    let leading: CGFloat

    let onToggle: () -> Void
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ConnectionListDisclosureIcon(
                    isExpanded: isExpanded,
                    isVisible: true
                )
                .onTapGesture {
                    onToggle()
                }

                Image(systemName: database.isSystemDatabase ? "cylinder" : "square.grid.2x2")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(database.isSystemDatabase ? Color.secondary : Color.blue)
                    .frame(width: 14)

                Text(database.name)
                    .font(.system(size: CGFloat(settingsRepo.settings.connectionTreeFontSize)))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else if let count = database.tableCount {
                    ConnectionListCountBadge(text: "\(count)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .padding(.leading, leading)
            .background(isSelected ? Color.accentColor.opacity(0.16) : .clear)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onToggle()
            }
            .onTapGesture(count: 1) {
                onSelect()
            }
        }
    }
}

// MARK: - Tables Folder Node

struct ConnectionListTablesFolderView: View {
    @ObservedObject private var settingsRepo = SettingsRepository.shared
    let database: MySQLDatabaseSummary
    let isExpanded: Bool
    let isLoading: Bool
    let tablesCount: Int?
    let leading: CGFloat

    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ConnectionListDisclosureIcon(
                    isExpanded: isExpanded,
                    isVisible: true
                )
                .onTapGesture {
                    onToggle()
                }

                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 14)

                Text("tables")
                    .font(.system(size: CGFloat(settingsRepo.settings.connectionTreeFontSize), weight: .medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if let count = tablesCount {
                    ConnectionListCountBadge(text: "\(count)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .padding(.leading, leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onToggle()
            }
            .onTapGesture(count: 1) {
                onToggle()
            }
        }
    }
}

// MARK: - Table Row

struct ConnectionListTableRowView: View {
    @ObservedObject private var settingsRepo = SettingsRepository.shared
    let table: MySQLTableSummary
    let isSelected: Bool
    let leading: CGFloat

    let onSelect: () -> Void
    let onDoubleClick: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 10)

            Image(systemName: "tablecells")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(table.name)
                .font(.system(size: CGFloat(settingsRepo.settings.connectionTreeFontSize)))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .padding(.leading, leading)
        .background(isSelected ? Color.accentColor.opacity(0.16) : .clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
    }
}
