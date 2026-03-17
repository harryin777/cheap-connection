//
//  MySQLEditorAutocomplete.swift
//  cheap-connection
//
//  MySQL SQL 编辑器自动补全状态与逻辑
//

import Foundation

enum MySQLEditorSuggestionNavigationDirection {
    case up
    case down
}

extension MySQLEditorView {
    func handleTextChange(_ text: String) {
        guard !text.isEmpty else {
            showAutocomplete = false
            return
        }

        // 基于当前光标位置提取词，而不是全文末尾
        let currentWord = extractWordAtCursor(text: text, position: cursorPosition)
        guard currentWord.count >= 1 else {
            showAutocomplete = false
            return
        }

        generateSuggestions(for: currentWord)
    }

    /// 提取光标位置的词（用于补全）
    private func extractWordAtCursor(text: String, position: Int) -> String {
        guard position >= 0 && position <= text.count else { return "" }

        let string = text
        let cursorIndex = string.index(string.startIndex, offsetBy: min(position, string.count))

        // 向前找到词的起始位置
        var wordStartIndex = cursorIndex
        var searchIndex = cursorIndex
        while searchIndex > string.startIndex {
            let prevIndex = string.index(before: searchIndex)
            let char = string[prevIndex]
            if char.isWhitespace || char == "," || char == "(" || char == ")" || char == ";" {
                wordStartIndex = searchIndex
                break
            }
            wordStartIndex = prevIndex
            searchIndex = prevIndex
        }

        // 向后找到词的结束位置（到光标位置为止，不包括光标后的内容）
        let wordEndIndex = cursorIndex

        // 提取当前词
        if wordStartIndex <= wordEndIndex {
            return String(string[wordStartIndex..<wordEndIndex])
        }
        return ""
    }

    func generateSuggestions(for word: String) {
        var suggestions: [SQLCompletionSuggestion] = []
        let lowercasedWord = word.lowercased()

        // Debug: 检查候选源是否为空
        print("[Autocomplete] 生成建议 for word: '\(word)'")
        print("[Autocomplete] tables.count: \(tables.count), columns.count: \(columns.count)")
        if !tables.isEmpty {
            print("[Autocomplete] 表名: \(tables.map { $0.name })")
        }

        for table in tables where table.name.lowercased().hasPrefix(lowercasedWord) {
            suggestions.append(SQLCompletionSuggestion(text: table.name, type: .table))
        }

        for column in columns where column.name.lowercased().hasPrefix(lowercasedWord) {
            suggestions.append(SQLCompletionSuggestion(text: column.name, type: .column))
        }

        for keyword in sqlKeywords where keyword.lowercased().hasPrefix(lowercasedWord) {
            suggestions.append(SQLCompletionSuggestion(text: keyword, type: .keyword))
        }

        print("[Autocomplete] 匹配到 \(suggestions.count) 个建议: \(suggestions.map { $0.text })")
        autocompleteSuggestions = Array(suggestions.prefix(10))
        selectedSuggestionIndex = 0
        showAutocomplete = !autocompleteSuggestions.isEmpty

        // 记录触发补全时的光标位置，用于后续判断光标是否移出补全词
        if showAutocomplete {
            autocompleteStartPosition = cursorPosition
        }
    }

    func acceptSuggestion() {
        acceptSuggestion(at: selectedSuggestionIndex)
    }

    func acceptSuggestion(at index: Int) {
        guard index < autocompleteSuggestions.count else { return }
        let suggestion = autocompleteSuggestions[index]

        // 基于光标位置替换当前词
        let text = sqlText
        let cursorPos = cursorPosition

        guard cursorPos >= 0 && cursorPos <= text.count else {
            showAutocomplete = false
            return
        }

        let string = text
        let cursorIndex = string.index(string.startIndex, offsetBy: min(cursorPos, string.count))

        // 向前找到词的起始位置
        var wordStartIndex = cursorIndex
        var searchIndex = cursorIndex
        while searchIndex > string.startIndex {
            let prevIndex = string.index(before: searchIndex)
            let char = string[prevIndex]
            if char.isWhitespace || char == "," || char == "(" || char == ")" || char == ";" {
                wordStartIndex = searchIndex
                break
            }
            wordStartIndex = prevIndex
            searchIndex = prevIndex
        }

        // 构建新文本：前缀 + 建议词 + 后缀
        let prefix = String(string[string.startIndex..<wordStartIndex])
        let suffix = String(string[cursorIndex...])
        sqlText = prefix + suggestion.text + suffix

        // 计算新的光标位置：精确停在补全文本最后一个字符后面
        let newCursorPos = prefix.count + suggestion.text.count
        requestedCursorPosition = newCursorPos

        showAutocomplete = false
        autocompleteStartPosition = nil
    }

    func navigateSuggestion(direction: MySQLEditorSuggestionNavigationDirection) {
        let count = min(autocompleteSuggestions.count, 8)
        guard count > 0 else { return }

        if direction == .down {
            selectedSuggestionIndex = (selectedSuggestionIndex + 1) % count
        } else {
            selectedSuggestionIndex = (selectedSuggestionIndex - 1 + count) % count
        }
    }

    /// 检查光标是否移出当前补全词范围，如果是则关闭补全浮层
    func checkAndDismissAutocompleteIfCursorMoved(newPosition: Int) {
        guard showAutocomplete, let startPosition = autocompleteStartPosition else { return }

        // 光标位置变化时，关闭补全浮层
        // 简单策略：如果光标移动了，就关闭补全
        if newPosition != startPosition {
            showAutocomplete = false
            autocompleteStartPosition = nil
        }
    }
}
