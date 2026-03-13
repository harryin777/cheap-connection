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
    let connectionName: String
    let selectedDatabase: String?
    let selectedTable: String?
    let onSelectDatabase: (String?) -> Void
    let onSelectTable: (String, String) -> Void
    let onRefresh: () async -> Void
    let onLoadTables: (String) async -> Void
    let isLoading: Bool
    let loadingDatabase: String?

    @State private var expandedDatabases: Set<String> = []
    @State private var isConnectionExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            if databases.isEmpty && !isLoading {
                EmptyStateView(isLoading: isLoading)
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
                ConnectionNodeView(
                    connectionName: connectionName,
                    databaseCount: databases.count,
                    isLoading: isLoading,
                    isExpanded: isConnectionExpanded,
                    onToggleExpand: { toggleConnection() },
                    onRefresh: onRefresh,
                    onCollapseAll: { collapseAll() }
                )

                if isConnectionExpanded {
                    ForEach(databases) { database in
                        VStack(spacing: 0) {
                            DatabaseRowView(
                                database: database,
                                isExpanded: expandedDatabases.contains(database.name),
                                isSelected: selectedDatabase == database.name && selectedTable == nil,
                                onToggleExpand: { toggleDatabase(database.name) },
                                onSelect: {
                                    onSelectDatabase(database.name)
                                    toggleDatabase(database.name)
                                }
                            )

                            if expandedDatabases.contains(database.name) {
                                TablesListView(
                                    database: database,
                                    isLoading: loadingDatabase == database.name,
                                    selectedTableName: selectedDatabase == database.name ? selectedTable : nil,
                                    onLoadTables: { await onLoadTables(database.name) },
                                    onSelectTable: onSelectTable
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleConnection() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isConnectionExpanded.toggle()
        }
    }

    private func collapseAll() {
        expandedDatabases.removeAll()
    }

    private func toggleDatabase(_ name: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if expandedDatabases.contains(name) {
                expandedDatabases.remove(name)
            } else {
                expandedDatabases.insert(name)

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
