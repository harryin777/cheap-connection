//
//  MySQLEditorView.swift
//  cheap-connection
//
//  MySQL SQL编辑器视图 - DataGrip风格工具栏
//

import SwiftUI
import AppKit

/// SQL 自动补全建议
struct SQLCompletionSuggestion: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    var displayText: String { text }

    enum SuggestionType: String {
        case table = "表"
        case column = "列"
        case keyword = "关键字"

        var icon: String {
            switch self {
            case .table: return "tablecells"
            case .column: return "rectangle.split.3x1"
            case .keyword: return "textformat.abc"
            }
        }
    }

    static func == (lhs: SQLCompletionSuggestion, rhs: SQLCompletionSuggestion) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 导入结果
struct SQLImportResult {
    let success: Bool
    let totalStatements: Int
    let successStatements: Int
    let failedStatements: Int
    let errors: [String]
    let duration: TimeInterval

    var summary: String {
        if success {
            return "成功执行 \(successStatements) 条语句，耗时 \(String(format: "%.2f", duration))s"
        } else {
            return "执行完成：成功 \(successStatements)/\(totalStatements)，失败 \(failedStatements)"
        }
    }
}

/// MySQL SQL编辑器视图 - DataGrip风格
struct MySQLEditorView: View {
    @Binding var sqlText: String
    let history: [String]
    let connectionName: String
    var isExecuting: Bool = false
    var activeWorkspaceTab: MySQLDetailTab? = nil
    let onExecute: (String) async -> Void
    let onSelectHistory: (String) -> Void
    var onSelectWorkspaceTab: ((MySQLDetailTab) -> Void)? = nil
    var onImport: (() async -> Void)? = nil  // 导入回调
    var onOpenFile: (() async -> Void)? = nil  // 打开文件回调
    var onCloseTab: (() -> Void)? = nil  // 关闭 Tab 回调
    var queryDatabases: [String] = []  // SQL 可执行数据库列表
    var selectedQueryDatabase: String? = nil  // 当前 SQL 执行数据库
    var onSelectQueryDatabase: (String?) -> Void = { _ in }  // 选择数据库回调

    // 自动补全相关数据
    var tables: [MySQLTableSummary] = []
    var columns: [MySQLColumnDefinition] = []

    // Query Tab 相关
    var editorTabs: [EditorQueryTab] = []
    var activeEditorTabId: UUID? = nil
    var onSelectEditorTab: ((UUID) -> Void)? = nil
    var onCloseEditorTab: ((UUID) -> Void)? = nil

    @State private var showHistory = false
    @State private var showConfirmDialog = false
    @State private var pendingSQL = ""
    @State private var showAutocomplete = false
    @State private var autocompleteSuggestions: [SQLCompletionSuggestion] = []
    @State private var selectedSuggestionIndex = 0
    @State private var autocompleteWordStart: Int = 0

    // 执行范围相关状态
    @State private var selectedTextRange: NSRange? = nil
    @State private var selectedTextContent: String = ""
    @State private var cursorPosition: Int = 0

    @FocusState private var isEditorFocused: Bool

    // SQL 关键字
    private let sqlKeywords = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN",
        "ORDER", "BY", "ASC", "DESC", "GROUP", "HAVING", "LIMIT", "OFFSET",
        "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "AS", "DISTINCT",
        "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "DROP",
        "ALTER", "TABLE", "INDEX", "VIEW", "NULL", "IS", "COUNT", "SUM", "AVG",
        "MAX", "MIN", "CASE", "WHEN", "THEN", "ELSE", "END", "UNION", "ALL", "SHOW"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏 - DataGrip风格
            toolbarView

            // Query Tab 条（仅当有外部文件时显示）
            if !editorTabs.isEmpty {
                queryTabBar
            }

            Divider()

            // 主内容区
            ZStack(alignment: .topLeading) {
                HSplitView {
                    // SQL 编辑器
                    editorView
                        .frame(minWidth: 300)

                    // 历史面板
                    if showHistory {
                        historyPanel
                            .frame(minWidth: 180, maxWidth: 280)
                    }
                }

                // 自动补全浮层
                if showAutocomplete && !autocompleteSuggestions.isEmpty {
                    autocompleteOverlay
                }
            }
        }
        .confirmationDialog("确认执行", isPresented: $showConfirmDialog) {
            Button("执行") {
                Task {
                    await onExecute(pendingSQL)
                }
                pendingSQL = ""
            }
            Button("取消", role: .cancel) {
                pendingSQL = ""
            }
        } message: {
            Text("此操作可能会修改或删除数据，是否继续？")
        }
    }

    // MARK: - Subviews

    private var toolbarView: some View {
        HStack(spacing: 8) {
            // 执行按钮 - 绿色播放图标
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

            // 历史按钮
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

            // 清空按钮
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

            // 打开文件按钮
            if let onOpenFile = onOpenFile {
                Button {
                    Task {
                        await onOpenFile()
                    }
                } label: {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("打开 .sql 文件")
            }

            // 导入执行按钮
            if let onImport = onImport {
                Button {
                    Task {
                        await onImport()
                    }
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

            // 当前 SQL 上下文选择器 - DataGrip 风格双 selector
            if !queryDatabases.isEmpty {
                contextSelectorsView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
    }

    /// DataGrip 风格上下文选择器 - 左侧 schema/database，右侧 connection
    private var contextSelectorsView: some View {
        HStack(spacing: 8) {
            schemaSelectorMenu
            connectionSelectorMenu
        }
    }

    private var schemaSelectorMenu: some View {
        // GPT TODO: 这里的 queryDatabases 目前来自外层 workspace 的单一数据库列表，
        // GPT TODO: 所以当右上角 connection pill 未来切到别的连接时，这里的 schema/database 菜单仍然会显示旧连接的库。
        // GPT TODO: glm5 必须改成“按当前活动 query tab 的 queryConnectionId 动态提供数据库列表”，
        // GPT TODO: 而不是继续复用当前 MySQLWorkspaceView(connectionConfig) 已加载的 databases。
        Menu {
            Button {
                onSelectQueryDatabase(nil)
            } label: {
                HStack {
                    Text("未指定")
                    if selectedQueryDatabase == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(queryDatabases, id: \.self) { database in
                Button {
                    onSelectQueryDatabase(database)
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 10))
                        Text(database)
                        if selectedQueryDatabase == database {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            contextSelectorLabel(
                icon: "square.grid.2x2",
                iconColor: .secondary,
                title: selectedQueryDatabase ?? "未指定"
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("当前 Query 执行数据库")
    }

    private var connectionSelectorMenu: some View {
        // GPT TODO: 这里现在是静态单项 Menu，只展示 connectionName，没有真正可选列表。
        // GPT TODO: 用户要求右上角 connection pill 是“当前 query 文件的连接选择器”，必须支持切换到其他已保存连接，
        // GPT TODO: 且不能与左侧资源树当前高亮连接强绑定。
        // GPT TODO: glm5 需要把这里改成真实连接列表菜单，并在切换时只更新 active editor tab 的 queryConnectionId，
        // GPT TODO: 不允许调用左侧资源树的全局 selectedConnectionId，否则会再次把 explorer selection 一起带走。
        Menu {
            Button {
            } label: {
                HStack {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.system(size: 10))
                    Text(connectionName)
                    Spacer()
                    Text("当前连接")
                        .foregroundStyle(.tertiary)
                }
            }
            .disabled(true)
        } label: {
            contextSelectorLabel(
                icon: "externaldrive.connected.to.line.below",
                iconColor: Color(red: 0.17, green: 0.67, blue: 0.95),
                title: connectionName
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("当前 Query 连接")
    }

    private func contextSelectorLabel(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    private func workspaceTabsView(
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

    /// Query Tab 条视图 - DataGrip 风格，关闭按钮始终清晰可见
    private var queryTabBar: some View {
        HStack(spacing: 0) {
            ForEach(editorTabs) { tab in
                queryTabItem(tab)
            }

            // 右侧空白区域，确保 tab 条占满整行
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }

    /// 单个 Query Tab 项
    private func queryTabItem(_ tab: EditorQueryTab) -> some View {
        HStack(spacing: 0) {
            // 左侧：图标和标题（点击选中）
            Button {
                onSelectEditorTab?(tab.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text(tab.title)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 右侧：关闭按钮（独立，始终可见）
            Button {
                onCloseEditorTab?(tab.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(activeEditorTabId == tab.id ? .secondary : .tertiary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .frame(minWidth: 80)
        .background(activeEditorTabId == tab.id ? Color.accentColor.opacity(0.12) : Color.clear)
        .overlay(
            Rectangle()
                .fill(activeEditorTabId == tab.id ? Color.accentColor : Color.clear)
                .frame(height: 1.5),
            alignment: .bottom
        )
    }

    private var editorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 代码编辑器 - 使用自定义 TextView 支持选中范围追踪
            SQLEditorTextView(
                text: $sqlText,
                onSelectionChange: { range, selectedText in
                    selectedTextRange = range
                    selectedTextContent = selectedText
                },
                onCursorPositionChange: { position in
                    cursorPosition = position
                }
            )
            .onChange(of: sqlText) { _, newValue in
                handleTextChange(newValue)
            }

            // 底部提示栏
            HStack {
                Text("⌘↵ 执行 | Tab 补全")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(sqlText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) 行")
                    .font(.system(size: 10))
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

    private var autocompleteOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(autocompleteSuggestions.prefix(8).enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    acceptSuggestion(at: index)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: suggestion.type.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)

                        Text(suggestion.displayText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(suggestion.type.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(index == selectedSuggestionIndex ? Color.accentColor.opacity(0.2) : Color.clear)
            }
        }
        .frame(minWidth: 200, maxWidth: 300)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
        .offset(x: 50, y: 80)
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 面板标题
            HStack {
                Text("执行历史")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showHistory = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.controlBackgroundColor))

            Divider()

            // 历史列表
            if history.isEmpty {
                emptyHistoryView
            } else {
                historyListView
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private var emptyHistoryView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            Text("暂无历史记录")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(history, id: \.self) { sql in
                    historyItemRow(sql)
                }
            }
        }
    }

    private func historyItemRow(_ sql: String) -> some View {
        Button {
            onSelectHistory(sql)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(sql)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(3)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(sql.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) 行")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Actions

    private func executeSQL() {
        // 使用 SQLStatementParser 解析执行范围
        // 1. 优先执行选中 SQL
        // 2. 无选中时执行光标所在语句
        // 3. 回退到整个 buffer
        let scope = SQLStatementParser.parseExecutionScope(
            fullText: sqlText,
            selectedRange: selectedTextRange,
            cursorPosition: cursorPosition
        )

        let sql = scope.sql
        guard !sql.isEmpty else { return }

        // 根据执行范围类型显示提示
        switch scope.scopeType {
        case .selected:
            print("🎯 Executing selected SQL: \(sql.prefix(50))...")
        case .current:
            print("📍 Executing current statement at cursor: \(sql.prefix(50))...")
        case .entire:
            print("📄 Executing entire buffer: \(sql.prefix(50))...")
        }

        // 检查 SQL 风险等级
        let riskLevel = SQLRiskLevel.analyze(sql)
        if riskLevel == .dangerous || riskLevel == .warning {
            pendingSQL = sql
            showConfirmDialog = true
        } else {
            Task {
                await onExecute(sql)
            }
        }
    }

    private func closeCurrentQueryTab() {
        // 清空自动补全状态
        showAutocomplete = false
        autocompleteSuggestions = []
        selectedSuggestionIndex = 0
        // 调用关闭回调
        onCloseTab?()
    }

    // MARK: - Autocomplete

    private func handleTextChange(_ text: String) {
        guard !text.isEmpty else {
            showAutocomplete = false
            return
        }

        // 找到当前光标位置前的单词
        let cursorPosition = text.count
        let prefix = String(text.prefix(cursorPosition))

        // 找到当前正在输入的单词起始位置
        var wordStart = prefix.endIndex
        var index = prefix.endIndex
        while index > prefix.startIndex {
            let charIndex = prefix.index(before: index)
            let char = prefix[charIndex]
            if char.isWhitespace || char == "," || char == "(" || char == ")" {
                wordStart = index
                break
            }
            index = charIndex
        }
        if index == prefix.startIndex {
            wordStart = prefix.startIndex
        }

        let currentWord = String(prefix[wordStart...])

        // 如果单词太短，不显示补全
        guard currentWord.count >= 2 else {
            showAutocomplete = false
            return
        }

        // 生成补全建议
        generateSuggestions(for: currentWord)
    }

    private func generateSuggestions(for word: String) {
        var suggestions: [SQLCompletionSuggestion] = []
        let lowercasedWord = word.lowercased()

        // 添加表名建议
        for table in tables {
            if table.name.lowercased().hasPrefix(lowercasedWord) {
                suggestions.append(SQLCompletionSuggestion(text: table.name, type: .table))
            }
        }

        // 添加列名建议
        for column in columns {
            if column.name.lowercased().hasPrefix(lowercasedWord) {
                suggestions.append(SQLCompletionSuggestion(text: column.name, type: .column))
            }
        }

        // 添加关键字建议
        for keyword in sqlKeywords {
            if keyword.lowercased().hasPrefix(lowercasedWord) {
                suggestions.append(SQLCompletionSuggestion(text: keyword, type: .keyword))
            }
        }

        // 限制建议数量
        autocompleteSuggestions = Array(suggestions.prefix(10))
        selectedSuggestionIndex = 0
        showAutocomplete = !autocompleteSuggestions.isEmpty
    }

    private func acceptSuggestion() {
        acceptSuggestion(at: selectedSuggestionIndex)
    }

    private func acceptSuggestion(at index: Int) {
        guard index < autocompleteSuggestions.count else { return }
        let suggestion = autocompleteSuggestions[index]

        // 找到当前单词的位置并替换
        let words = sqlText.split(separator: " ", omittingEmptySubsequences: false)
        if var lastWord = words.last {
            let prefix = sqlText.dropLast(lastWord.count)
            sqlText = prefix + suggestion.text + " "
        }

        showAutocomplete = false
    }

    private func navigateSuggestion(direction: NavigationDirection) {
        let count = min(autocompleteSuggestions.count, 8)
        guard count > 0 else { return }

        if direction == .down {
            selectedSuggestionIndex = (selectedSuggestionIndex + 1) % count
        } else {
            selectedSuggestionIndex = (selectedSuggestionIndex - 1 + count) % count
        }
    }

    private enum NavigationDirection {
        case up, down
    }
}

// MARK: - SQL Editor TextView (支持选中范围追踪)

/// SQL 编辑器 TextView - 支持选中范围和光标位置追踪
struct SQLEditorTextView: NSViewRepresentable {
    @Binding var text: String
    var onSelectionChange: ((NSRange, String) -> Void)?
    var onCursorPositionChange: ((Int) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 0

        // 设置初始文本
        textView.string = text

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // 只在文本真正改变时更新
        if textView.string != text {
            // 保存当前选中范围
            let selectedRange = textView.selectedRange()

            textView.string = text

            // 尝试恢复选中范围（如果有效）
            if selectedRange.location + selectedRange.length <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }

        // 通知选中范围变化
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            let startIndex = text.index(text.startIndex, offsetBy: selectedRange.location)
            let endIndex = text.index(startIndex, offsetBy: min(selectedRange.length, text.count - selectedRange.location))
            let selectedText = String(text[startIndex..<endIndex])
            context.coordinator.parent?.onSelectionChange?(selectedRange, selectedText)
        }

        // 通知光标位置变化
        let cursorPosition = selectedRange.location
        context.coordinator.parent?.onCursorPositionChange?(cursorPosition)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SQLEditorTextView?

        init(_ parent: SQLEditorTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent?.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let selectedRange = textView.selectedRange()

            if let parent = parent {
                // 通知选中范围变化
                if selectedRange.length > 0 {
                    let text = textView.string
                    let startIndex = text.index(text.startIndex, offsetBy: selectedRange.location)
                    let endIndex = text.index(startIndex, offsetBy: min(selectedRange.length, text.count - selectedRange.location))
                    let selectedText = String(text[startIndex..<endIndex])
                    parent.onSelectionChange?(selectedRange, selectedText)
                }

                // 通知光标位置变化
                parent.onCursorPositionChange?(selectedRange.location)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var sqlText = "SELECT * FROM users LIMIT 10;"

        var body: some View {
            MySQLEditorView(
                sqlText: $sqlText,
                history: [
                    "SELECT * FROM users LIMIT 10;",
                    "SHOW DATABASES;",
                    "DESCRIBE orders;"
                ],
                connectionName: "local-mysql",
                onExecute: { _ in },
                onSelectHistory: { _ in }
            )
            .frame(width: 700, height: 400)
        }
    }

    return PreviewWrapper()
}
