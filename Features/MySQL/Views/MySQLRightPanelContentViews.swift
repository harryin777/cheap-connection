//
//  MySQLRightPanelContentViews.swift
//  cheap-connection
//
//  MySQL 右侧面板内容视图拆分
//

import SwiftUI

extension MySQLRightPanelView {
    @ViewBuilder
    var editorOnlyView: some View {
        MySQLEditorView(
            sqlText: $sqlText,
            history: sqlHistory,
            queryConnectionId: currentQueryConnectionId,
            queryConnectionName: currentQueryConnectionName,
            availableConnections: availableConnections,
            queryDatabases: queryDatabaseOptions,
            selectedQueryDatabase: currentQueryDatabase,
            onSwitchQueryConnection: { switchQueryConnection($0) },
            onSelectQueryDatabase: { updateQueryDatabase($0) },
            onExecute: { sql in
                enqueuePendingTask {
                    await executeSQL(sql)
                }
            },
            isExecuting: isLoadingSQL,
            activeWorkspaceTab: nil,
            onSelectWorkspaceTab: { tab in
                selectedTab = tab
                displayMode = .tableDetail(tab)
            },
            onImport: { await importSQLFile() },
            onOpenFile: { await openSQLFile() },
            onCloseTab: { closeActiveEditorTab() },
            onSaveFile: { saveSQLFile() },
            tables: autocompleteTables,
            columns: autocompleteColumns,
            editorTabs: editorTabs,
            activeEditorTabId: activeEditorTabId,
            onSelectEditorTab: { selectEditorTab($0) },
            onCloseEditorTab: { closeEditorTab($0) }
        )
    }

    @ViewBuilder
    var splitView: some View {
        SplitView(
            topView: AnyView(
                MySQLEditorView(
                    sqlText: $sqlText,
                    history: sqlHistory,
                    queryConnectionId: currentQueryConnectionId,
                    queryConnectionName: currentQueryConnectionName,
                    availableConnections: availableConnections,
                    queryDatabases: queryDatabaseOptions,
                    selectedQueryDatabase: currentQueryDatabase,
                    onSwitchQueryConnection: { switchQueryConnection($0) },
                    onSelectQueryDatabase: { updateQueryDatabase($0) },
                    onExecute: { sql in
                        enqueuePendingTask {
                            await executeSQL(sql)
                        }
                    },
                    isExecuting: isLoadingSQL,
                    activeWorkspaceTab: {
                        if case .tableDetail = displayMode {
                            return selectedTab
                        }
                        return nil
                    }(),
                    onSelectWorkspaceTab: { tab in
                        selectedTab = tab
                        displayMode = .tableDetail(tab)
                    },
                    onImport: { await importSQLFile() },
                    onOpenFile: { await openSQLFile() },
                    onCloseTab: { closeActiveEditorTab() },
                    onSaveFile: { saveSQLFile() },
                    tables: autocompleteTables,
                    columns: autocompleteColumns,
                    editorTabs: editorTabs,
                    activeEditorTabId: activeEditorTabId,
                    onSelectEditorTab: { selectEditorTab($0) },
                    onCloseEditorTab: { closeEditorTab($0) }
                )
            ),
            bottomView: AnyView(bottomContentView),
            topHeight: $editorHeight,
            minTopHeight: 120,
            minBottomHeight: 100
        )
    }

    @ViewBuilder
    var bottomContentView: some View {
        switch displayMode {
        case .editorOnly:
            EmptyView()
        case .sqlResult:
            sqlResultArea
        case .tableDetail:
            detailView
        }
    }
}
