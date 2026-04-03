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
            autocompleteWordRange = nil
            return
        }

        // 基于当前光标位置提取词，而不是全文末尾
        let extracted = extractWordAtCursor(text: text, position: cursorPosition)
        let currentWord = extracted.word
        guard currentWord.count >= 1 else {
            showAutocomplete = false
            autocompleteWordRange = nil
            return
        }

        generateSuggestions(for: currentWord, wordRange: extracted.range)
    }

    /// 提取光标位置的词（用于补全）
    private func extractWordAtCursor(text: String, position: Int) -> (word: String, range: NSRange) {
        guard position >= 0 && position <= text.count else { return ("", NSRange(location: 0, length: 0)) }

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
            let word = String(string[wordStartIndex..<wordEndIndex])
            let startOffset = string.distance(from: string.startIndex, to: wordStartIndex)
            let length = string.distance(from: wordStartIndex, to: wordEndIndex)
            return (word, NSRange(location: startOffset, length: length))
        }
        return ("", NSRange(location: position, length: 0))
    }

    func generateSuggestions(for word: String, wordRange: NSRange) {
        var suggestions: [SQLCompletionSuggestion] = []
        let lowercasedWord = word.lowercased()

        for table in tables where table.name.lowercased().hasPrefix(lowercasedWord) {
            suggestions.append(SQLCompletionSuggestion(text: table.name, type: .table))
        }

        for column in columns where column.name.lowercased().hasPrefix(lowercasedWord) {
            suggestions.append(SQLCompletionSuggestion(text: column.name, type: .column))
        }

        for keyword in sqlKeywords where keyword.lowercased().hasPrefix(lowercasedWord) {
            suggestions.append(SQLCompletionSuggestion(text: keyword, type: .keyword))
        }
        autocompleteSuggestions = Array(suggestions.prefix(10))
        selectedSuggestionIndex = 0
        showAutocomplete = !autocompleteSuggestions.isEmpty

        if showAutocomplete {
            autocompleteWordRange = wordRange
        } else {
            autocompleteWordRange = nil
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
            autocompleteWordRange = nil
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
        autocompleteWordRange = nil
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
        guard showAutocomplete, let wordRange = autocompleteWordRange else { return }

        let validRange = wordRange.location...(wordRange.location + wordRange.length)
        if !validRange.contains(newPosition) {
            showAutocomplete = false
            autocompleteWordRange = nil
        }
    }
}
