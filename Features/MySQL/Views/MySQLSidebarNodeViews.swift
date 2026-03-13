//
//  MySQLSidebarNodeViews.swift
//  cheap-connection
//
//  MySQL侧边栏子视图组件
//

import SwiftUI

// MARK: - Connection Node

/// 连接节点视图
struct ConnectionNodeView: View {
    let connectionName: String
    let databaseCount: Int
    let isLoading: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onRefresh: () async -> Void
    let onCollapseAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                // 展开/折叠箭头
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggleExpand()
                    }

                // 连接图标
                Image(systemName: "cylinder.split.1x2")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)

                // 连接名称
                Text(connectionName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                // 数据库数量
                if databaseCount > 0 {
                    Text("\(databaseCount)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }

                // 刷新按钮
                Button {
                    Task {
                        await onRefresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(isLoading ? .tertiary : .secondary)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .help("刷新数据库列表")

                // 收起按钮
                Button {
                    onCollapseAll()
                } label: {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("收起全部数据库")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.windowBackgroundColor))
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpand()
            }

            // 分隔线
            if isExpanded {
                Divider()
                    .padding(.leading, 24)
            }
        }
    }
}

// MARK: - Database Row

/// 数据库行视图
struct DatabaseRowView: View {
    let database: MySQLDatabaseSummary
    let isExpanded: Bool
    let isSelected: Bool
    let onToggleExpand: () -> Void
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                // 展开/折叠箭头
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggleExpand()
                    }

                // 数据库图标
                Image(systemName: database.isSystemDatabase ? "cylinder.fill" : "cylinder")
                    .font(.system(size: 14))
                    .foregroundStyle(database.isSystemDatabase ? Color.secondary : Color.accentColor)

                // 数据库名称
                Text(database.name)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Spacer()

                // 表数量
                if let count = database.tableCount {
                    Text("\(count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .padding(.leading, 20)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
        }
    }
}

// MARK: - Tables List

/// 表列表视图
struct TablesListView: View {
    let database: MySQLDatabaseSummary
    let isLoading: Bool
    let selectedTableName: String?
    let onLoadTables: () async -> Void
    let onSelectTable: (String, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let tables = database.tables {
                if tables.isEmpty {
                    EmptyTablesView()
                } else {
                    ForEach(tables) { table in
                        TableRowView(
                            table: table,
                            databaseName: database.name,
                            isSelected: selectedTableName == table.name,
                            onSelect: { onSelectTable(database.name, table.name) }
                        )
                    }
                }
            } else if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .frame(width: 14, height: 14)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                Color.clear
                    .onAppear {
                        Task {
                            await onLoadTables()
                        }
                    }
            }
        }
        .padding(.leading, 20)
    }
}

// MARK: - Empty Views

/// 空状态视图
struct EmptyStateView: View {
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("加载中...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "cylinder.split.1x2")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)

                Text("无数据库")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text("连接后自动加载")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 空表列表视图
struct EmptyTablesView: View {
    var body: some View {
        Text("无表")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 44)
    }
}

// MARK: - Table Row

/// 表行视图
struct TableRowView: View {
    let table: MySQLTableSummary
    let databaseName: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // 表图标
            Image(systemName: "table")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            // 表名
            Text(table.name)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            // 引擎标签
            if let engine = table.engine {
                Text(engine)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .padding(.leading, 44)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onSelect()
        }
    }
}
