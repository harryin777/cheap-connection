//
//  SQLStatementParser.swift
//  cheap-connection
//
//  SQL 语句解析器
//

import Foundation

/// SQL 语句解析器
enum SQLStatementParser {

    /// 解析要执行的 SQL 范围
    /// - Parameters:
    ///   - fullText: 完整的 SQL 文本
    ///   - selectedRange: 选中的范围（如果有的话，NSRange 格式）
    ///   - cursorPosition: 光标位置（字符索引）
    /// - Returns: 执行范围
    static func parseExecutionScope(
        fullText: String,
        selectedRange: NSRange? = nil,
        cursorPosition: Int? = nil
    ) -> SQLExecutionScope {
        // 1. 优先执行选中 SQL
        if let range = selectedRange, range.length > 0 {
            let startIndex = fullText.index(fullText.startIndex, offsetBy: range.location)
            let endIndex = fullText.index(startIndex, offsetBy: range.length)
            let selectedText = String(fullText[startIndex..<endIndex])
            let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return SQLExecutionScope(sql: trimmed, scopeType: .selected)
            }
        }

        // 2. 执行光标所在语句
        if let position = cursorPosition {
            if let statement = findStatementAtPosition(fullText, position: position) {
                let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return SQLExecutionScope(sql: trimmed, scopeType: .current)
                }
            }
        }

        // 3. 回退到整个 buffer
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        return SQLExecutionScope(sql: trimmed, scopeType: .entire)
    }

    /// 在指定位置找到 SQL 语句
    /// - Parameters:
    ///   - text: 完整文本
    ///   - position: 光标位置（字符索引）
    /// - Returns: 该位置的 SQL 语句
    static func findStatementAtPosition(_ text: String, position: Int) -> String? {
        let statements = parseStatements(from: text)

        var currentPosition = 0
        for statement in statements {
            let statementLength = statement.count
            let statementStart = currentPosition
            let statementEnd = currentPosition + statementLength

            // 检查光标是否在这个语句的范围内
            if position >= statementStart && position <= statementEnd {
                return statement
            }

            // 跳过这个语句和后面的分号/空白
            currentPosition = statementEnd
            // 跳过分号和空白
            while currentPosition < text.count {
                let index = text.index(text.startIndex, offsetBy: currentPosition)
                let char = text[index]
                if char == ";" || char.isWhitespace || char == "\n" {
                    currentPosition += 1
                } else {
                    break
                }
            }
        }

        return nil
    }

    /// 解析 SQL 文本中的所有语句
    /// - Parameter text: SQL 文本
    /// - Returns: 语句数组
    static func parseStatements(from text: String) -> [String] {
        var statements: [String] = []
        var currentStatement = ""
        var inString = false
        var stringDelimiter: Character?
        var inLineComment = false
        var inBlockComment = false

        let chars = Array(text)
        var i = 0

        while i < chars.count {
            let char = chars[i]
            let nextChar = i + 1 < chars.count ? chars[i + 1] : nil

            // 处理行注释 (-- 或 #)
            if !inString && !inBlockComment {
                if char == "-" && nextChar == "-" {
                    inLineComment = true
                    currentStatement.append(char)
                    i += 1
                    continue
                } else if char == "#" {
                    inLineComment = true
                    currentStatement.append(char)
                    i += 1
                    continue
                }
            }

            // 处理行注释结束（换行）
            if inLineComment {
                currentStatement.append(char)
                if char == "\n" {
                    inLineComment = false
                }
                i += 1
                continue
            }

            // 处理块注释开始 (/*)
            if !inString && !inBlockComment && char == "/" && nextChar == "*" {
                inBlockComment = true
                currentStatement.append(char)
                currentStatement.append(nextChar!)
                i += 2
                continue
            }

            // 处理块注释结束 (*/)
            if inBlockComment {
                currentStatement.append(char)
                if char == "*" && nextChar == "/" {
                    inBlockComment = false
                    currentStatement.append(nextChar!)
                    i += 2
                    continue
                }
                i += 1
                continue
            }

            // 处理字符串
            if char == "'" || char == "\"" {
                if !inString {
                    inString = true
                    stringDelimiter = char
                } else if char == stringDelimiter {
                    // 检查是否是转义的引号（双引号）
                    if nextChar == stringDelimiter {
                        currentStatement.append(char)
                        i += 1
                    } else {
                        inString = false
                        stringDelimiter = nil
                    }
                }
                currentStatement.append(char)
                i += 1
                continue
            }

            // 在字符串内，跳过分号检查
            if inString {
                currentStatement.append(char)
                i += 1
                continue
            }

            // 遇到分号，结束当前语句
            if char == ";" {
                let trimmed = currentStatement.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    statements.append(trimmed)
                }
                currentStatement = ""
            } else {
                currentStatement.append(char)
            }

            i += 1
        }

        // 处理最后一条语句（可能没有分号结尾）
        let trimmed = currentStatement.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            statements.append(trimmed)
        }

        return statements
    }
}
