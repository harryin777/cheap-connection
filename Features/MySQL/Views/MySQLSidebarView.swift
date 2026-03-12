//
//  MySQLSidebarView.swift
//  cheap-connection
//
//  MySQL侧边栏视图 - DataGrip风格树形结构
//

import SwiftUI

/// MySQL侧边栏视图 - 树形数据库/表结构
struct MySQLSidebarView: View {
    @Binding var databases: [MySQLDatabaseSummary]
    let connectionName: String  // 连接名称
    let selectedDatabase: String?
    let selectedTable: String?
    let onSelectDatabase: (String?) -> Void
    let onSelectTable: (String, String) -> Void
    let onRefresh: () async -> Void
    let onLoadTables: (String) async -> Void
    let isLoading: Bool
    let loadingDatabase: String?

    // 展开状态
    @State private var expandedDatabases: Set<String> = []
    @State private var isConnectionExpanded = true  // 连接节点默认展开

    var body: some View {
        VStack(spacing: 0) {
            // 树形列表
            if databases.isEmpty && !isLoading {
                emptyStateView
            } else {
                treeListView
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Subviews

    private var treeListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 连接节点（顶层）
                connectionNode

                // 数据库列表
                if isConnectionExpanded {
                    ForEach(databases) { database in
                        databaseRow(database)
                    }
                }
            }
        }
    }

    // MARK: - Connection Node

    private var connectionNode: some View {
        VStack(spacing: 0) {
            // 连接行
            HStack(spacing: 6) {
                // 展开/折叠箭头
                Image(systemName: isConnectionExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isConnectionExpanded.toggle()
                        }
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
                if !databases.isEmpty {
                    Text("\(databases.count)")
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
                    expandedDatabases.removeAll()
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
                withAnimation(.easeInOut(duration: 0.15)) {
                    isConnectionExpanded.toggle()
                }
            }

            // 分隔线
            if isConnectionExpanded {
                Divider()
                    .padding(.leading, 24)
            }
        }
    }

    private var emptyStateView: some View {
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

    // MARK: - Database Row

    private func databaseRow(_ database: MySQLDatabaseSummary) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                // 展开/折叠箭头
                Image(systemName: expandedDatabases.contains(database.name) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleDatabase(database.name)
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
            .padding(.leading, 20)  // 缩进
            .background(
                selectedDatabase == database.name && selectedTable == nil
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectDatabase(database.name)
                toggleDatabase(database.name)
            }

            // 表列表（展开时）
            if expandedDatabases.contains(database.name) {
                tablesList(for: database)
            }
        }
    }

    // MARK: - Tables List

    private func tablesList(for database: MySQLDatabaseSummary) -> some View {
        VStack(spacing: 0) {
            if let tables = database.tables {
                // 已加载表
                if tables.isEmpty {
                    emptyTablesView
                } else {
                    ForEach(tables) { table in
                        tableRow(table, database: database.name)
                    }
                }
            } else if loadingDatabase == database.name {
                // 加载中
                HStack {
                    Spacer()
                    ProgressView()
                        .frame(width: 14, height: 14)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                // 需要加载 - 自动触发
                Color.clear
                    .onAppear {
                        Task {
                            await onLoadTables(database.name)
                        }
                    }
            }
        }
        .padding(.leading, 20)
    }

    private var emptyTablesView: some View {
        Text("无表")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 44)
    }

    // MARK: - Table Row

    private func tableRow(_ table: MySQLTableSummary, database: String) -> some View {
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
        .padding(.leading, 44)  // 额外缩进
        .background(
            selectedDatabase == database && selectedTable == table.name
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectTable(database, table.name)
        }
        .onTapGesture(count: 2) {
            // 双击直接打开数据标签
            onSelectTable(database, table.name)
        }
    }

    // MARK: - Actions

    private func toggleDatabase(_ name: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if expandedDatabases.contains(name) {
                expandedDatabases.remove(name)
            } else {
                expandedDatabases.insert(name)

                // 展开时自动加载表（如果尚未加载）
                if let database = databases.first(where: { $0.name == name }),
                   database.tables == nil {
                    Task {
                        await onLoadTables(name)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let databases = MySQLDatabaseSummary.previewData

    MySQLSidebarView(
        databases: .constant(databases),
        connectionName: "aliyun",
        selectedDatabase: nil,
        selectedTable: nil,
        onSelectDatabase: { _ in },
        onSelectTable: { _, _ in },
        onRefresh: {},
        onLoadTables: { _ in },
        isLoading: false,
        loadingDatabase: nil
    )
    .frame(width: 250, height: 500)
}
