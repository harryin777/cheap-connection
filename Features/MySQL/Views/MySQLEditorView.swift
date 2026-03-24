//
//  MySQLEditorView.swift
//  cheap-connection
//
//  MySQL SQL编辑器视图 - DataGrip风格工具栏
//

import SwiftUI

/// MySQL SQL编辑器视图 - DataGrip风格
struct MySQLEditorView: View {
    @Binding var sqlText: String
    let history: [String]
    @ObservedObject private var settingsRepo = SettingsRepository.shared

    // MARK: - Query Context
    let queryConnectionId: UUID
    let queryConnectionName: String
    let availableConnections: [ConnectionConfig]
    let queryDatabases: [String]
    let selectedQueryDatabase: String?

    // MARK: - Callbacks
    let onSwitchQueryConnection: (UUID) -> Void
    let onSelectQueryDatabase: (String?) -> Void
    let onExecute: (String) async -> Void

    var isExecuting: Bool = false
    var activeWorkspaceTab: MySQLDetailTab? = nil
    var onSelectWorkspaceTab: ((MySQLDetailTab) -> Void)? = nil
    var onImport: (() async -> Void)? = nil
    var onOpenFile: (() async -> Void)? = nil
    var onCloseTab: (() -> Void)? = nil
    var onSaveFile: (() -> Void)? = nil
    var tables: [MySQLTableSummary] = []
    var columns: [MySQLColumnDefinition] = []
    var editorTabs: [EditorQueryTab] = []
    var activeEditorTabId: UUID? = nil
    var onSelectEditorTab: ((UUID) -> Void)? = nil
    var onCloseEditorTab: ((UUID) -> Void)? = nil

    @State var showHistory = false
    @State var showConfirmDialog = false
    @State var pendingSQL = ""
    @State var showAutocomplete = false
    @State var autocompleteSuggestions: [SQLCompletionSuggestion] = []
    @State var selectedSuggestionIndex = 0
    @State var selectedTextRange: NSRange? = nil
    @State var cursorPosition: Int = 0
    @State var cursorRect: CursorRectInfo? = nil
    /// 外部请求的光标位置（用于自动补全后同步）
    @State var requestedCursorPosition: Int?
    /// 触发补全时的光标位置（用于判断光标是否移出补全词）
    @State var autocompleteStartPosition: Int?

    let sqlKeywords = SQLKeywords.all

    // MARK: - Computed Properties

    var editorFontSize: CGFloat {
        CGFloat(settingsRepo.settings.editorFontSize)
    }

    var tabBarFontSize: CGFloat {
        CGFloat(settingsRepo.settings.tabBarFontSize)
    }

    /// 当前查询连接是否为 Redis
    var isCurrentConnectionRedis: Bool {
        availableConnections.first { $0.id == queryConnectionId }?.databaseKind == .redis
    }

    var body: some View {
        return VStack(spacing: 0) {
            toolbarView

            if !editorTabs.isEmpty {
                queryTabBar
            }

            Divider()

            ZStack(alignment: .topLeading) {
                HSplitView {
                    editorView
                        .frame(minWidth: 300)

                    if showHistory {
                        historyPanel
                            .frame(minWidth: 180, maxWidth: 280)
                    }
                }

                if showAutocomplete && !autocompleteSuggestions.isEmpty {
                    autocompleteOverlay
                }
            }
        }
        .confirmationDialog("Confirm Execute", isPresented: $showConfirmDialog) {
            Button("Execute") {
                Task { await onExecute(pendingSQL) }
                pendingSQL = ""
            }
            Button("Cancel", role: .cancel) {
                pendingSQL = ""
            }
        } message: {
            Text("This operation may modify or delete data. Continue?")
        }
        // MARK: - Keyboard Shortcut Listeners
        .onReceive(NotificationCenter.default.publisher(for: .executeSQL)) { _ in
            executeSQL()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearEditor)) { _ in
            sqlText = ""
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleHistory)) { _ in
            showHistory.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveSQLFile)) { _ in
            onSaveFile?()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSQLFile)) { _ in
            // 打开文件也使用同步模式
            if let result = SQLFileOperations.openSQLFileSync() {
                sqlText = result.content
            }
        }
    }

    var editorView: some View {
        return VStack(alignment: .leading, spacing: 0) {
            SQLEditorTextView(
                text: $sqlText,
                editorFontSize: editorFontSize,
                requestedCursorPosition: requestedCursorPosition,
                onSelectionChange: { range, _ in
                    selectedTextRange = range
                },
                onCursorPositionChange: { position in
                    cursorPosition = position
                    // 检查光标是否移出当前补全词范围，如果是则关闭补全浮层
                    checkAndDismissAutocompleteIfCursorMoved(newPosition: position)
                },
                onCursorRectChange: { rectInfo in
                    cursorRect = rectInfo
                }
            )
            .onChange(of: sqlText) { _, newValue in
                handleTextChange(newValue)
            }

            HStack {
                Text("Cmd+Enter execute | Tab complete")
                    .font(.system(size: max(9, tabBarFontSize - 1)))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(sqlText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) lines")
                    .font(.system(size: max(9, tabBarFontSize - 1)))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
        }
        .onKeyPress(.tab) {
            if showAutocomplete && !autocompleteSuggestions.isEmpty {
                acceptSuggestion()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            if showAutocomplete && !autocompleteSuggestions.isEmpty {
                navigateSuggestion(direction: .up)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow) {
            if showAutocomplete && !autocompleteSuggestions.isEmpty {
                navigateSuggestion(direction: .down)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if showAutocomplete {
                showAutocomplete = false
                return .handled
            }
            return .ignored
        }
    }

    var autocompleteOverlay: some View {
        SQLEditorAutocompleteOverlay(
            suggestions: autocompleteSuggestions,
            selectedIndex: selectedSuggestionIndex,
            onSelect: acceptSuggestion(at:)
        )
        .offset(
            x: cursorRect?.x ?? 10,
            y: (cursorRect.map { $0.y + $0.height + 4 } ?? 20)
        )
    }

    var historyPanel: some View {
        SQLEditorHistoryPanel(
            history: history,
            isPresented: $showHistory
        )
    }

    func executeSQL() {
        let scope = SQLStatementParser.parseExecutionScope(
            fullText: sqlText,
            selectedRange: selectedTextRange,
            cursorPosition: cursorPosition
        )

        let sql = scope.sql
        guard !sql.isEmpty else { return }

        let riskLevel = SQLRiskLevel.analyze(sql)
        if riskLevel == .dangerous || riskLevel == .warning {
            pendingSQL = sql
            showConfirmDialog = true
        } else {
            Task { await onExecute(sql) }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var sqlText = "SELECT * FROM users LIMIT 10;"
        @State var selectedDb: String? = "test_db"

        let previewConnection = ConnectionConfig(
            name: "local-mysql",
            databaseKind: .mysql,
            host: "localhost",
            port: 3306,
            username: "root",
            defaultDatabase: "test_db"
        )

        var body: some View {
            MySQLEditorView(
                sqlText: $sqlText,
                history: [
                    "SELECT * FROM users LIMIT 10;",
                    "SHOW DATABASES;",
                    "DESCRIBE orders;"
                ],
                queryConnectionId: previewConnection.id,
                queryConnectionName: previewConnection.name,
                availableConnections: [previewConnection],
                queryDatabases: ["test_db", "mysql", "information_schema"],
                selectedQueryDatabase: selectedDb,
                onSwitchQueryConnection: { _ in },
                onSelectQueryDatabase: { db in selectedDb = db },
                onExecute: { _ in }
            )
            .frame(width: 700, height: 400)
        }
    }

    return PreviewWrapper()
}
