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

        let prefix = String(text.prefix(text.count))
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
        guard currentWord.count >= 2 else {
            showAutocomplete = false
            return
        }

        generateSuggestions(for: currentWord)
    }

    func generateSuggestions(for word: String) {
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
    }

    func acceptSuggestion() {
        acceptSuggestion(at: selectedSuggestionIndex)
    }

    func acceptSuggestion(at index: Int) {
        guard index < autocompleteSuggestions.count else { return }
        let suggestion = autocompleteSuggestions[index]

        let words = sqlText.split(separator: " ", omittingEmptySubsequences: false)
        if let lastWord = words.last {
            let prefix = sqlText.dropLast(lastWord.count)
            sqlText = prefix + suggestion.text + " "
        }

        showAutocomplete = false
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
}
