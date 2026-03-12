//
//  MySQLEditorView.swift
//  cheap-connection
//
//  MySQL SQL编辑器视图 - DataGrip风格工具栏
//

import SwiftUI

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
    var isExecuting: Bool = false
    let onExecute: (String) async -> Void
    let onSelectHistory: (String) -> Void
    var onImport: (() async -> Void)? = nil  // 导入回调
    var onOpenFile: (() async -> Void)? = nil  // 打开文件回调
    var queryDatabases: [String] = []  // SQL 可执行数据库列表
    var selectedQueryDatabase: String? = nil  // 当前 SQL 执行数据库
    var onSelectQueryDatabase: (String?) -> Void = { _ in }  // 选择数据库回调

    // 自动补全相关数据
    var tables: [MySQLTableSummary] = []
    var columns: [MySQLColumnDefinition] = []

    @State private var showHistory = false
    @State private var showConfirmDialog = false
    @State private var pendingSQL = ""
    @State private var showAutocomplete = false
    @State private var autocompleteSuggestions: [SQLCompletionSuggestion] = []
    @State private var selectedSuggestionIndex = 0
    @State private var autocompleteWordStart: Int = 0
    @State private var queryTabTitle = "Query"

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

            Divider()

            queryTabBar

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

            Spacer()

            // 当前 SQL 执行数据库（单选）
            if !queryDatabases.isEmpty {
                Picker(
                    "执行数据库",
                    selection: Binding<String?>(
                        get: { selectedQueryDatabase },
                        set: { onSelectQueryDatabase($0) }
                    )
                ) {
                    Text("未指定")
                        .tag(Optional<String>.none)

                    ForEach(queryDatabases, id: \.self) { database in
                        Text(database)
                            .tag(Optional(database))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 180)
                .help("当前 Query 执行数据库")
            }

            // 历史记录计数
            if !history.isEmpty {
                Text("\(history.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
    }

    private var queryTabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(queryTabTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Button {
                    closeCurrentQueryTab()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("关闭当前 Query")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .overlay(
                Rectangle()
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(height: 1),
                alignment: .bottom
            )

            Spacer()
        }
        .frame(height: 28)
        .background(Color(.windowBackgroundColor))
    }

    private var editorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 代码编辑器
            TextEditor(text: $sqlText)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .focused($isEditorFocused)
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
        let sql = sqlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else { return }

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
        sqlText = ""
        showAutocomplete = false
        autocompleteSuggestions = []
        selectedSuggestionIndex = 0
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
                onExecute: { _ in },
                onSelectHistory: { _ in }
            )
            .frame(width: 700, height: 400)
        }
    }

    return PreviewWrapper()
}
